#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
sed -i 's/192.168.1.1/192.168.1.3/g' package/base-files/files/bin/config_generate
#sed -i 's/KERNEL_PATCHVER:=5.15/KERNEL_PATCHVER:=5.10/g' target/linux/x86/Makefile
#sed -i "s/.*PKG_VERSION:=.*/PKG_VERSION:=4.3.9_v1.2.14/" package/lean/qBittorrent-static/Makefile
# welcome test 

# 首次开机关闭流量卸载：ImmortalWrt 默认开启，会让 eqos 按设备限速失效
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-disable-flow-offload <<'EOF'
#!/bin/sh
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall
exit 0
EOF

# 修复 nft-fullcone 误注销 ctnetlink 的连接事件通知，导致 nlbwmon/conntrack -E 收不到事件、设备流量为空：
# 内核 >= 5.15 每个 netns 只能有一个事件接收者，位置已被 ctnetlink 占用时 fullcone 跳过注册却仍记为已注册，
# fw4 启动时的 fullcone 探测（nft -c）让引用计数归零，随即清空了 ctnetlink 的注册
FULLCONE_PATCHES=package/network/utils/fullconenat-nft/patches
if [ -d "$FULLCONE_PATCHES" ]; then
	cat > "$FULLCONE_PATCHES/020-fix-ct-notifier-unregister.patch" <<'EOF'
--- a/src/nft_ext_fullcone.c
+++ b/src/nft_ext_fullcone.c
@@ -164,6 +164,8 @@ static int nft_fullcone_init(const struct nft_ctx *ctx, const struct nft_expr *e
 #if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0) && !defined(CONFIG_NF_CONNTRACK_CHAIN_EVENTS)
 		if (!READ_ONCE(ctx->net->ct.nf_conntrack_event_cb)) {
 			nf_conntrack_register_notifier(ctx->net, &ct_event_notifier);
+		} else {
+			register_ct_notifier_ret = -EBUSY;
 		}
 #else
 		register_ct_notifier_ret = nf_conntrack_register_notifier(ctx->net, &ct_event_notifier);
@@ -254,7 +256,8 @@ static void nft_fullcone_common_destory(const struct nft_ctx *ctx)
 	if (module_refer_count == 0) {
 		if (ct_event_notifier_registered) {
 #if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0) && !defined(CONFIG_NF_CONNTRACK_CHAIN_EVENTS)
-			nf_conntrack_unregister_notifier(ctx->net);
+			if (rcu_access_pointer(ctx->net->ct.nf_conntrack_event_cb) == &ct_event_notifier)
+				nf_conntrack_unregister_notifier(ctx->net);
 #else
 			nf_conntrack_unregister_notifier(ctx->net, &ct_event_notifier);
 #endif
EOF
fi

# AdGuardHome 工作目录默认在 /var（内存盘），重启后规则和统计全丢，改到固定存储
# 24.10 选项名为 workdir，25.12 为 work_dir；仅在仍为默认值时修改，不覆盖手动设置
cat > files/etc/uci-defaults/99-adguardhome-workdir <<'EOF'
#!/bin/sh
for opt in work_dir workdir; do
	[ "$(uci -q get adguardhome.config.$opt)" = "/var/lib/adguardhome" ] || continue
	uci set adguardhome.config.$opt='/etc/adguardhome/work'
	uci commit adguardhome
done
exit 0
EOF

# 冒充 wrtbwmon 给 wechatpush 提供设备流量：wrtbwmon 已被移出软件源，且统计不到 OpenClash 代理流量。
# wechatpush 每轮调用 "wrtbwmon update <db>" 并按表头 in/out/total 读取该 CSV；
# 这里改从 nlbwmon（连接跟踪计数，含代理流量）取累计值，按差值累加进 db，
# 使 wechatpush 删除行（设备上线重置）和每日删库（零点重置）的逻辑照常生效。
mkdir -p files/usr/sbin
cat > files/usr/sbin/wrtbwmon <<'EOF'
#!/bin/sh
case "$1" in update|-f) db="$2" ;; *) exit 0 ;; esac
[ -n "$db" ] || exit 0
state="$db.nlbw"
cur=$(nlbw -c csv -g mac,ip -s, -q 2>/dev/null | sed '1d')
[ -n "$cur" ] || exit 0
first=1; [ -f "$state" ] && first=0
{
	[ -f "$state" ] && sed 's/^/S,/' "$state"
	[ -f "$db" ] && grep -v '^#' "$db" | sed 's/^/D,/'
	awk 'NR>1 && $4 != "00:00:00:00:00:00" {print "A," $4 "," $1}' /proc/net/arp
	echo "$cur" | sed 's/^/N,/'
} | awk -F, -v first="$first" -v db="$db.tmp" -v st="$state.tmp" '
	$1 == "S" { lrx[$2] = $3; ltx[$2] = $4; next }
	$1 == "D" { din[$2] = $4; dout[$2] = $5; next }
	$1 == "A" { arp[$2] = $3; next }
	$1 == "N" && $2 != "00:00:00:00:00:00" {
		rx[$2] += $5; tx[$2] += $7
		if (!($2 in ip4) && $3 ~ /^[0-9.]+$/) ip4[$2] = $3
	}
	END {
		print "#mac,ip,in,out,total" > db
		for (m in rx) {
			# 首次运行只建基线；计数变小说明 nlbwmon 重启或换周期，按新累计值计
			dr = first ? 0 : ((m in lrx) && rx[m] >= lrx[m] ? rx[m] - lrx[m] : rx[m])
			dt = first ? 0 : ((m in ltx) && tx[m] >= ltx[m] ? tx[m] - ltx[m] : tx[m])
			i = din[m] + dr; o = dout[m] + dt
			ip = (m in arp) ? arp[m] : ip4[m]
			if (ip != "") printf "%s,%s,%.0f,%.0f,%.0f\n", m, ip, i, o, i + o > db
			printf "%s,%.0f,%.0f\n", m, rx[m], tx[m] > st
		}
	}' && mv "$db.tmp" "$db" && mv "$state.tmp" "$state"
EOF
chmod +x files/usr/sbin/wrtbwmon

# Lucky 软件源的 Makefile 写死了版本号，改为 GitHub 最新正式版（releases/latest 不含预发布）
# 获取失败或该版本没有 x86_64 包时保留软件源自带的版本，不影响编译
LUCKY_MK=feeds/lucky/lucky/Makefile
if [ -f "$LUCKY_MK" ]; then
	ver=$(curl -fsSIL -o /dev/null -w '%{url_effective}' https://github.com/gdy666/lucky/releases/latest | sed -n 's#.*/tag/v##p')
	if [ -n "$ver" ] && curl -fsIL -o /dev/null "https://github.com/gdy666/lucky/releases/download/v${ver}/lucky_${ver}_Linux_x86_64.tar.gz"; then
		sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=${ver}/" "$LUCKY_MK"
	fi
	echo "Lucky 版本: $(grep '^PKG_VERSION:=' "$LUCKY_MK")"
fi
