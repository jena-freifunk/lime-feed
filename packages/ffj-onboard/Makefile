# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Freifunk Jena first-boot onboard (hostname, shared root password, location)

include $(TOPDIR)/rules.mk

PKG_NAME:=ffj-onboard
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Freifunk Jena
PKG_LICENSE:=AGPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/ffj-onboard
  SECTION:=lime
  CATEGORY:=LibreMesh
  TITLE:=Freifunk Jena node onboard wizard
  DEPENDS:=+lime-system +ubus-lime-location +luci-lib-jsonc +libuci-lua +libubus-lua +uhttpd +rpcd
  PKGARCH:=all
endef

define Package/ffj-onboard/description
  One-shot web UI to set hostname, shared root password (FBW-compatible),
  and node location when lime-community is already preconfigured.
endef

define Build/Compile
endef

define Package/ffj-onboard/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/97-ffj-onboard $(1)/etc/uci-defaults/97-ffj-onboard
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/usr/libexec/rpcd/ffj-onboard $(1)/usr/libexec/rpcd/ffj-onboard
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/usr/share/rpcd/acl.d/ffj-onboard.json $(1)/usr/share/rpcd/acl.d/ffj-onboard.json
	$(INSTALL_DIR) $(1)/www
	$(INSTALL_DATA) ./files/www/ffj_onboard_index.html $(1)/www/ffj_onboard_index.html
	$(INSTALL_DIR) $(1)/www/ffj-onboard
	$(INSTALL_DATA) ./files/www/ffj-onboard/index.html $(1)/www/ffj-onboard/index.html
	$(INSTALL_DATA) ./files/www/ffj-onboard/app.js $(1)/www/ffj-onboard/app.js
	$(INSTALL_DATA) ./files/www/ffj-onboard/style.css $(1)/www/ffj-onboard/style.css
endef

define Package/ffj-onboard/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	/etc/init.d/rpcd restart >/dev/null 2>&1 || true
	/etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}
exit 0
endef

$(eval $(call BuildPackage,ffj-onboard))
