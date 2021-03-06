#!/bin/sh
source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
DIR=$(cd $(dirname $0); pwd)
module=serverchan
ROG_86U=0
BUILDNO=$(nvram get buildno)
EXT_NU=$(nvram get extendno)
EXT_NU=$(echo ${EXT_NU%_*} | grep -Eo "^[0-9]{1,10}$")
[ -z "${EXT_NU}" ] && EXT_NU="0"
odmpid=$(nvram get odmpid)
productid=$(nvram get productid)
[ -n "${odmpid}" ] && MODEL="${odmpid}" || MODEL="${productid}"
LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')

# 获取固件类型
_get_type() {
	local FWTYPE=$(nvram get extendno|grep koolshare)
	if [ -d "/koolshare" ];then
		if [ -n "${FWTYPE}" ];then
			echo "koolshare官改固件"
		else
			echo "koolshare梅林改版固件"
		fi
	else
		if [ "$(uname -o|grep Merlin)" ];then
			echo "梅林原版固件"
		else
			echo "华硕官方固件"
		fi
	fi
}

exit_install(){
	local state=$1
	case $state in
		1)
			echo_date "本插件适用于【koolshare merlin armv7l 384/386】固件平台！"
			echo_date "你的固件平台不能安装！！!"
			echo_date "本插件支持机型/平台：https://github.com/koolshare/armsoft#armsoft"
			echo_date "退出安装！"
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 1
			;;
		0|*)
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 0
			;;
	esac
}

# 判断路由架构和平台
if [ -d "/koolshare" -a -f "/usr/bin/skipd" -a "${LINUX_VER}" -eq "26" ];then
	echo_date 机型：${MODEL} $(_get_type) 符合安装要求，开始安装插件！
else
	exit_install 1
fi

# 判断固件UI类型
if [ -n "$(nvram get extendno | grep koolshare)" -a "$(nvram get productid)" == "RT-AC86U" -a "${EXT_NU}" -lt "81918" -a "${BUILDNO}" != "386" ];then
	ROG_86U=1
fi

if [ "${MODEL}" == "GT-AC5300" -o "${MODEL}" == "GT-AX11000" -o "${MODEL}" == "GT-AX11000_BO4"  -o "$ROG_86U" == "1" ];then
	# 官改固件，骚红皮肤
	ROG=1
fi

if [ "${MODEL}" == "TUF-AX3000" ];then
	# 官改固件，橙色皮肤
	TUF=1
fi

# stop serverchan first
enable=$(dbus get serverchan_enable)
if [ "$enable" == "1" ] && [ -f "/koolshare/scripts/serverchan_config.sh" ]; then
	/koolshare/scripts/serverchan_config.sh stop >/dev/null 2>&1
fi

# 安装
echo_date "开始安装ServerChan微信通知..."
cd /tmp
if [[ ! -x /koolshare/bin/jq ]]; then
	cp -f /tmp/serverchan/bin/jq /koolshare/bin/jq
	chmod +x /koolshare/bin/jq
fi
rm -rf /koolshare/init.d/*serverchan.sh
rm -rf /koolshare/serverchan >/dev/null 2>&1
rm -rf /koolshare/scripts/serverchan_*
cp -rf /tmp/serverchan/res/icon-serverchan.png /koolshare/res/
cp -rf /tmp/serverchan/scripts/* /koolshare/scripts/
cp -rf /tmp/serverchan/webs/Module_serverchan.asp /koolshare/webs/
if [ "$ROG" == "1" ];then
	echo_date "安装ROG皮肤！"
	continue
else
	if [ "$TUF" == "1" ];then
		echo_date "安装TUF皮肤！"
		sed -i 's/3e030d/3e2902/g;s/91071f/92650F/g;s/680516/D0982C/g;s/cf0a2c/c58813/g;s/700618/74500b/g;s/530412/92650F/g' /koolshare/webs/Module_${module}.asp >/dev/null 2>&1
	else
		echo_date "安装ASUSWRT皮肤！"
		sed -i '/rogcss/d' /koolshare/webs/Module_${module}.asp >/dev/null 2>&1
	fi
fi
chmod +x /koolshare/scripts/*
# 安装重启自动启动功能
[ ! -L "/koolshare/init.d/S99CRUserverchan.sh" ] && ln -sf /koolshare/scripts/serverchan_config.sh /koolshare/init.d/S99CRUserverchan.sh

# 设置默认值
router_name=$(echo $(nvram get model) | base64_encode)
router_name_get=$(dbus get serverchan_config_name)
if [ -z "${router_name_get}" ]; then
	dbus set serverchan_config_name="${router_name}"
fi
router_ntp_get=$(dbus get serverchan_config_ntp)
if [ -z "${router_ntp_get}" ]; then
	dbus set serverchan_config_ntp="ntp1.aliyun.com"
fi
bwlist_en_get=$(dbus get serverchan_dhcp_bwlist_en)
if [ -z "${bwlist_en_get}" ]; then
	dbus set serverchan_dhcp_bwlist_en="1"
fi
_sckey=$(dbus get serverchan_config_sckey)
if [ -n "${_sckey}" ]; then
	dbus set serverchan_config_sckey_1=$(dbus get serverchan_config_sckey)
	dbus remove serverchan_config_sckey
fi
[ -z "$(dbus get serverchan_info_lan_macoff)" ] && dbus set serverchan_info_lan_macoff="1"
[ -z "$(dbus get serverchan_info_dhcp_macoff)" ] && dbus set serverchan_info_dhcp_macoff="1"
[ -z "$(dbus get serverchan_trigger_dhcp_macoff)" ] && dbus set serverchan_trigger_dhcp_macoff="1"

# 离线安装用
dbus set serverchan_version="$(cat $DIR/version)"
dbus set softcenter_module_serverchan_version="$(cat $DIR/version)"
dbus set softcenter_module_serverchan_install="1"
dbus set softcenter_module_serverchan_name="serverchan"
dbus set softcenter_module_serverchan_title="ServerChan微信推送"
dbus set softcenter_module_serverchan_description="从路由器推送状态及通知的工具。"

# re-enable serverchan
if [ "$enable" == "1" ] && [ -f "/koolshare/scripts/serverchan_config.sh" ]; then
	/koolshare/scripts/serverchan_config.sh start >/dev/null 2>&1
fi

# 完成
echo_date "ServerChan微信通知插件安装完毕！"
exit_install
