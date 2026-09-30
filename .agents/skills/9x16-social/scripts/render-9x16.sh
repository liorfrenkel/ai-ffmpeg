#!/usr/bin/env bash
#
# render-9x16.sh — deterministic 9:16 social clip renderer for this repo.
#
# Turns a list of crop-position "arrivals" into a piecewise camera path:
#   cut      X at T            instant jump to X
#   glide    X at T (D)        constant-speed pan, default D=0.1
#   easeout  X at T (D, A)     decelerate into X (no end-crawl), A=0.3 default
#   easeinout X at T (D)       accelerate then decelerate (gimbal)
# Between arrivals the camera HOLDS the previous position.
# x is measured in px from the LEFT of the source frame.
#
# -m values use DECIMAL SECONDS of the original timeline ("138.5", not "2:18").
# -ss / -to accept both decimal seconds and m:ss(.f).
# Sources are never modified; output goes where -o says.
#
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  render-9x16.sh -i SRC.mp4 -o OUT.mp4 -ss START -to END \
                 [-x0 XSTART] [-crf N] [-preset P] [-b:a BITRATE] [-n] \
                 -m 'T:X:TYPE[:D[:A]]' [-m ...]

  -i SRC    input video (probed; read-only)
  -o OUT    output mp4 (new file)
  -ss START clip start, original-timeline seconds or m:ss(.f)
  -to  END  clip end, original-timeline seconds or m:ss(.f)
  -x0 X     x position held from clip start (default 0)
  -m SPEC   one arrival per -m, in chronological order:
              T:X:cut | T:X:glide[:D] | T:X:easeout[:D[:A]] | T:X:easeinout[:D]
            T/X decimal seconds / px-from-left. Defaults: D=0.1, A=0.3.
  -crf/-preset/-b:a   encode options (defaults 18 / medium / 160k)
  -n        dry run: print the computed command, do not execute
  -h        this help
EOF
  exit "${1:-0}"
}

SRC= OUT= SS= TO= X0=0 CRF=18 PRESET=medium BA=160k DRYRUN=0
MOVES=()
while [ $# -gt 0 ]; do
  case "$1" in
    -i) SRC=$2; shift 2 ;;
    -o) OUT=$2; shift 2 ;;
    -ss) SS=$2; shift 2 ;;
    -to) TO=$2; shift 2 ;;
    -x0) X0=$2; shift 2 ;;
    -crf) CRF=$2; shift 2 ;;
    -preset) PRESET=$2; shift 2 ;;
    -b:a) BA=$2; shift 2 ;;
    -m) MOVES+=("$2"); shift 2 ;;
    -n) DRYRUN=1; shift 1 ;;
    -h|--help) usage 0 ;;
    *) echo "unknown option: $1"; usage 1 ;;
  esac
done

[ -n "$SRC" ] || { echo "missing -i"; usage 1; }
[ -n "$OUT" ] || { echo "missing -o"; usage 1; }
[ -n "$SS" ]  || { echo "missing -ss"; usage 1; }
[ -n "$TO" ]  || { echo "missing -to"; usage 1; }
[ "${#MOVES[@]}" -gt 0 ] || { echo "missing -m (at least one arrival)"; usage 1; }
[ -f "$SRC" ] || { echo "input not found: $SRC"; exit 1; }

time2sec() {
  awk -F: '{ if (NF==3) print $1*3600+$2*60+$3; else if (NF==2) print $1*60+$2; else print $1 }' <<<"$1"
}
warn() { echo "[warn] $*" >&2; }

# --- probe source -----------------------------------------------------------
W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$SRC")
H=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$SRC")
SAR=$(ffprobe -v error -select_streams v:0 -show_entries stream=sample_aspect_ratio -of csv=p=0 "$SRC")
case "$SAR" in
  N/A|1:1|"") ;;
  *) W=$(awk -v w="$W" -v sar="$SAR" 'BEGIN{split(sar,a,":"); print int(w*a[1]/a[2])}') ;;
esac

# --- slice geometry ---------------------------------------------------------
CW=$(( H * 9 / 16 )); CW=$(( CW / 2 * 2 ))
if [ "$CW" -gt "$W" ]; then
  CW=$W
  CH=$(( W * 16 / 9 )); CH=$(( CH / 2 * 2 )); [ "$CH" -le "$H" ] || CH=$H
  Y0=$(( (H - CH) / 2 )); Y0=$(( Y0 / 2 * 2 ))
else
  CH=$H; Y0=0
fi
XMAX=$(( W - CW ))

# --- parse moves -> segments -------------------------------------------------
SEGS=()   # "B|L|X" literal, or "B|R|FROM|TO|TYPE|D|A" ramp
prevX=$X0
order=0
for m in "${MOVES[@]}"; do
  order=$((order+1))
  IFS=: read -r T X TYPE D A <<<"$m"
  [ -n "$T" ] && [ -n "$X" ] && [ -n "$TYPE" ] || { echo "bad -m: $m"; exit 1; }
  T=$(time2sec "$T")
  case "$X" in (*[!0-9]*) echo "X must be integer px: $X"; exit 1;; esac
  X=$((10#$X))
  [ $((X % 2)) -eq 0 ] || { echo "X must be even: $X"; exit 1; }
  [ "$X" -ge 0 ] && [ "$X" -le "$XMAX" ] || { echo "X out of range [0,$XMAX]: $X"; exit 1; }
  case "$TYPE" in
    cut)
      SEGS+=("$T|L|$prevX") ;;
    glide|easeout|easeinout)
      D=${D:-0.1}; A=${A:-0.3}
      S=$(awk -v t="$T" -v d="$D" 'BEGIN{printf "%.6f", t-d}')
      LASTB=""
      [ "${#SEGS[@]}" -gt 0 ] && LASTB=$(printf '%s' "${SEGS[${#SEGS[@]}-1]}" | cut -d'|' -f1)
      if [ -z "$LASTB" ] || awk -v s="$S" -v b="$LASTB" 'BEGIN{exit !(s>b)}'; then
        SEGS+=("$S|L|$prevX")
      else
        warn "move $order: transition for t=$T overlaps boundary $LASTB — previous move truncated"
      fi
      SEGS+=("$T|R|$prevX|$X|$TYPE|$D|$A|$S") ;;
    *)
      echo "unknown type: $TYPE (cut|glide|easeout|easeinout)"; exit 1 ;;
  esac
  prevX=$X
done

# --- build nested expression (innermost = final hold) ------------------------
chain="$prevX"
for ((i=${#SEGS[@]}-1; i>=0; i--)); do
  IFS='|' read -r B K V1 V2 TY D A S <<<"${SEGS[$i]}"
  if [ "$K" = "L" ]; then
    val="$V1"
  else
    AM=$(awk -v a="$A" 'BEGIN{printf "%.6g", 1-a}')
    case "$TY" in
      glide)     val="${V1}+(${V2}-${V1})*(t-${S})/${D}" ;;
      easeout)   val="${V1}+(${V2}-${V1})*(((${A}*((t-${S})/${D}))+(${AM}*(1-(1-(t-${S})/${D})*(1-(t-${S})/${D})))))" ;;
      easeinout) val="${V1}+(${V2}-${V1})*(((t-${S})/${D})*((t-${S})/${D})*(3-2*((t-${S})/${D})))" ;;
    esac
  fi
  chain="if(lt(t,$B),$val,$chain)"
done

# --- guards ----------------------------------------------------------------
O=$(printf '%s' "$chain" | tr -cd '(' | wc -c)
C=$(printf '%s' "$chain" | tr -cd ')' | wc -c)
[ "$O" = "$C" ] || { echo "assert failed: unbalanced expression ($O open / $C close)"; exit 1; }

DUR=$(awk -v s="$(time2sec "$SS")" -v e="$(time2sec "$TO")" 'BEGIN{printf "%.6f", e-s}')

FFMPEG_ARGS=(-y -v error -i "$SRC" -ss "$(time2sec "$SS")" -t "$DUR" \
  -vf "crop=$CW:$CH:'$chain':$Y0,scale=1080:1920:flags=lanczos,format=yuv420p" \
  -c:v libx264 -crf "$CRF" -preset "$PRESET" -c:a aac -b:a "$BA" -movflags +faststart "$OUT")

echo "== render-9x16: source ${W}x${H}, slice ${CW}x${CH} @ y=$Y0, x range [0,$XMAX]"
for m in "${MOVES[@]}"; do echo "   move: $m"; done
echo "   x(t): $chain"
if [ "$DRYRUN" = "1" ]; then
  echo "== dry run: ffmpeg ${FFMPEG_ARGS[*]}"
  exit 0
fi

ffmpeg "${FFMPEG_ARGS[@]}" || exit 1

# --- structural verification ------------------------------------------------
echo "== output check:"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,duration -of default=noprint_wrappers=1 "$OUT"
ffprobe -v error -show_entries stream=index,codec_type,codec_name -of default=noprint_wrappers=1 "$OUT"
echo "== done: $OUT"