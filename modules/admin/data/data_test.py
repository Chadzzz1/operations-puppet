#!/usr/bin/env python3

# 2014 Chase Pettet
# Tests to perform basic validation on data.yaml

import os
import re
import unittest
from collections import Counter, Iterable, defaultdict

import yaml


def flatten(not_flat):
    '''flatten a complex list of lists'''
    # https://stackoverflow.com/a/2158532/3075306
    for element in not_flat:
        if isinstance(element, Iterable) and not isinstance(element, str):
            for sub_list in flatten(element):
                yield sub_list
        else:
            yield element


class DataTest(unittest.TestCase):

    admins = None
    bad_privileges_re = [
        re.compile(r'systemctl (?:\*|edit)')
    ]

    @classmethod
    def setUpClass(cls):
        with open(os.path.join(os.path.dirname(__file__), 'data.yaml')) as f:
            cls.admins = yaml.safe_load(f)

    def test_for_backdoor_sudo(self):
        """Ensure sudo commands which are too permissive are not added"""
        bad_privileges = defaultdict(list)
        for group, val in self.admins['groups'].items():
            for privilege in val.get('privileges', []):
                for priv_re in self.bad_privileges_re:
                    if priv_re.search(privilege):
                        bad_privileges[group].append(privilege)
        self.assertEqual(
                {}, bad_privileges,
                'The following groups define banned privileges: %r' % bad_privileges)

    def test_group_gids_are_uniques(self):
        """Ensure no two groups uses the same gid"""
        gids = filter(None, [
            v.get('gid', None) for k, v in self.admins['groups'].items()])
        dupes = [k for k, v in Counter(gids).items() if v > 1]
        self.assertEqual([], dupes, 'Duplicate group GIDs: %r' % dupes)

    def test_absent_members(self):
        """Ensure absent users in the absent group and have ensure => absent"""
        absent_members = set(self.admins['groups']['absent']['members'])
        absentees = set(
            username
            for username, val in self.admins['users'].items()
            if val['ensure'] == 'absent'
            )
        self.maxDiff = None
        self.longMessage = True
        self.assertSetEqual(
            absent_members,
            absentees,
            'Absent users are both in "absent" group (first set)'
            'and in marked "ensure: absent" (second set)')

    def test_group_members(self):
        """Ensure group members are real users"""
        present_users = set(
            username
            for username, val in self.admins['users'].items()
            if val['ensure'] == 'present'
            )
        present_group_members = set(
            user for user in flatten(
                value['members'] for group, value in self.admins['groups'].items()
                if group not in ['absent', 'absent_ldap']))
        missing_users = present_group_members - present_users
        self.assertEqual(
            missing_users, set(),
            "The following users are members of a group but don't exist: {}".format(
                ','.join(missing_users)))


if __name__ == '__main__':
    unittest.main()
