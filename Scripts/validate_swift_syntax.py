#!/usr/bin/env python3
"""Optional grammar check; NOT an Apple SDK type-check/build. Requires tree-sitter and tree-sitter-swift."""
from pathlib import Path
import sys
from tree_sitter import Language, Parser
import tree_sitter_swift

ROOT = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
errors = []
sources = sorted(ROOT.glob("JoeToep*/**/*.swift"))
for source in sources:
    tree = parser.parse(source.read_bytes())
    stack = [tree.root_node]
    while stack:
        node = stack.pop()
        if node.type == "ERROR" or node.is_missing:
            errors.append(f"{source.relative_to(ROOT)}:{node.start_point.row + 1}:{node.start_point.column + 1}: {node.type}")
        stack.extend(node.children)
if errors:
    print("\n".join(errors)); sys.exit(1)
print(f"PASS Swift grammar parsing ({len(sources)} files; no Apple SDK type checking)")
