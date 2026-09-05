#!/usr/bin/env bash
# Peepo's sound: the music tracks and the effects.
#
#   tools/audio.sh sfx                   # synthesize the effects, offline, free
#   tools/audio.sh music [<id> ...]      # generate the tracks, costs money
#   tools/audio.sh music --reprocess     # redo the post-process, no new calls
#
# `music` calls Lyria 3 through the Gemini API and needs GEMINI_API_KEY. It
# keeps what the model sent in tools/audio/, so --reprocess can rework a track
# as often as it takes without paying for it again. See tools/audio.py.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.venv"
PY="$VENV/bin/python"

if [ ! -x "$PY" ]; then
  echo "creating $VENV" >&2
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
fi
# Cheap enough to run every time, and it is what adds numpy and google-genai to
# a .venv that an older checkout created for the scene pipeline alone.
"$VENV/bin/pip" install --quiet -r "$ROOT/tools/requirements.txt"

[ $# -gt 0 ] || { sed -n '2,6p' "${BASH_SOURCE[0]}" | cut -c3-; exit 1; }

cd "$ROOT"
export PYTHONPATH="$ROOT/tools:${PYTHONPATH:-}"
exec "$PY" tools/audio.py "$@"
