#!/bin/sh
# network_watchdog.sh - K2P-512 卡死自动恢复看门狗
# 由 cron 每分钟执行一次 (rc.c init_crontab 注册)
# 策略: 检测卡死 -> 分级停止无关程序 -> 恢复核心联网 -> 必要时重启

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

PIDFILE="/var/network_watchdog.pid"
LOG="/tmp/network_watchdog.log"
FAILF="/tmp/network_watchdog.fail"
WANFAILF="/tmp/network_watchdog.wanfail"
MAXLOG=100000

# ===== 可调参数 =====
WAN_PING="223.5.5.5"        # WAN 连通性检测目标 (阿里DNS)
GRACE_SEC=180               # 开机宽限期(秒), WAN未就绪不检测
MEM_MIN_KB=16384            # 可用内存阈值(KB), 低于此释放资源
SYS_FAIL_MAX=3              # 系统级卡死连续N次 -> 重启路由器

loger() {
	[ -f "$LOG" ] && [ "$(stat -c %s "$LOG" 2>/dev/null)" -gt $MAXLOG ] && rm -f "$LOG"
	echo "$(date '+%H:%M:%S') netwd $1" >> "$LOG"
}

cleanup() {
	rm -f "$PIDFILE"
	exit 0
}

get_fail() {
	cat "$FAILF" 2>/dev/null || echo 0
}

# 防重入
if [ -f "$PIDFILE" ]; then
	OLD=$(cat "$PIDFILE" 2>/dev/null)
	[ -n "$OLD" ] && kill -9 "$OLD" 2>/dev/null
fi
echo $$ > "$PIDFILE"

# 开机宽限期内不检测
UPTIME=$(cut -d. -f1 /proc/uptime 2>/dev/null)
[ -z "$UPTIME" ] && UPTIME=0
if [ "$UPTIME" -lt "$GRACE_SEC" ]; then
	cleanup
fi

LAN_IP=$(nvram get lan_ipaddr 2>/dev/null)
[ -z "$LAN_IP" ] && LAN_IP="192.168.123.1"
HTTP_PORT=$(nvram get http_lanport 2>/dev/null)
[ -z "$HTTP_PORT" ] && HTTP_PORT=80
HTTP_PROTO=$(nvram get http_proto 2>/dev/null)

# ---- 检测 ----
wan_ok() {
	ping -c 2 -W 3 "$WAN_PING" >/dev/null 2>&1
}

lan_ok() {
	ping -c 1 -W 2 "$LAN_IP" >/dev/null 2>&1
}

http_ok() {
	# HTTPS-only 模式下 HTTP 端口不监听, 跳过检测
	[ "$HTTP_PROTO" = "1" ] && return 0
	wget -q -O /dev/null --timeout=3 "http://127.0.0.1:$HTTP_PORT/" 2>/dev/null
}

# ---- 释放无关程序 (保留 dnsmasq/httpd/watchdog 核心) ----
stop_noncritical() {
	loger "stop non-critical services"
	# 代理降级为直连 (用脚本停止以清理透明代理 iptables 规则)
	if [ -x /usr/bin/shadowsocks.sh ]; then
		nvram set ss_enable=0 >/dev/null 2>&1
		/usr/bin/shadowsocks.sh stop >/dev/null 2>&1
	fi
	[ -x /usr/bin/v2ray.sh ] && /usr/bin/v2ray.sh stop >/dev/null 2>&1
	[ -x /usr/bin/trojan.sh ] && /usr/bin/trojan.sh stop >/dev/null 2>&1
	# 下载/文件/广告类进程
	killall aria2c caddy smbd nmbd transmission-daemon minidlnad 2>/dev/null
	killall adbyby koolproxyd privoxy 2>/dev/null
	# 恢复直连防火墙规则
	/sbin/restart_firewall >/dev/null 2>&1
}

mem_free_kb() {
	local m
	m=$(awk '/MemAvailable/{print $2}' /proc/meminfo 2>/dev/null)
	[ -z "$m" ] && m=$(awk '/MemFree/{print $2}' /proc/meminfo 2>/dev/null)
	echo "$m"
}

# ================= 主逻辑 =================
FAIL=$(get_fail)

if wan_ok; then
	# 网络正常: 清零计数, 仅在内存紧张时释放资源
	if [ "$FAIL" != "0" ]; then
		loger "wan recovered, reset fail counter"
		echo 0 > "$FAILF"
	fi
	echo 0 > "$WANFAILF"
	MEMFREE=$(mem_free_kb)
	if [ -n "$MEMFREE" ] && [ "$MEMFREE" -lt "$MEM_MIN_KB" ] 2>/dev/null; then
		loger "low memory ${MEMFREE}KB, release file/download services"
		killall aria2c caddy smbd nmbd transmission-daemon minidlnad 2>/dev/null
		killall adbyby koolproxyd privoxy 2>/dev/null
	fi
	cleanup
fi

# --- WAN 不通 ---
# 场景A: LAN IP 或 httpd 也无响应 = 系统卡死级 -> 分级恢复
if ! lan_ok || ! http_ok; then
	FAIL=$((FAIL + 1))
	echo "$FAIL" > "$FAILF"
	loger "system hang detected (fail=$FAIL)"
	if [ "$FAIL" -ge "$SYS_FAIL_MAX" ]; then
		loger "recovery failed $SYS_FAIL_MAX times, reboot now"
		echo 0 > "$FAILF"
		sync
		reboot
		cleanup
	fi
	if [ "$FAIL" -eq 1 ]; then
		# 第1轮: 重启核心网络 (DNS + WAN)
		loger "restart dnsmasq and wan"
		/sbin/restart_dhcpd >/dev/null 2>&1
		/sbin/restart_wan >/dev/null 2>&1
	else
		# 第2轮: 停止全部无关程序 + 重启WiFi + WAN
		stop_noncritical
		/sbin/radio2_restart >/dev/null 2>&1
		/sbin/radio5_restart >/dev/null 2>&1
		/sbin/restart_wan >/dev/null 2>&1
	fi
	cleanup
fi

# 场景B: LAN 正常仅 WAN 不通 = 上游问题 -> 每3分钟重试WAN, 不动服务不重启
WANFAIL=$(cat "$WANFAILF" 2>/dev/null || echo 0)
WANFAIL=$((WANFAIL + 1))
echo "$WANFAIL" > "$WANFAILF"
if [ $((WANFAIL % 3)) -eq 1 ]; then
	loger "wan unreachable for ${WANFAIL}min (lan ok), retry wan connect"
	/sbin/restart_dhcpd >/dev/null 2>&1
	/sbin/restart_wan >/dev/null 2>&1
fi
cleanup
