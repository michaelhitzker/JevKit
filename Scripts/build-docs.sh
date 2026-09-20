#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift package dump-symbol-graph --minimum-access-level public
symbol_dir=.build/jevkit-doc-symbols
python3 - <<'PYTHON'
import json
import shutil
from pathlib import Path
root = Path(".build")
target = root / "jevkit-doc-symbols"
target.mkdir(exist_ok=True)
for old in target.glob("*.json"):
    old.unlink()
sources = list(root.rglob("JevKit.symbols.json"))
source = max(sources, key=lambda path: path.stat().st_mtime).parent
for graph in source.glob("*.symbols.json"):
    if json.loads(graph.read_text())["module"]["name"] == "JevKit":
        shutil.copyfile(graph, target / graph.name)
PYTHON
if command -v docc >/dev/null 2>&1; then
    docc_command=(docc)
else
    docc_command=(xcrun docc)
fi
"${docc_command[@]}" convert Sources/JevKit/JevKit.docc \
    --additional-symbol-graph-dir "$symbol_dir" \
    --output-path .build/JevKit.doccarchive \
    --fallback-display-name JevKit \
    --fallback-bundle-identifier org.jevkit.documentation \
    --warnings-as-errors
