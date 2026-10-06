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
#sed -i "/luci/d" "feeds.conf.default"
echo "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main" >> "feeds.conf.default"
echo "src-git lucky https://github.com/gdy666/luci-app-lucky.git;main" >> "feeds.conf.default"
#echo "src-git nekoclash https://github.com/Thaolga/luci-app-nekoclash.git" >> "feeds.conf.default"

#echo "src-git kiddin9 https://github.com/kiddin9/openwrt-packages.git" >> "feeds.conf.default"
#sed -i '$a src-git adguard https://github.com/281677160/openwrt-package.git;adguard' feeds.conf.default
#svn co https://github.com/281677160/openwrt-package/trunk/luci-app-clash package/luci-app-clash
#svn co https://github.com/281677160/openwrt-package/branches/19.07/luci-app-eqos package/luci-app-eqos


# Add a feed source

mkdir -p files/usr/share
mkdir -p files/etc/
touch files/etc/Lee_version

# backup config
cat>> package/base-files/files/lib/upgrade/keep.d/base-files-essential<<-EOF
/etc/config/dhcp
/etc/adguardhome/work/data/filters/
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
kpatch=`cat include/kernel-${str1} target/linux/generic/kernel-${str1} 2>/dev/null | grep "LINUX_VERSION-${str1} =" | cut -d . -f 3` #取小版本号；24.10 在 include/，25.12 起移到 target/linux/generic/
sleep 2
if [ -e bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined.img.gz ];then
  mv  bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined.img.gz       bin/targets/x86/64/immortalwrt_x86-64-${rename_version}_${str1}.${kpatch}_sta_Lee.img.gz
fi
exit 0
EOF


cat>Lee.sh<<-\EOOF
#!/bin/bash
Lee_version="`date '+%y%m%d%H%M'`_sta_Lee"
echo $Lee_version | cut -d _ -f 1 >  files/etc/Lee_version
# 固件版本描述编译时写入模板：网页概况页读 /usr/lib/os-release 的 OPENWRT_RELEASE，/etc/openwrt_release 同步保持一致
# 版本号取自源码分支名（openwrt-25.12 → 25.12），换分支无需手改
branch=`git rev-parse --abbrev-ref HEAD`
desc="ImmortalWrt ${branch#openwrt-} · $Lee_version"
sed -i "s|^OPENWRT_RELEASE=.*|OPENWRT_RELEASE=\"$desc\"|" package/base-files/files/usr/lib/os-release
sed -i "s|^DISTRIB_DESCRIPTION=.*|DISTRIB_DESCRIPTION='$desc'|" package/base-files/files/etc/openwrt_release
EOOF
