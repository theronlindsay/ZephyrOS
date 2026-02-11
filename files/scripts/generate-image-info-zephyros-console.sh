#!/usr/bin/env bash
set -euo pipefail

# Wrapper for zephyros-console recipe
IMAGE_NAME=zephyros-console \
IMAGE_VENDOR=theronlindsay \
IMAGE_REF="ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros-console" \
FEDORA_VERSION=43 \
./generate-image-info.sh
