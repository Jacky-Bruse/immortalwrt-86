#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# Uncomment a feed source
# Add a feed helloword
sed -i "/helloworld/d" "feeds.conf.default"
#sed -i "/luci/d" "feeds.conf.default"
echo "src-git helloworld https://github.com/fw876/helloworld.git" >> "feeds.conf.default"
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"
#echo "src-git nekoclash https://github.com/Thaolga/luci-app-nekoclash.git" >> "feeds.conf.default"

#echo "src-git kiddin9 https://github.com/kiddin9/openwrt-packages.git" >> "feeds.conf.default"
#sed -i '$a src-git adguard https://github.com/281677160/openwrt-package.git;adguard' feeds.conf.default
#svn co https://github.com/281677160/openwrt-package/trunk/luci-app-clash package/luci-app-clash
#svn co https://github.com/281677160/openwrt-package/branches/19.07/luci-app-eqos package/luci-app-eqos


# Add a feed source

mkdir -p files/usr/share
mkdir -p files/etc/
touch files/etc/Lee_version
mkdir wget
touch wget/DISTRIB_REVISION1

# backup config
cat>> package/base-files/files/lib/upgrade/keep.d/base-files-essential<<-EOF
/etc/config/dhcp
/etc/config/xray
/etc/config/sing-box
/etc/config/passwall_show
/etc/config/passwall_server
/etc/config/passwall
/usr/share/v2ray/geosite.dat
/usr/share/v2ray/geoip.dat
/usr/share/passwall/rules/
/usr/share/singbox/
/usr/share/v2ray/
/etc/openclash/core/
/usr/bin/chinadns-ng
/usr/bin/sing-box
/usr/bin/xray
/usr/bin/hysteria
EOF


cat>rename.sh<<-\EOF
#!/bin/bash
rm -rf  bin/targets/x86/64/immortalwrt-x86-64-generic-kernel.bin
rm -rf  bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-rootfs.img.gz
rm -rf  bin/targets/x86/64/immortalwrt-x86-64-generic-rootfs.tar.gz
rm -rf  bin/targets/x86/64/version.buildinfo
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-ext4-rootfs.img.gz
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-ext4-combined-efi.img.gz
rm -rf bin/targets/x86/64/immortalwrt-x86-64-generic-ext4-combined.img.gz
sleep 2
rename_version=`cat files/etc/Lee_version`
str1=`grep "KERNEL_PATCHVER:="  target/linux/x86/Makefile | cut -d = -f 2` #判断当前默认内核版本号如6.12
kpatch=`grep "LINUX_VERSION-${str1} ="  include/kernel-${str1} | cut -d . -f 3` #取小版本号，通用适配任意内核系列
sleep 2
if [ -e bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined.img.gz ];then
  mv  bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined.img.gz       bin/targets/x86/64/immortalwrt_x86-64-${rename_version}_${str1}.${kpatch}_sta_Lee.img.gz
  mv  bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz   bin/targets/x86/64/immortalwrt_x86-64-${rename_version}_${str1}.${kpatch}_uefi-gpt_sta_Lee.img.gz
fi
exit 0
EOF


cat>Lee.sh<<-\EOOF
#!/bin/bash
Lee_version="`date '+%y%m%d%H%M'`_sta_Lee"
echo $Lee_version >  wget/DISTRIB_REVISION1
echo $Lee_version | cut -d _ -f 1 >  files/etc/Lee_version
new_DISTRIB_REVISION=`cat  wget/DISTRIB_REVISION1`
# 将固件版本号写入系统描述（网页概况页显示）
sed -i 's/exit 0/ /'  package/emortal/default-settings/files/99-default-settings
cat>> package/emortal/default-settings/files/99-default-settings<<-EOF
	sed -i '/DISTRIB_DESCRIPTION/d' /etc/openwrt_release
	echo "DISTRIB_DESCRIPTION='$new_DISTRIB_REVISION'" >> /etc/openwrt_release
	exit 0
	EOF
EOOF
