#!/usr/bin/env python3
"""Partition every declared UI test once; never silently omit a test."""
import json
import re
import sys
from pathlib import Path

SHARDS = 4

def partition(source: str, index: int) -> tuple[list[str], list[str]]:
    if index not in range(SHARDS):
        raise ValueError('Shard must be 0, 1, 2 or 3')
    names = sorted(re.findall(r'\bfunc\s+(test\w+)\s*\(', source))
    if not names or len(names) != len(set(names)):
        raise ValueError('No tests found, or duplicate test method names')
    selected = names[index::SHARDS]
    if not selected:
        raise ValueError('Refusing an empty shard')
    return names, selected

def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit('Usage: select_test_shard.py INDEX OUTPUT_JSON')
    source = Path(__file__).resolve().parents[1] / 'JFTAUITests/JFTAUITests.swift'
    names, selected = partition(source.read_text(), int(sys.argv[1]))
    payload = {'shard': int(sys.argv[1]), 'shards': SHARDS, 'all_ui_tests': names, 'selected_ui_tests': selected, 'includes_core_tests': sys.argv[1] == '0'}
    Path(sys.argv[2]).write_text(json.dumps(payload, indent=2) + '\n')
    if sys.argv[1] == '0':
        print('-only-testing:JFTAUnitTests')
    for name in selected:
        print(f'-only-testing:JFTAUITests/JFTAUITests/{name}')

if __name__ == '__main__':
    main()
