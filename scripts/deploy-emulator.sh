#!/usr/bin/env bash
# Copies dist/KindleShowcase and dist/KindleWiki into the userstore.img of the Kindle QEMU emulator
# (showing up as /mnt/us/KindleShowcase and /mnt/us/KindleWiki inside the guest).
#
#   scripts/deploy-emulator.sh [path/to/KindleEmulator]      (default: ~/Developer/KindleEmulator)
#
# The emulator MUST be shut down first. Needs e2fsprogs (brew install e2fsprogs).
set -euo pipefail
cd "$(dirname "$0")/.."

EMU=${1:-$HOME/Developer/KindleEmulator}
IMG=$EMU/userstore.img

[ -f "$IMG" ] || { echo "no $IMG"; exit 1; }
[ -f "dist/KindleWiki" ] || { echo "no dist/KindleWiki -- run ./build.sh first"; exit 1; }
if pgrep -f "qemu-system-arm.*userstore.img" >/dev/null; then
  echo "QEMU is running with this image. Shut the emulator down first."; exit 1
fi

E2FS=$(brew --prefix e2fsprogs 2>/dev/null || echo /opt/homebrew/opt/e2fsprogs)
export PATH="$E2FS/sbin:$E2FS/bin:$PATH"

# The image is usually left with an unreplayed ext4 journal; e2fsck replays it safely.
# (exit code 1 just means "errors corrected", e.g. the journal was replayed)
rc=0; e2fsck -fp "$IMG" || rc=$?
[ "$rc" -le 1 ] || { echo "e2fsck failed ($rc)"; exit 1; }

if [ -f "dist/KindleShowcase" ]; then
  debugfs -w -R "rm KindleShowcase" "$IMG" >/dev/null 2>&1 || true
  debugfs -w -R "write dist/KindleShowcase KindleShowcase" "$IMG"
  debugfs -w -R "set_inode_field KindleShowcase mode 0100755" "$IMG"
  debugfs -R "stat KindleShowcase" "$IMG" | head -3
fi

if [ -f "dist/KindleWiki" ]; then
  debugfs -w -R "rm KindleWiki" "$IMG" >/dev/null 2>&1 || true
  debugfs -w -R "write dist/KindleWiki KindleWiki" "$IMG"
  debugfs -w -R "set_inode_field KindleWiki mode 0100755" "$IMG"
  debugfs -R "stat KindleWiki" "$IMG" | head -3
fi
echo
echo "Done. In the emulator's serial shell:"
echo "  cp /mnt/us/KindleWiki /tmp/ && DISPLAY=:0 /tmp/KindleWiki"
