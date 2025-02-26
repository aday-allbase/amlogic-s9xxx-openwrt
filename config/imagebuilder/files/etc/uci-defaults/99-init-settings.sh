#!/bin/sh

exec > /root/setup.log 2>&1

# dont remove!
# dont remove!
msg "Installed Time: $(date '+%A, %d %B %Y %T')"
msg "###############################################"
msg "Processor: $(ubus call system board | grep '\"system\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
msg "Device Model: $(ubus call system board | grep '\"model\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
msg "Device Board: $(ubus call system board | grep '\"board_name\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
sed -i "s#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' / ':'')+(luciversion||''),#_('Firmware Version'),(L.isObject(boardinfo.release)?boardinfo.release.description+' build by OPEN-WRT [ Ouc3kNF6 ]':''),#g" /www/luci-static/resources/view/status/include/10_system.js
sed -i -E "s|icons/port_%s.png|icons/port_%s.gif|g" /www/luci-static/resources/view/status/include/29_ports.js
if grep -q "ImmortalWrt" /etc/openwrt_release; then
  sed -i "s/\(DISTRIB_DESCRIPTION='ImmortalWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
  sed -i -E "s|services/ttyd|system/ttyd|g" /usr/share/ucode/luci/template/themes/material/header.ut
  sed -i -E "s|services/ttyd|system/ttyd|g" /usr/lib/lua/luci/view/themes/argon/header.htm
  msg Branch version: "$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
elif grep -q "OpenWrt" /etc/openwrt_release; then
  sed -i "s/\(DISTRIB_DESCRIPTION='OpenWrt [0-9]*\.[0-9]*\.[0-9]*\).*'/\1'/g" /etc/openwrt_release
  msg Branch version: "$(grep 'DISTRIB_DESCRIPTION=' /etc/openwrt_release | awk -F"'" '{print $2}')"
fi
echo "Tunnel Installed: $(opkg list-installed | grep -e luci-app-openclash -e luci-app-nikki -e luci-app-passwall | awk '{print $1}' | tr '\n' ' ')"
echo "###############################################"

# Set login root password
(echo "root"; sleep 1; echo "root") | passwd > /dev/null

# Set hostname and Timezone to Asia/Jakarta
echo "Setup NTP Server and Time Zone to Asia/Jakarta"
uci set system.@system[0].hostname='OPEN-WRT'
uci set system.@system[0].timezone='WIB-7'
uci set system.@system[0].zonename='Asia/Jakarta'
uci -q delete system.ntp.server
uci add_list system.ntp.server="pool.ntp.org"
uci add_list system.ntp.server="id.pool.ntp.org"
uci add_list system.ntp.server="time.google.com"
uci commit system

# configure wan interface
echo "Setup WAN and LAN Interface"
uci set network.lan.ipaddr="192.168.1.1"
uci set network.wan=interface 
uci set network.wan.proto='modemmanager'
uci set network.wan.device='/sys/devices/platform/scb/fd500000.pcie/pci0000:00/0000:00:00.0/0000:01:00.0/usb2/2-1'
uci set network.wan.apn='internet'
uci set network.wan.auth='none'
uci set network.wan.iptype='ipv4'
uci commit network
uci set firewall.@zone[1].network='wan'
uci commit firewall

# configure ipv6
uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra
uci -q delete dhcp.lan.ndp
uci commit dhcp

# custom repo and Disable opkg signature check
echo "Setup custom repo using dlopenwrtai Repo"
sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf

# set material as default theme
echo "Setup Default Theme"
uci set luci.main.mediaurlbase='/luci-static/material' && uci commit

echo "Setup misc settings"
# remove login password required when accessing terminal
uci set ttyd.@ttyd[0].command='/bin/bash --login'
uci commit

# remove huawei me909s usb-modeswitch
sed -i -e '/12d1:15c1/,+5d' /etc/usb-mode.json

# remove dw5821e usb-modeswitch
sed -i -e '/413c:81d7/,+5d' /etc/usb-mode.json

# Remove Thales MV31-W T99W175 usb-modeswitch
sed -i -e '/1e2d:00b3/,+5d' /etc/usb-mode.json

# setup auto vnstat database backup
sed -i 's/;DatabaseDir "\/var\/lib\/vnstat"/DatabaseDir "\/etc\/vnstat"/' /etc/vnstat.conf
mkdir -p /etc/vnstat
chmod +x /etc/init.d/vnstat_backup
bash /etc/init.d/vnstat_backup enable

# setup misc settings
sed -i 's/\[ -f \/etc\/banner \] && cat \/etc\/banner/#&/' /etc/profile
sed -i 's/\[ -n "$FAILSAFE" \] && cat \/etc\/banner.failsafe/#&/' /etc/profile
chmod +x /sbin/free.sh
chmod +x /usr/bin/speedtest

# Setup PHP
uci set uhttpd.main.ubus_prefix='/ubus'
uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
uci set uhttpd.main.index_page='cgi-bin/luci'
uci add_list uhttpd.main.index_page='index.html'
uci add_list uhttpd.main.index_page='index.php'
uci commit uhttpd
sed -i -E "s|memory_limit = [0-9]+M|memory_limit = 100M|g" /etc/php.ini
sed -i -E "s|display_errors = On|display_errors = Off|g" /etc/php.ini
ln -s /usr/bin/php-cli /usr/bin/php
[ -d /usr/lib/php8 ] && [ ! -d /usr/lib/php ] && ln -sf /usr/lib/php8 /usr/lib/php
/etc/init.d/uhttpd restart

# Setting Tinyfm
msg "Setting Tinyfm"
ln -s / /www/tinyfm/rootfs

if [ -f "/etc/profile.d/30-sysinfo.sh" ]; then
  rm -rf /etc/profile.d/30-sysinfo.sh
  mv /etc/profile.d/30-sysinfo.sh-bak /etc/profile.d/30-sysinfo.sh
else
  mv /etc/profile.d/30-sysinfo.sh-bak /etc/profile.d/30-sysinfo.sh
fi

echo "All first boot setup complete!"
rm -f /etc/uci-defaults/$(basename $0)
exit 0