#!/bin/sh
# Promote a successful temporary trial, retaining the original binaries/units.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run as root' >&2; exit 1; }
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
trial=/var/lib/altserver-native/netmux-compat-trial
systemctl is-active --quiet altserver-netmux-compat.service
test -f /run/systemd/system/altserver-native-netmuxd.service.d/90-compat-trial.conf
test ! -e /etc/systemd/system/altserver-native-netmuxd.service.d/50-official-compat.conf
printf '%s  %s\n' d42e0d1ed1a29c38693083db919e4cb2e1ce9e08799fa19a2ee388882d9bcc23 "$trial/netmuxd" | sha256sum -c -
. "${ENV_FILE:-/etc/altserver-native.env}"
install -m 755 "$trial/netmuxd" "$ALTSERVER_HOME/bin/netmuxd-v0.4.3"
install -m 755 "$root/scripts/runtime/altserver-netmux-compat" /usr/local/libexec/altserver-netmux-compat
install -d /etc/systemd/system/altserver-native-netmuxd.service.d /etc/systemd/system/altserver-native.service.d
cat >"$trial/restore-original.sh" <<'RESTORE'
#!/bin/sh
set -eu
systemctl stop altserver-netmux-trial-rollback.timer || true
systemctl stop altserver-native-healthcheck.timer
systemctl stop altserver-native-healthcheck.service || true
systemctl stop altserver-native.service altserver-native-netmuxd.service altserver-netmux-compat.service
rm -f /etc/systemd/system/altserver-native-netmuxd.service.d/50-official-compat.conf
rm -f /etc/systemd/system/altserver-native.service.d/50-official-compat.conf
rm -f /etc/systemd/system/altserver-netmux-compat.service
rm -f /run/systemd/system/altserver-native-netmuxd.service.d/90-compat-trial.conf
rm -f /run/systemd/system/altserver-netmux-compat.service
systemctl daemon-reload
systemctl start altserver-native-netmuxd.service
systemctl restart iphone-mobdev-service.service
systemctl start altserver-native.service altserver-native-healthcheck.timer
RESTORE
chmod 700 "$trial/restore-original.sh"
trap 'result=$?; if [ "$result" -ne 0 ]; then /bin/sh "$trial/restore-original.sh"; fi' EXIT
cat >/etc/systemd/system/altserver-native-netmuxd.service.d/50-official-compat.conf <<UNIT
[Unit]
Wants=altserver-netmux-compat.service
[Service]
ExecStart=
ExecStart=$ALTSERVER_HOME/bin/netmuxd-v0.4.3 --disable-unix --disable-usb --host 127.0.0.1 --port 27016 --plist-storage /var/lib/lockdown --upstream-usbmuxd /var/run/usbmuxd
UNIT
cat >/etc/systemd/system/altserver-native.service.d/50-official-compat.conf <<'UNIT'
[Unit]
Wants=altserver-netmux-compat.service
After=altserver-netmux-compat.service
UNIT
cat >/etc/systemd/system/altserver-netmux-compat.service <<'UNIT'
[Unit]
Description=Legacy AltServer address format adapter
After=altserver-native-netmuxd.service
[Service]
ExecStart=/usr/bin/python3 /usr/local/libexec/altserver-netmux-compat
DynamicUser=yes
User=altserver-netmux-compat
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
RestrictAddressFamilies=AF_INET
MemoryMax=192M
Restart=on-failure
RestartSec=2
UNIT
systemctl stop altserver-netmux-trial-rollback.timer
systemctl stop altserver-native-healthcheck.timer
systemctl stop altserver-native-healthcheck.service || true
systemctl stop altserver-native.service altserver-native-netmuxd.service altserver-netmux-compat.service
rm -f /run/systemd/system/altserver-native-netmuxd.service.d/90-compat-trial.conf
rm -f /run/systemd/system/altserver-netmux-compat.service
systemctl daemon-reload
systemctl start altserver-native-netmuxd.service altserver-netmux-compat.service
systemctl restart iphone-mobdev-service.service
systemctl start altserver-native.service altserver-native-healthcheck.timer
echo "Official netmuxd compatibility profile installed. Restore: sh $trial/restore-original.sh"
