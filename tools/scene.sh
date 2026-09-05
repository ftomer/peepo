#!/usr/bin/env bash
# Scene pipeline: raw jpegs in, playable level out.
#
#   tools/scene.sh art     docs/imgenprompts/<level>.md
#   tools/scene.sh icon    [<square master png>]
#   tools/scene.sh mascot  [<pose> ...]
#   tools/scene.sh analyze <id> --bg <jpeg> --sheets <jpeg> [<jpeg> ...]
#   tools/scene.sh regions <id> [--variant dense] [--sheet] [--only <id> ...]
#   tools/scene.sh fit     <id> [--variant dense] [--snap] [--check]
#   tools/scene.sh bake    <id> [--variant dense] [--art <jpeg>]
#   tools/scene.sh place   <id> [--difficulty easy|medium|hard]
#   tools/scene.sh rebase  <id> --variant dense --decoys <id> ...
#   tools/scene.sh build   <id> [--variant dense]
#   tools/scene.sh preview <id> [--seed N] [--band ...] [--variant dense]
#                               [--outlines]
#
# Stages are separate on purpose: read the meta file before the props are ruled
# on against it, and read the rules before the sprites get cut. Where each prop
# actually goes is decided by the game, per playthrough - preview draws one such
# layout, so pass --seed to look at a particular game. See
# docs/scene-pipeline.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.venv"
PY="$VENV/bin/python"

if [ ! -x "$PY" ]; then
  echo "creating $VENV" >&2
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet -r "$ROOT/tools/requirements.txt"
fi

# Pulls --variant <name> out of the arguments wherever it sits, because a
# stage that quietly built the base spec instead would overwrite the level's
# own background, meta and scene with the variant's.
variant=""
rest=()
vflag=()
take_variant() {
  variant=""
  rest=()
  vflag=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --variant)
        [ $# -ge 2 ] || { echo "--variant needs a name" >&2; exit 2; }
        variant="$2"
        shift 2
        ;;
      --variant=*)
        variant="${1#--variant=}"
        shift
        ;;
      *)
        rest+=("$1")
        shift
        ;;
    esac
  done
  [ -z "$variant" ] || vflag=(--variant "$variant")
}

command="${1:-}"
shift || true
[ -n "$command" ] || { sed -n '2,10p' "${BASH_SOURCE[0]}" | cut -c3-; exit 1; }

cd "$ROOT"
export PYTHONPATH="$ROOT/tools:${PYTHONPATH:-}"

case "$command" in
  art)     exec "$PY" tools/generate_art.py "$@" ;;
  icon)    exec "$PY" tools/make_icons.py "$@" ;;
  mascot)  exec "$PY" tools/make_mascot.py "$@" ;;
  analyze) exec "$PY" tools/analyze_scene.py "$@" ;;
  regions) exec "$PY" tools/show_regions.py "$@" ;;
  fit)     exec "$PY" tools/fit_regions.py "$@" ;;
  bake)    exec "$PY" tools/bake_scene.py "$@" ;;
  place)   exec "$PY" tools/place_objects.py "$@" ;;
  rebase)  exec "$PY" tools/rebase_variant.py "$@" ;;
  preview) exec "$PY" tools/preview_scene.py "$@" ;;
  build)
    id="${1:?usage: tools/scene.sh build <id> [--variant <name>]}"
    shift
    take_variant "$@"
    set -- ${rest[@]+"${rest[@]}"}
    # A variant is a second backdrop for the same level, built from its own
    # spec beside the original: tools/scenes/<id>.dense.build.json.
    spec="tools/scenes/$id.build.json"
    [ -z "$variant" ] || spec="tools/scenes/$id.$variant.build.json"
    exec "$PY" tools/build_scene.py "$spec" "$@"
    ;;
  all)
    id="${1:?usage: tools/scene.sh all <id> --bg ... --sheets ...}"
    shift
    # Every stage builds the same scene, so the variant has to reach all four
    # of them: analyze writes the variant's meta, place rules on it, build
    # reads the variant's spec, and preview draws the room the others just
    # made.
    take_variant "$@"
    set -- ${rest[@]+"${rest[@]}"}
    dotted=""
    [ -z "$variant" ] || dotted=".$variant"
    "$PY" tools/analyze_scene.py "$id" ${vflag[@]+"${vflag[@]}"} "$@"
    # Between reading the room and ruling on the props: the meta is corrected
    # against the pixels it describes, and each surface is asked where it
    # still has room. What fit cannot safely decide it prints, and that is
    # for eyes - which is the other reason this stage is not the whole run.
    "$PY" tools/fit_regions.py "$id" ${vflag[@]+"${vflag[@]}"} --snap --spans
    "$PY" tools/place_objects.py "$id" ${vflag[@]+"${vflag[@]}"}
    "$PY" tools/build_scene.py "tools/scenes/$id$dotted.build.json"
    exec "$PY" tools/preview_scene.py "$id" ${vflag[@]+"${vflag[@]}"}
    ;;
  *) echo "unknown command: $command" >&2; exit 1 ;;
esac
