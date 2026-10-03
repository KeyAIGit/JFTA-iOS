#!/usr/bin/env python3
"""Unit checks for simulator selection; no Mac or simulated xcodebuild result."""
import unittest
from select_simulator import choose

class SimulatorSelectionTests(unittest.TestCase):
    def device(self, name='iPhone 17', available=True, uid='00000000-0000-0000-0000-000000000001'):
        return {'name':name, 'isAvailable':available, 'udid':uid}
    def test_picks_newest_ios(self):
        d = self.device()
        result = choose({'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-18-5':[d], 'com.apple.CoreSimulator.SimRuntime.iOS-26-2':[dict(d, name='iPhone 17 Pro')]}})
        self.assertTrue(result['runtime'].endswith('26-2'))
    def test_ignores_ipad(self):
        with self.assertRaises(ValueError): choose({'devices':{'x.iOS-26-2':[self.device('iPad Pro')]}})
    def test_ignores_unavailable(self):
        with self.assertRaises(ValueError): choose({'devices':{'x.iOS-26-2':[self.device(available=False)]}})
    def test_ignores_old_ios(self):
        with self.assertRaises(ValueError): choose({'devices':{'x.iOS-16-4':[self.device()]}})
    def test_rejects_bad_udid(self):
        with self.assertRaises(ValueError): choose({'devices':{'x.iOS-26-2':[self.device(uid='bad')]}})
    def test_prefers_standard_size(self):
        result=choose({'devices':{'x.iOS-26-2':[self.device('iPhone 17 Pro Max'),self.device('iPhone 17')]}})
        self.assertEqual(result['name'],'iPhone 17')
    def test_compact_prefers_se_over_larger_newer_phone(self):
        payload={'devices': {'x.iOS-26-2':[self.device('iPhone SE (3rd generation)')], 'x.iOS-26-5':[self.device('iPhone Air')]}}
        self.assertEqual(choose(payload, 'compact')['name'], 'iPhone SE (3rd generation)')
    def test_compact_falls_back_without_downloading(self):
        self.assertEqual(choose({'devices': {'x.iOS-26-5':[self.device('iPhone 17'), self.device('iPhone 17 Pro Max')]}}, 'compact')['name'], 'iPhone 17')
    def test_invalid_kind_fails(self):
        with self.assertRaises(ValueError): choose({}, 'unknown')
    def test_missing_payload_fails(self):
        with self.assertRaises(ValueError):choose({})

if __name__ == '__main__': unittest.main(verbosity=2)
