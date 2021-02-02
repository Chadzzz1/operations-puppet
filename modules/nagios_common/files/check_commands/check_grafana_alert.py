#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
  check_grafana_alert
  ~~~~~~~~~~~~~~~~~~~~~~~~

  Checks a Grafana dashboard and generates CRITICAL states if
  it has Grafana alerts in "alerting" state.

  The script requires the Grafana dashboard UID to operate.
  The UID could be found in Grafana dashboard URI which looks like the following:
  https://grafana.wikimedia.org/d/DASHBOARD_UID/DASHBOARD_NAME

  Usage:
    check_grafana_alert DASHBOARD_UID GRAFANA_URL

  Positional arguments:
    DASHBOARD_URI         Grafana dashboard URI
    GRAFANA_URL           URL of grafana

"""
import sys

import argparse
import json
import os
import urllib.request as request

ap = argparse.ArgumentParser(description='Grafana dashboard alert')
ap.add_argument('dashboard_uid', help='dashboard ID')
ap.add_argument('grafana_url', help="URL of grafana")
args = ap.parse_args()

# First - fetch the proper Dashboard ID, URI and title from API
dashboard_id = ''
dashboard_url = ''
dashboard_title = ''
try:
    req = request.Request('{}/api/dashboards/uid/{}'.format(
        args.grafana_url,
        args.dashboard_uid))
    req.add_header(
        'User-Agent',
        'wmf-icinga/{} root@wikimedia.org'.format(os.path.basename(__file__)))
    dashboard_info = json.load(request.urlopen(req))
    dashboard_id = dashboard_info['dashboard']['id']
    dashboard_url = '%s%s' % (
        args.grafana_url,
        dashboard_info['meta']['url']
    )
    dashboard_title = dashboard_info['dashboard']['title']
except Exception as e:
    print('UNKNOWN: failed to fetch info about dashboard with uid=%s due to exception: %s' % (
        args.dashboard_uid, e))
    sys.exit(3)

alerting_names = []
try:
    req = request.Request('{}/api/alerts?dashboardId={}&state=alerting'.format(
        args.grafana_url,
        dashboard_id))
    req.add_header(
        'User-Agent',
        'wmf-icinga/{} root@wikimedia.org'.format(os.path.basename(__file__)))
    data = json.load(request.urlopen(req))
    alerting_names = list(map(lambda alert: alert['name'], data))
except Exception as e:
    print('UNKNOWN: failed to check dashboard %s ( %s ) due to exception: %s' % (
        dashboard_title, dashboard_url, e))
    sys.exit(3)

if len(alerting_names) > 0:
    print('CRITICAL: %s ( %s ) is alerting: %s.' % (
        dashboard_title, dashboard_url, ', '.join(alerting_names)), file=sys.stderr)
    sys.exit(2)
else:
    print('OK: %s ( %s ) is not alerting.' % (
        dashboard_title, dashboard_url), file=sys.stderr)
    sys.exit(0)
