#!/bin/bash
set -euo pipefail

add_feed() {
    local name="$1"
    local url="$2"
    grep -q "^[[:space:]]*src-git[[:space:]]\+$name[[:space:]]" feeds.conf.default || \
        printf 'src-git %s %s\n' "$name" "$url" >>feeds.conf.default
}

set_config() {
    local symbol="$1"
    sed -i -e "/^CONFIG_${symbol}=.*/d" \
        -e "/^# CONFIG_${symbol} is not set$/d" .config
    printf 'CONFIG_%s=y\n' "$symbol" >>.config
}

set_config_value() {
    local symbol="$1"
    local value="$2"
    sed -i -e "/^CONFIG_${symbol}=.*/d" \
        -e "/^# CONFIG_${symbol} is not set$/d" .config
    printf 'CONFIG_%s=%s\n' "$symbol" "$value" >>.config
}

clone_custom_package() {
    local repo="$1"
    local branch="$2"
    local directory="$3"
    test -d "$directory" || git clone --depth 1 --branch "$branch" "$repo" "$directory"
}

if [ ! -d feeds/packages ]; then
    add_feed lucky 'https://github.com/gdy666/luci-app-lucky.git;main'
    add_feed easytier 'https://github.com/EasyTier/luci-app-easytier.git;main'
    add_feed quickfile 'https://github.com/sbwml/luci-app-quickfile.git;main'
    add_feed clashoo 'https://github.com/kenzok8/openwrt-clashoo.git;main'
    mkdir -p package/custom
    clone_custom_package \
        'https://github.com/eamonxg/luci-theme-aurora.git' master \
        package/custom/luci-theme-aurora
    clone_custom_package \
        'https://github.com/eamonxg/luci-app-aurora-config.git' master \
        package/custom/luci-app-aurora-config
    exit 0
fi

for symbol in \
    PACKAGE_luci-theme-aurora \
    PACKAGE_luci-app-aurora-config \
    PACKAGE_luci-i18n-aurora-config-zh-cn \
    PACKAGE_luci-app-lucky \
    PACKAGE_luci-i18n-lucky-zh-cn \
    PACKAGE_luci-app-easytier \
    PACKAGE_luci-i18n-easytier-zh-cn \
    PACKAGE_luci-app-quickfile \
    PACKAGE_luci-i18n-quickfile-zh-cn \
    PACKAGE_clashoo \
    PACKAGE_luci-app-clashoo \
    PACKAGE_luci-i18n-clashoo-zh-cn; do
    set_config "$symbol"
done

# Keep the larger x86 rootfs size isolated from upstream .config changes.
set_config_value TARGET_ROOTFS_PARTSIZE 2048
