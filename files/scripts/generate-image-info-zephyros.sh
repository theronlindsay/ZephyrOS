#!/usr/bin/env bash
set -euo pipefail

# Wrapper for zephyros recipe
IMAGE_NAME=zephyros \
IMAGE_VENDOR=theronlindsay \
IMAGE_REF="ostree-image-signed:docker://ghcr.io/theronlindsay/zephyros" \
FEDORA_VERSION=43 \
./generate-image-info.sh
