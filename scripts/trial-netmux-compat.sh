#!/bin/sh
# Temporary amd64 trial; /run overrides disappear on reboot. Automatic rollback.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run as root' >&2; exit 1; }
[ "$(uname -m)" = x86_64 ] || { echo 'Only amd64 is verified' >&2; exit 1; }
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
trial=/var/lib/altserver-native/netmux-compat-trial
override=/run/systemd/system/altserver-native-netmuxd.service.d/90-compat-trial.conf
[ ! -e "$override" ] || { echo 'A trial is already active' >&2; exit 1; }
install -d -m 700 "$trial"
curl -fL --retry 3 --connect-timeout 15 https://github.com/jkcoxson/netmuxd/releases/download/v0.4.3/netmuxd-x86_64-unknown-linux-gnu.tar.gz -o "$trial/asset.tar.gz"
printf '%s  %s\n' 85b6598284fc639f2a282584461d05e2090b79bdf3ec949d2a5e5d3dc655dde4 "$trial/asset.tar.gz" | sha256sum -c -
tar -xzf "$trial/asset.tar.gz" -C "$trial" netmuxd
install -d /usr/local/libexec
install -m 755 "$root/scripts/runtime/altserver-netmux-compat" /usr/local/libexec/altserver-netmux-compat
install -m 755 "$root/scripts/runtime/altserver-native-probe" /usr/local/sbin/altserver-native-probe
install -m 755 "$root/scripts/runtime/altserver-native-healthcheck" /usr/local/sbin/altserver-native-healthcheck
cat >"$trial/rollback.sh" <<'ROLLBACK'
#!/bin/sh
set -eu
systemctl stop altserver-native-healthcheck.timer
systemctl stop altserver-native-healthcheck.service || true
systemctl stop altserver-native.service altserver-native-netmuxd.service altserver-netmux-compat.service
rm -f /run/systemd/system/altserver-native-netmuxd.service.d/90-compat-trial.conf
rm -f /run/systemd/system/altserver-netmux-compat.service
rm -f /run/systemd/system/altserver-native-healthcheck.service.d/50-netmux-api.conf
rm -f /run/systemd/system/altserver-native-boot-recover.service.d/50-netmux-api.conf
systemctl daemon-reload
systemctl start altserver-native-netmuxd.service
systemctl restart iphone-mobdev-service.service
systemctl start altserver-native.service altserver-native-healthcheck.timer
ROLLBACK
chmod 700 "$trial/rollback.sh"
systemd-run --unit=altserver-netmux-trial-rollback --on-active=20m /bin/sh "$trial/rollback.sh"
trap 'exit 1' HUP INT TERM
trap 'result=$?; if [ "$result" -ne 0 ]; then /bin/sh "$trial/rollback.sh"; fi' EXIT
install -d /run/systemd/system/altserver-native-netmuxd.service.d
for unit in altserver-native-healthcheck altserver-native-boot-recover; do
    install -d "/run/systemd/system/$unit.service.d"
    printf '[Service]\nEnvironment=NETMUXD_REGISTER_MODE=api\n' >"/run/systemd/system/$unit.service.d/50-netmux-api.conf"
done
cat >"$override" <<UNIT
[Service]
ExecStart=
ExecStart=$trial/netmuxd --disable-unix --disable-usb --host 127.0.0.1 --port 27016 --plist-storage /var/lib/lockdown --upstream-usbmuxd /var/run/usbmuxd
UNIT
cat >/run/systemd/system/altserver-netmux-compat.service <<'UNIT'
[Unit]
Description=Legacy AltServer address format adapter (trial)
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
systemctl stop altserver-native-healthcheck.timer
systemctl stop altserver-native-healthcheck.service || true
systemctl stop altserver-native.service altserver-native-netmuxd.service
systemctl daemon-reload
if ! systemctl start altserver-native-netmuxd.service altserver-netmux-compat.service; then
    /bin/sh "$trial/rollback.sh"
    exit 1
fi
systemctl restart iphone-mobdev-service.service
systemctl start altserver-native.service altserver-native-healthcheck.timer
echo 'Trial active; automatic rollback in 20 minutes.'
echo "Manual rollback: sh $trial/rollback.sh"
