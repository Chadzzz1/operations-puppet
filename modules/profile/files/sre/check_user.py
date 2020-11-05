#!/usr/bin/env python3
"""A simple example of how to access the Google Analytics API."""

from argparse import ArgumentParser
from configparser import ConfigParser
from os import access, R_OK
from textwrap import dedent

from apiclient.discovery import build
from google.oauth2 import service_account


class GsuiteUsers:
    """Class for listing Gsuite managed users"""

    api_name = 'admin'
    api_version = 'directory_v1'
    scopes = ['https://www.googleapis.com/auth/admin.directory.user.readonly']

    def __init__(self, key_file_location, impersonate=None):
        self.key_file_location = key_file_location
        self.impersonate = impersonate
        self.domain = self.impersonate.split('@', 1)[1]
        self._credentials = None
        self._service = None

    @property
    def credentials(self):
        """Return a credentials object"""
        if self._credentials is None:
            self._credentials = service_account.Credentials.from_service_account_file(
                self.key_file_location, scopes=self.scopes)
            if self.impersonate is not None:
                self._credentials = self._credentials.with_subject(self.impersonate)
        return self._credentials

    @property
    def service(self):
        """Return a service object"""
        if self._service is None:
            self._service = build(self.api_name, self.api_version, credentials=self.credentials)
        return self._service

    def emails(self):
        """A generator to list all emails managed by gsuite"""
        page_token = None
        while True:
            results = self.get_users(page_token)
            for data in results.get('users', []):
                yield data['primaryEmail']
                for alias in data.get('aliases', []):
                    yield alias
            page_token = results.get('nextPageToken')
            if page_token is None:
                break

    def get_users(self, page_token=None, max_results=25):
        """Get a list of users"""
        return self.service.users().list(
            domain=self.domain, maxResults=max_results, pageToken=page_token).execute()

    def get_user(self, email):
        """Get a users object from the primary email address

        Parameters:
            email (str): The primary email address of the user

        Returns:
            : An object representing the user

        """
        return self.service.users().get(userKey=email).execute()


def get_args():
    """Parse arguments"""
    parser = ArgumentParser(description=__doc__)
    parser.add_argument('-i', '--impersonate', help='A super admin email address')
    parser.add_argument('-c', '--config', default='/etc/check_user.conf',
                        help='Location of the config file')
    parser.add_argument('-K', '--key_file',
                        help='The path to a valid service account JSON key file')
    parser.add_argument('email', help='The primary email address of the user')
    return parser.parse_args()


def main():
    """Main entry point"""
    args = get_args()
    config = ConfigParser()
    if access(args.config, R_OK):
        config.read(args.config)
    # prefer arguments to config file
    try:
        impersonate = args.impersonate if args.impersonate else config['DEFAULT']['impersonate']
        key_file = args.key_file if args.key_file else config['DEFAULT']['key_file']
    except KeyError as error:
        return 'no {} specified'.format(error)
    if not access(key_file, R_OK):
        return 'unable to access {}'.format(key_file)

    users = GsuiteUsers(key_file, impersonate)
    user = users.get_user(args.email)
    # I dont think there would ever be more then one manager but just in case
    manager = ', '.join([r['value'] for r in user['relations'] if r['type'] == 'manager'])
    msg = """
    name:\t\t{}
    title:\t\t{}
    manager:\t{}
    agreedToTerms:\t{}
    """.format(user['name']['fullName'],
               user['organizations'][0]['title'],
               manager,
               user['agreedToTerms'])
    print(dedent(msg))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
