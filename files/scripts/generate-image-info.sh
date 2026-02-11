#!/usr/bin/env bash
set -euo pipefail

# Generates /usr/share/ublue-os/image-info.json with a date-based version.
# Supports overrides via environment variables (use in recipe's script module):
# IMAGE_NAME, IMAGE_VENDOR, IMAGE_REF, IMAGE_TAG, IMAGE_BRANCH,
# BASE_IMAGE_NAME, FEDORA_VERSION, VERSION_PRETTY

OUT=/usr/share/ublue-os/image-info.json
mkdir -p "$(dirname "$OUT")"

# Defaults (can be overridden by environment variables in the recipe)
IMAGE_NAME="${IMAGE_NAME:-zephyros}"
IMAGE_VENDOR="${IMAGE_VENDOR:-theronlindsay}"
IMAGE_REF="${IMAGE_REF:-ostree-image-signed:docker://ghcr.io/theronlindsay/${IMAGE_NAME}}"
IMAGE_TAG="${IMAGE_TAG:-stable}"
IMAGE_BRANCH="${IMAGE_BRANCH:-stable}"
BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
FEDORA_VERSION="${FEDORA_VERSION:-43}"

DATE="$(date +%Y%m%d)"
VERSION="${FEDORA_VERSION}.${DATE}"
VERSION_PRETTY="${VERSION_PRETTY:-Stable (F${VERSION})}"

cat > "$OUT" <<EOF
{
  "image-name": "${IMAGE_NAME}",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-ref": "${IMAGE_REF}",
  "image-tag": "${IMAGE_TAG}",
  "image-branch": "${IMAGE_BRANCH}",
  "base-image-name": "${BASE_IMAGE_NAME}",
  "fedora-version": "${FEDORA_VERSION}",
  "version": "${VERSION}",
  "version-pretty": "${VERSION_PRETTY}"
}
EOF

chmod 0644 "$OUT"

echo "Wrote $OUT"
