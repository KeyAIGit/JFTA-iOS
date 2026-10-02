import unittest
from pathlib import Path
from select_test_shard import partition, SHARDS

class ShardTests(unittest.TestCase):
    def test_exact_partition(self):
        source = '\n'.join(f'func testCase{i:02d}() {{}}' for i in range(19))
        all_names, _ = partition(source, 0)
        selected = [name for i in range(SHARDS) for name in partition(source, i)[1]]
        self.assertEqual(sorted(selected), all_names)
        self.assertEqual(len(selected), len(set(selected)))
    def test_real_ui_suite_is_covered_once(self):
        source = (Path(__file__).resolve().parents[1] / 'JFTAUITests/JFTAUITests.swift').read_text()
        names, _ = partition(source, 0)
        flattened = [name for i in range(SHARDS) for name in partition(source, i)[1]]
        self.assertEqual(sorted(flattened), names)
        self.assertGreaterEqual(len(names), 16)
    def test_rejects_invalid_index(self):
        for i in [-1, 4, 99]:
            with self.assertRaises(ValueError): partition('func testA() {}', i)
    def test_rejects_empty_source(self):
        with self.assertRaises(ValueError): partition('', 0)
    def test_rejects_duplicates(self):
        with self.assertRaises(ValueError): partition('func testA() {} func testA() {}', 0)
    def test_rejects_empty_shard(self):
        with self.assertRaises(ValueError): partition('func testA() {}', 3)
    def test_selection_is_deterministic(self):
        source = 'func testD() {} func testB() {} func testA() {} func testC() {}'
        self.assertEqual(partition(source, 0), partition(source, 0))
        self.assertEqual(partition(source, 0)[1], ['testA'])

if __name__ == '__main__':
    unittest.main(verbosity=2)
