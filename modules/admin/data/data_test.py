#!/usr/bin/env python3

# 2014 Chase Pettet
# Tests to perform basic validation on data.yaml

import os
import re
import unittest
from collections import Counter, defaultdict
from collections.abc import Iterable

import yaml


def flatten(not_flat):
    """flatten a complex list of lists"""
    # https://stackoverflow.com/a/2158532/3075306
    for element in not_flat:
        if isinstance(element, Iterable) and not isinstance(element, str):
            yield from flatten(element)
        else:
            yield element


class DataTest(unittest.TestCase):

    admins = {}
    bad_privileges_re = [
        re.compile(r'systemctl (?:\*|edit)')
    ]
    system_gid_min = 900
    system_gid_max = 950
    system_uid_min = 900
    system_uid_max = 950

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

    def test_group_system_gid_range(self):
        """Ensure system group GID's are in the correct range"""
        groups = ['%s (gid: %s)' % (group, config.get('gid'))
                  for group, config in self.admins['groups'].items()
                  if config.get('system') and not
                  self.system_gid_min <= config.get('gid') <= self.system_gid_max]
        self.assertEqual(
            [], groups,
            'System groups GID must be in range [%s-%s]: %r' % (
                self.system_gid_min, self.system_gid_max, groups))

    def test_group_standard_gid_range(self):
        """Ensure groups GID's are in the correct range"""
        # some standard groups don't have a gid so we mock it as 1000 below
        groups = ['%s (gid: %s)' % (group, config.get('gid', '<unset assuming 1000>'))
                  for group, config in self.admins['groups'].items()
                  if not config.get('system')
                  and self.system_gid_min <= config.get('gid', 1000) <= self.system_gid_max]
        self.assertEqual(
            [], groups,
            'Standard groups GIDs must not be in system groups range [%s-%s]: %r' % (
                self.system_gid_min, self.system_gid_max, groups))

    def test_group_gids_are_uniques(self):
        """Ensure no two groups uses the same gid"""
        gids = filter(None, [
            v.get('gid', None) for k, v in self.admins['groups'].items()])
        dupes = [k for k, v in Counter(gids).items() if v > 1]
        self.assertEqual([], dupes, 'Duplicate group GIDs: %r' % dupes)

    def test_user_system_gid_range(self):
        """Ensure system users UID's are in the correct range"""
        users = ['%s (uid: %s)' % (user, config.get('uid'))
                 for user, config in self.admins['users'].items()
                 if config.get('system') and not
                 self.system_gid_min <= config.get('uid') <= self.system_gid_max]
        self.assertEqual(
            [], users,
            'System users UID must be in range [%s-%s]: %r' % (
                self.system_uid_min, self.system_uid_max, users))

    def test_user_standard_gid_range(self):
        """Ensure users UID's are in the correct range"""
        users = ['%s (uid: %s)' % (user, config.get('uid'))
                 for user, config in self.admins['users'].items()
                 if not config.get('system')
                 and self.system_gid_min <= config.get('uid') <= self.system_gid_max]
        self.assertEqual(
            [], users,
            'Standard user UIDs must not be in system groups range [%s-%s]: %r' % (
                self.system_uid_min, self.system_uid_max, users))

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
