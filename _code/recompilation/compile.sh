#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)
cd "$SCRIPT_DIR"

ls -1 *.dot \
    | cut -d. -f1 \
    | xargs -I {} -n1 dot -v -Tpng {}.dot -o {}.png

mv *.png ../../public/recompilation/
