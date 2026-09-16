# lime-feed-ffj

Freifunk Jena package feed for LibreMesh: package sources plus the tooling that publishes
them as a binary feed on GitHub Pages (`.apk` + `packages.adb`).

Repository: [mmdevapp/lime-feed-ffj](https://github.com/mmdevapp/lime-feed-ffj).

Packages in this feed:

- **`ffj-community`** — Jena community profile: `/etc/config/lime-community` (hostname
  domain, IPv4/IPv6, WiFi SSID) and community SSH keys in `/etc/dropbear/authorized_keys`.
  First boot runs `lime-config` via `80-ffj-community`.
- **`ffj-onboard`** — onboard wizard: set **hostname**, **shared root password** (same
  mechanism as First Boot Wizard), and **map location** when `lime-community` is already
  preconfigured (install `ffj-community` in the image).

## ffj-onboard on the node

After install, open:

`http://thisnode.info/ffj-onboard/`  
(or `http://<node-ip>/ffj-onboard/`)

Flow:

1. Enter hostname, shared root password (min 8 chars), lat/lon (map, address search, or browser geolocation).
2. Submit → writes `lime-node`, calls `lime.utils.set_shared_root_password`, sets location via `lime.location`, runs `lime-config`, reboots.
3. Flag `lime-node.system.ffj_onboard_done=1` prevents showing the form again (redirects to `/app/`).

### Forcing `/` to the wizard

Until onboarding is done, `/` serves the wizard instead of LimeApp:

- `97-ffj-onboard` sets `uhttpd.main.index_page=ffj_onboard_index.html`, a stub that
  refreshes to `/ffj-onboard/`. It is numbered after lime-app's `96-lime-app-index_page`,
  which sets the same option to `lime_app_index.html` — on first boot uci-defaults run in
  alphabetical order, so the higher number wins.
- The previous value is kept in `lime-node.system.ffj_onboard_prev_index` and restored by
  `complete` before the reboot, so `/` goes straight to LimeApp afterwards.
- Only `/` is redirected; `/app/` and LuCI stay reachable during onboarding.

Security note: `status` / `complete` are allowed for the **unauthenticated** rpcd ACL until onboard is done (open LAN trust model, similar to FBW on first boot).

## Package layout

```text
packages/ffj-community/
  Makefile
  files/
    etc/config/lime-community
    etc/dropbear/authorized_keys
    etc/uci-defaults/80-ffj-community
packages/ffj-onboard/
  Makefile
  files/
    etc/uci-defaults/97-ffj-onboard
    usr/libexec/rpcd/ffj-onboard
    usr/share/rpcd/acl.d/ffj-onboard.json
    www/ffj_onboard_index.html
    www/ffj-onboard/{index.html,app.js,style.css}
```

## Build locally (no full SDK)

```sh
chmod +x scripts/*.sh
./scripts/build-apk.sh          # → dist/*.apk  (needs apk-tools v3)
./scripts/build-ipk.sh          # → dist/*.ipk  (opkg images only)
./scripts/build-feed.sh         # → dist/feed/ (.apk, packages.adb, Packages, .ipk)
```

Current LibreMesh/OpenWrt images use **apk**, not opkg. Copy the `.apk` to the node:

```sh
apk add --allow-untrusted /tmp/ffj-community-0.1.0-r1.apk /tmp/ffj-onboard-0.1.0-r1.apk
/etc/init.d/rpcd restart
```

`--allow-untrusted` is required until [`keys/feed.pub.pem`](keys/feed.pub.pem) is in `/etc/apk/keys` on the firmware. When `keys/feed.pem` exists (or `FFJ_FEED_KEY` points at it), `build-apk.sh` and `build-feed.sh` sign the `.apk` and `packages.adb` with it.

Check what a node would check:

```sh
# --keys-dir is resolved against --root, so it must be an absolute path.
apk --keys-dir "$PWD/keys" verify dist/feed/packages.adb dist/feed/*.apk
```

If `apk` on the build host fails with `libapk.so.3.0.0: cannot open shared object file`, point it at the meson build dir:

```sh
export APK_LIBDIR="$HOME/apk-tools/build/src"
# or: sudo cp "$HOME/apk-tools/build/src/libapk.so.3.0.0" /usr/local/lib && sudo ldconfig
```

### OpenWrt buildroot / SDK

Two different things: compiling the package from git (no feed key), and trusting the **binary** GitHub Pages feed at image build / on the node (needs the public key).

#### Compile from source

Clone [mmdevapp/lime-feed-ffj](https://github.com/mmdevapp/lime-feed-ffj) and add the `packages/` directory as a feed in `feeds.conf` (package Makefiles live there, not at the repo root):

```text
src-link ffj /path/to/lime-feed-ffj/packages
```

Then:

```sh
./scripts/feeds update ffj
./scripts/feeds install ffj-community ffj-onboard
make package/ffj-community/compile package/ffj-onboard/compile
```

`src-link` / `src-git` is unsigned source. Do not put the feed public key in `feeds.conf`.

#### Binary feed + public key (apk)

LibreMesh/OpenWrt **main** uses apk. The feed public key is the EC PEM in [`keys/feed.pub.pem`](keys/feed.pub.pem) (generate with `./scripts/gen-feed-keys.sh` if missing; never commit `keys/feed.pem`).

Copy it into the buildroot **files overlay** so the image has `/etc/apk/keys/…` and a repository entry. From the OpenWrt/LibreMesh tree:

```sh
mkdir -p files/etc/apk/keys files/etc/apk/repositories.d
install -m 0644 /path/to/lime-feed-ffj/keys/feed.pub.pem \
  files/etc/apk/keys/ffj-lime-feed.pem
printf '%s\n' 'https://mmdevapp.github.io/lime-feed-ffj/packages.adb' \
  > files/etc/apk/repositories.d/ffj-lime-feed.list
```

Then `make` (or ImageBuilder `make image`) as usual. On the node, `apk update` / `apk add ffj-onboard` can verify the feed without `--allow-untrusted`.

ImageBuilder also reads `keys/*.pem`. You can copy the same file into the ImageBuilder `keys/` directory:

```sh
install -m 0644 /path/to/lime-feed-ffj/keys/feed.pub.pem \
  keys/ffj-lime-feed.pem
```

Add the Pages URL to the ImageBuilder `repositories` file (apk) next to the other `packages.adb` lines.

#### Binary feed (opkg / 24.10)

If the image still uses opkg, add a usign public key (`keys/feed.pub` from `usign -G`, not the PEM file) and a `src/gz` line:

```text
src/gz ffj_lime https://mmdevapp.github.io/lime-feed-ffj
```

Install the key with OpenWrt’s `opkg-key add keys/feed.pub`, or drop it into `files/etc/opkg/keys/` (filename is the key fingerprint). PEM `feed.pub.pem` is **not** an opkg/usign key.

## GitHub Pages feed (ASU)

ASU does **not** consume the git URL. It needs a **binary feed**.

GitHub Pages for this repo is:

`https://mmdevapp.github.io/lime-feed-ffj/`

1. Enable **Pages** on [mmdevapp/lime-feed-ffj](https://github.com/mmdevapp/lime-feed-ffj) (source: GitHub Actions).
2. Workflow [`.github/workflows/pages-feed.yml`](.github/workflows/pages-feed.yml) builds `dist/feed` and deploys it.
3. Signing: `./scripts/gen-feed-keys.sh`, store the **private** key (`keys/feed.pem`) as Actions secret `FFJ_FEED_PRIV`, and commit `keys/feed.pub.pem`. CI writes the secret back to `keys/feed.pem`, signs the `.apk` plus `packages.adb`, and fails the run if `apk verify` rejects them. Without the secret the feed is published unsigned. Never commit `keys/feed.pem`.
4. For LibreMesh ASU (`packages.adb`): rebuild the feed with the OpenWrt/`apk` toolchain so `packages.adb` is present on Pages (see `FEED.txt` if missing after a plain CI run).
5. In the firmware selector [`www/config.js`](../freifunk-jena-firmware-selecctor/www/config.js):

```js
asu_repositories: {
  // ...
  lime_feed: "https://mmdevapp.github.io/lime-feed-ffj/packages.adb",
},
asu_repository_keys: [
  // ... existing keys ...,
  "<PEM from keys/feed.pub.pem, newlines as \\n>",
],
```

Flavors `default` and `ffjnovpn` list `"ffj-community"` and `"ffj-onboard"`.

## Access URL

Document for installers: after flashing Jena firmware with this package, complete setup at **`/ffj-onboard/`** before using LimeApp.
