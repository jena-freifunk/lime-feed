# Feed signing keys
#
# Generate locally:
#   ./scripts/gen-feed-keys.sh
#
# Commit only public material (feed.pub or feed.pub.pem).
# Keep feed.priv / feed.pem out of git (see ../.gitignore).
#
# After Pages deploy, paste the public key string into the firmware selector
# www/config.js → asu_repository_keys array, and set:
#   asu_repositories.lime_feed = "https://mmdevapp.github.io/lime-feed-ffj/packages.adb"
#
# OpenWrt buildroot overlay (apk): copy feed.pub.pem to
#   files/etc/apk/keys/ffj-lime-feed.pem
# and add the same packages.adb URL under files/etc/apk/repositories.d/
