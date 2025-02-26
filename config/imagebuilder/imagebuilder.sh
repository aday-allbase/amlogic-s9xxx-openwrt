#!/bin/bash
#================================================================================================
#
# Set default parameters
make_path="${PWD}"
openwrt_dir="imagebuilder"
imagebuilder_path="${make_path}/${openwrt_dir}"
custom_files_path="${make_path}/config/imagebuilder/files"
custom_config_file="${make_path}/config/imagebuilder/config"

# Set default parameters
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
#
#================================================================================================

# Encountered a serious error, abort the script execution
error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

# Downloading OpenWrt ImageBuilder
download_imagebuilder() {
    cd ${make_path}
    echo -e "${STEPS} Start downloading OpenWrt files..."

    # Downloading imagebuilder files
    download_file="https://downloads.${op_sourse}.org/releases/${op_branch}/targets/armsr/armv8/${op_sourse}-imagebuilder-${op_branch}-armsr-armv8.Linux-x86_64.tar.zst"
    curl -fsSOL ${download_file}
    [[ "${?}" -eq "0" ]] || error_msg "Download failed: [ ${download_file} ]"

    # Unzip and change the directory name
    tar -I zstd -xvf *-imagebuilder-*.tar.zst -C . && sync && rm -f *-imagebuilder-*.tar.zst
    mv -f *-imagebuilder-* ${openwrt_dir}

    sync && sleep 3
    echo -e "${INFO} [ ${make_path} ] directory status: $(ls -al 2>/dev/null)"
}

# Adjust related files in the ImageBuilder directory
adjust_settings() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adjusting .config file settings..."
    
    # Update 99-first-setup
    FIRST_SETUP_FILE="${custom_files_path}/etc/uci-defaults/99-first-setup"
    if [[ -s "${FIRST_SETUP_FILE}" ]]; then
        sed -i "s|Ouc3kNF6|$DTM|g" "${FIRST_SETUP_FILE}"
        echo -e "${INFO} Updated 99-first-setup with date: $DTM"
    else
        echo -e "${WARNING} File 99-first-setup not found or is empty at: ${FIRST_SETUP_FILE}"
    fi
    
    # Update repositories.conf
    REPO_CONF="repositories.conf"
    if [[ -s "${REPO_CONF}" ]]; then
        sed -i '\|option check_signature| s|^|#|' "${REPO_CONF}"
        echo -e "${INFO} Updated repositories.conf to disable signature checks."
    else
        echo -e "${WARNING} File repositories.conf not found or is empty."
    fi

    # For .config file
    if [[ -s ".config" ]]; then
        # Root filesystem archives
        sed -i "s|CONFIG_TARGET_ROOTFS_CPIOGZ=.*|# CONFIG_TARGET_ROOTFS_CPIOGZ is not set|g" .config
        # Root filesystem images
        sed -i "s|CONFIG_TARGET_ROOTFS_EXT4FS=.*|# CONFIG_TARGET_ROOTFS_EXT4FS is not set|g" .config
        sed -i "s|CONFIG_TARGET_ROOTFS_SQUASHFS=.*|# CONFIG_TARGET_ROOTFS_SQUASHFS is not set|g" .config
        sed -i "s|CONFIG_TARGET_IMAGES_GZIP=.*|# CONFIG_TARGET_IMAGES_GZIP is not set|g" .config
    else
        echo -e "${INFO} [ ${imagebuilder_path} ] directory status: $(ls -al 2>/dev/null)"
        error_msg "There is no .config file in the [ ${download_file} ]"
    fi
    
# Configure partition sizes
configure_partitions() {
    log "INFO" "Configuring partition sizes"
    # Set kernel and rootfs partition sizes
    sed -i "s/CONFIG_TARGET_KERNEL_PARTSIZE=.*/CONFIG_TARGET_KERNEL_PARTSIZE=128/" .config
    sed -i "s/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=1024/" .config
}

    # For other files
    # ......

    sync && sleep 3
    echo -e "${INFO} [ ${imagebuilder_path} ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom packages
custom_packages() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom packages..."

    # Create a [ packages ] directory
    [[ -d "packages" ]] || mkdir packages
    cd packages

    # Download luci-app-amlogic
    amlogic_api="https://api.github.com/repos/ophub/luci-app-amlogic/releases"
    #
    amlogic_file="luci-app-amlogic"
    amlogic_file_down="$(curl -s ${amlogic_api} | grep "browser_download_url" | grep -oE "https.*${amlogic_name}.*.ipk" | head -n 1)"
    curl -fsSOJL ${amlogic_file_down}
    [[ "${?}" -eq "0" ]] || error_msg "[ ${amlogic_file} ] download failed!"
    echo -e "${INFO} The [ ${amlogic_file} ] is downloaded successfully."
    
    # Download other luci-app-xxx
    # ......

    sync && sleep 3
    echo -e "${INFO} [ packages ] directory status: $(ls -al 2>/dev/null)"
}

# Add custom files
custom_files() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start adding custom files..."

    if [[ -d "${custom_files_path}" ]]; then
        # Copy custom files
        [[ -d "files" ]] || mkdir -p files
        cp -rf ${custom_files_path}/* files

        sync && sleep 3
        echo -e "${INFO} [ files ] directory status: $(ls files -al 2>/dev/null)"
    else
        echo -e "${INFO} No customized files were added."
    fi
}

# Rebuild OpenWrt firmware
rebuild_firmware() {
    cd ${imagebuilder_path}
    echo -e "${STEPS} Start building OpenWrt with Image Builder..."

    # Selecting default packages, lib, theme, app and i18n, etc.
    my_packages="
cgi-io libiwinfo libiwinfo-data libiwinfo-lua liblua \
luci-lib-base luci-lib-ip luci-lib-jsonc luci-lib-nixio luci-mod-admin-full \
cpusage ttyd dmesg luci-lib-ipkg \
zram-swap adb parted losetup resize2fs luci-ssl block-mount htop wget-ssl \
tar unrar gzip jq luci-app-ttyd nano httping screen openssh-sftp-server \
liblucihttp liblucihttp-lua libubus-lua lua luci-app-firewall luci-app-opkg \
ca-bundle coreutils-sleep fontconfig coreutils-whoami file lolcat \
luci-lib-base luci-lib-ip luci-lib-jsonc luci-lib-nixio luci-mod-admin-full \
luci-mod-network luci-mod-status luci-mod-system luci-proto-ipv6 luci-proto-ppp \
luci-theme-bootstrap px5g-wolfssl rpcd rpcd-mod-file rpcd-mod-iwinfo rpcd-mod-luci \
rpcd-mod-rrdns uhttpd uhttpd-mod-ubus coreutils coreutils-base64 coreutils-stty libc coreutils-stat \
libuci-lua iptables iptables-legacy \
iptables-mod-iprange iptables-mod-socket iptables-mod-tproxy kmod-ipt-nat luci-lua-runtime zoneinfo-asia zoneinfo-core \
perl perlbase-base perlbase-bytes perlbase-class perlbase-config perlbase-cwd perlbase-dynaloader perlbase-errno perlbase-essential perlbase-fcntl perlbase-file \
perlbase-filehandle perlbase-i18n perlbase-integer perlbase-io perlbase-list perlbase-locale perlbase-params perlbase-posix \
perlbase-re perlbase-scalar perlbase-selectsaver perlbase-socket perlbase-symbol perlbase-tie perlbase-time perlbase-unicore perlbase-utf8 perlbase-xsloader \

coreutils-nohup bash -dnsmasq dnsmasq-full curl ca-certificates ipset ip-full libcap libcap-bin ruby ruby-yaml kmod-tun kmod-inet-diag unzip kmod-nft-tproxy luci-compat luci luci-base \

kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 kmod-usb-net-asix kmod-usb-net-asix-ax88179 \

kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan uqmi luci-proto-qmi \
kmod-usb-net-cdc-ether kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan qmi-utils \
kmod-usb-serial-qualcomm kmod-usb-acm kmod-usb-net-cdc-ncm kmod-usb-net-cdc-mbim umbim \
modemmanager  modemmanager-rpcd luci-proto-modemmanager libmbim libqmi usbutils luci-proto-mbim luci-proto-ncm \
kmod-usb-net-huawei-cdc-ncm kmod-usb-net-cdc-ether kmod-usb-net-rndis kmod-usb-net-sierrawireless kmod-usb-ohci kmod-usb-serial-sierrawireless \
kmod-usb-uhci kmod-usb2 kmod-usb-ehci kmod-usb-net-ipheth usbmuxd libusbmuxd-utils libimobiledevice-utils usb-modeswitch kmod-nls-utf8 mbim-utils \
kmod-phy-broadcom kmod-phylib-broadcom kmod-tg3 libusb-1.0-0 \

kmod-usb-storage kmod-usb-storage-uas ntfs-3g \

vnstat2 vnstati2 luci-app-vnstat2 \

luci-theme-material \

php8 php8-fastcgi php8-fpm php8-mod-session php8-mod-ctype php8-mod-fileinfo php8-mod-zip php8-mod-iconv php8-mod-mbstring \

luci-app-amlogic ath9k-htc-firmware btrfs-progs hostapd hostapd-utils kmod-ath kmod-ath9k kmod-ath9k-common kmod-ath9k-htc kmod-cfg80211 kmod-crypto-acompress kmod-crypto-crc32c kmod-crypto-hash kmod-fs-btrfs kmod-mac80211 wireless-tools wpa-cli wpa-supplicant -procd-ujail \
        ${config_list} \
        "

    # Rebuild firmware
    make image PROFILE="" PACKAGES="${my_packages}" FILES="files"

    sync && sleep 3
    echo -e "${INFO} [ ${openwrt_dir}/bin/targets/*/* ] directory status: $(ls bin/targets/*/* -al 2>/dev/null)"
    echo -e "${SUCCESS} The rebuild is successful, the current path: [ ${PWD} ]"
}

# Show welcome message
echo -e "${STEPS} Welcome to Rebuild OpenWrt Using the Image Builder."
[[ -x "${0}" ]] || error_msg "Please give the script permission to run: [ chmod +x ${0} ]"
[[ -z "${1}" ]] && error_msg "Please specify the OpenWrt Branch, such as [ ${0} openwrt:22.03.3 ]"
[[ "${1}" =~ ^[a-z]{3,}:[0-9]+ ]] || error_msg "Incoming parameter format <source:branch>: openwrt:22.03.3"
op_sourse="${1%:*}"
op_branch="${1#*:}"
echo -e "${INFO} Rebuild path: [ ${PWD} ]"
echo -e "${INFO} Rebuild Source: [ ${op_sourse} ], Branch: [ ${op_branch} ]"
echo -e "${INFO} Server space usage before starting to compile: \n$(df -hT ${make_path}) \n"
#
# Perform related operations
download_imagebuilder
adjust_settings
configure_partitions
custom_packages
custom_files
rebuild_firmware
#
# Show server end information
echo -e "Server space usage after compilation: \n$(df -hT ${make_path}) \n"
# All process completed
wait
