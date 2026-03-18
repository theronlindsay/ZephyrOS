#!/usr/bin/env bash
set -euo pipefail

FONT_URL="https://github.com/samuelngs/apple-emoji-linux/releases/latest/download/AppleColorEmoji.ttf"

# Guide says system-wide install: put the font under /usr/share/fonts/.
DEST_DIR="/usr/share/fonts/AppleColorEmoji"
FONT_FILE="${DEST_DIR}/AppleColorEmoji.ttf"

GENERIC_CONF="/etc/fonts/conf.d/60-generic.conf"

log() {
  echo "[apple-emoji] $1"
}

mkdir -p "${DEST_DIR}"

if [[ ! -s "${FONT_FILE}" ]]; then
  log "Downloading AppleColorEmoji.ttf..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${FONT_URL}" -o "${FONT_FILE}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${FONT_FILE}" "${FONT_URL}"
  else
    log "Neither curl nor wget found; attempting to install one via dnf."
    dnf -y install curl || dnf -y install wget
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "${FONT_URL}" -o "${FONT_FILE}"
    else
      wget -qO "${FONT_FILE}" "${FONT_URL}"
    fi
  fi
else
  log "AppleColorEmoji.ttf already present."
fi

# Put Apple Color Emoji as the FIRST preferred emoji font.
# The base image ships /etc/fonts/conf.d/60-generic.conf as a symlink into
# /usr/share/fontconfig/conf.avail/60-generic.conf.
if [[ -f "${GENERIC_CONF}" ]]; then
  log "Reordering emoji preference in 60-generic.conf (Apple first)..."

  # Swap the two contiguous lines in the <prefer> block.
  # This matches the upstream conf.avail/60-generic.conf structure:
  #   <family>Noto Color Emoji</family> <!-- Google -->
  #   <family>Apple Color Emoji</family> <!-- Apple -->
  perl -0777 -i -pe '
    s#(\s*)<family>\s*Noto\s+Color\s+Emoji\s*</family>\s*<!--\s*Google\s*-->\s*\n(\s*)<family>\s*Apple\s+Color\s+Emoji\s*</family>\s*<!--\s*Apple\s*-->#$2<family>Apple Color Emoji</family> <!-- Apple -->\n$1<family>Noto Color Emoji</family> <!-- Google -->#s
  ' "${GENERIC_CONF}" || true
else
  log "WARNING: ${GENERIC_CONF} not found; skipping preference reorder."
fi

# Guide step 3: per-user fontconfig override for new users.
# This gets copied into /etc/skel, so it affects users created later.
SKEL_DIR="/etc/skel/.config/fontconfig"
mkdir -p "${SKEL_DIR}"

cat > "${SKEL_DIR}/fonts.conf" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>serif</family>
    <prefer>
      <family>Apple Color Emoji</family>
    </prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Apple Color Emoji</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>Apple Color Emoji</family>
    </prefer>
  </alias>
  <match target="pattern">
    <test qual="any" name="family"><string>Noto Color Emoji</string></test>
    <edit name="family" mode="assign" binding="same"><string>Apple Color Emoji</string></edit>
  </match>
</fontconfig>
EOF

log "Refreshing font cache..."
fc-cache -f -v

log "Done."

