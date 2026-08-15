#!/bin/bash
set -euo pipefail

workspace="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")" && pwd)}"

if [ ! -d feeds/packages ]; then
    bash "$workspace/diy-part1.sh"

    sed -i 's|^src-git kdae .*|src-git kdae https://github.com/QiuSimons/luci-app-dae.git;kix|' feeds.conf.default
    cat <<'EOF' >>feeds.conf.default
src-git quickfile https://github.com/sbwml/luci-app-quickfile.git;main
src-git lucky https://github.com/gdy666/luci-app-lucky.git;main
src-git easytier https://github.com/EasyTier/luci-app-easytier.git;main
src-git istore https://github.com/linkease/istore.git;main
EOF

    mkdir -p package/custom
    git clone --depth 1 --branch master \
        https://github.com/eamonxg/luci-theme-aurora.git \
        package/custom/luci-theme-aurora
    git clone --depth 1 --branch master \
        https://github.com/eamonxg/luci-app-aurora-config.git \
        package/custom/luci-app-aurora-config
    git clone --depth 1 --branch main \
        https://github.com/sbwml/luci-app-diskman.git \
        package/custom/luci-app-diskman
    exit 0
fi

bash "$workspace/diy-part2.sh"

./scripts/feeds install -d y -p istore luci-app-store

set_config() {
    local symbol="$1"
    sed -i -e "/^CONFIG_${symbol}=.*/d" \
        -e "/^# CONFIG_${symbol} is not set$/d" .config
    printf 'CONFIG_%s=y\n' "$symbol" >>.config
}

unset_config() {
    local symbol="$1"
    sed -i -e "/^CONFIG_${symbol}=.*/d" \
        -e "/^# CONFIG_${symbol} is not set$/d" .config
    printf '# CONFIG_%s is not set\n' "$symbol" >>.config
}

set_kernel_config() {
    local file="$1"
    local symbol="$2"
    test -f "$file" || {
        echo "Kernel config fragment not found: $file" >&2
        exit 1
    }
    sed -i -e "/^CONFIG_${symbol}=.*/d" \
        -e "/^# CONFIG_${symbol} is not set$/d" "$file"
    printf 'CONFIG_%s=y\n' "$symbol" >>"$file"
}

unset_kernel_config() {
    local file="$1"
    local symbol="$2"
    test -f "$file" || {
        echo "Kernel config fragment not found: $file" >&2
        exit 1
    }
    sed -i -e "/^CONFIG_${symbol}=.*/d" \
        -e "/^# CONFIG_${symbol} is not set$/d" "$file"
    printf '# CONFIG_%s is not set\n' "$symbol" >>"$file"
}

# Always use OpenWrt's native toolchain.
unset_config 'EXTERNAL_TOOLCHAIN'

for symbol in \
    KERNEL_CGROUPS \
    KERNEL_CGROUP_BPF \
    PACKAGE_kmod-xdp-sockets-diag \
    PACKAGE_luci-app-aurora-config \
    PACKAGE_luci-app-diskman \
    PACKAGE_luci-app-easytier \
    PACKAGE_luci-app-lucky \
    PACKAGE_luci-app-quickfile \
    PACKAGE_luci-app-store \
    PACKAGE_luci-i18n-aurora-config-zh-cn \
    PACKAGE_luci-i18n-easytier-zh-cn \
    PACKAGE_luci-i18n-lucky-zh-cn \
    PACKAGE_luci-i18n-quickfile-zh-cn \
    PACKAGE_luci-nginx \
    PACKAGE_luci-theme-aurora; do
    set_config "$symbol"
done

for symbol in \
    PACKAGE_luci \
    PACKAGE_luci-light \
    PACKAGE_uhttpd \
    PACKAGE_uhttpd-mod-ubus; do
    unset_config "$symbol"
done

# Linux 6.18 added these symbols after OpenWrt's x86/64 fragment was generated.
# Put them in the last target fragment merged before CONFIG_KERNEL_* overrides.
kernel_config="target/linux/x86/64/config-6.18"
set_kernel_config "$kernel_config" "DRM_CLIENT_DEFAULT_FBDEV"
unset_kernel_config "$kernel_config" "KASAN"
unset_kernel_config "$kernel_config" "SLUB_DEBUG"
unset_kernel_config "$kernel_config" "SLUB_DEBUG_ON"
unset_kernel_config "$kernel_config" "SLUB_RCU_DEBUG"

mkdir -p files/etc/uci-defaults
cat <<'EOF' >files/etc/uci-defaults/99-quickfile-nginx
#!/bin/sh

if [ -x /usr/bin/quickfile ]; then
    uci set nginx.global.uci_enable='true'
    uci -q delete nginx._lan
    uci -q delete nginx._redirect2ssl
    uci set nginx._lan='server'
    uci -q delete nginx._lan.uci_manage_ssl
    uci -q delete nginx._lan.ssl_certificate
    uci -q delete nginx._lan.ssl_certificate_key
    uci -q delete nginx._lan.ssl_session_reuse
    uci add_list nginx._lan.listen='80 default_server'
    uci add_list nginx._lan.listen='[::]:80 default_server'
    uci add_list nginx._lan.include='conf.d/*.locations'
    uci set nginx._lan.access_log='off; # logd openwrt'
    uci commit nginx
fi

# Let luci-app-easytier manage its own tun0 interface, EasyTier zone, and
# forwarding section. lanfwet enables only LAN-to-EasyTier forwarding.
if uci -q show easytier >/dev/null; then
    uci set easytier.@easytier[0].auto_config_interface='1'
    uci set easytier.@easytier[0].auto_config_firewall='1'
    uci -q del_list easytier.@easytier[0].et_forward='lanfwet'
    uci add_list easytier.@easytier[0].et_forward='lanfwet'
    uci commit easytier
fi

exit 0
EOF
chmod +x files/etc/uci-defaults/99-quickfile-nginx
