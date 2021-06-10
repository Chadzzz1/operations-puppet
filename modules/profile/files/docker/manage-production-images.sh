#!/bin/bash
cd /srv/images/production-images \
   && /srv/deployment/docker-pkg/venv/bin/docker-pkg -c /etc/production-images/config.yaml "$1" images \
   && /srv/deployment/docker-pkg/venv/bin/docker-pkg -c /etc/production-images/config-istio.yaml "$1" istio
