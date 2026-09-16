# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Freifunk Jena LibreMesh community profile (lime-community + SSH keys)

include $(TOPDIR)/rules.mk

PKG_NAME:=ffj-community
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Freifunk Jena
PKG_LICENSE:=AGPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/ffj-community
  SECTION:=lime
  CATEGORY:=LibreMesh
  TITLE:=Freifunk Jena community profile
  DEPENDS:=+lime-system
  PKGARCH:=all
endef

define Package/ffj-community/description
  Jena lime-community defaults and community SSH authorized_keys.
endef

define Package/ffj-community/conffiles
/etc/config/lime-community
/etc/dropbear/authorized_keys
endef

define Build/Compile
endef

define Package/ffj-community/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/lime-community $(1)/etc/config/lime-community
	$(INSTALL_DIR) $(1)/etc/dropbear
	$(INSTALL_DATA) ./files/etc/dropbear/authorized_keys $(1)/etc/dropbear/authorized_keys
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/80-ffj-community $(1)/etc/uci-defaults/80-ffj-community
endef

$(eval $(call BuildPackage,ffj-community))
