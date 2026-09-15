#!/bin/sh
# Update helper logic without re-pairing, replacing binaries, or rebuilding USB.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "Run as root" >&2; exit 1; }
ENV_FILE="${ENV_FILE:-/etc/altserver-native.env}"
export ENV_FILE
set -a
. "$ENV_FILE"
set +a
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
backup="$(mktemp -d /var/backups/altserver-runtime-XXXXXXXX)"
chmod 700 "$backup"
cp -a "$ENV_FILE" "$backup/config.env"
mkdir "$backup/helpers" "$backup/units"
for name in altserver-native-healthcheck altserver-native-probe altserver-native-boot-recover altserver-anisette-docker-run altserver-anisette-migrate iphone-mobdev-address-publisher iphone-mobdev-service-publisher; do
  if [ -f "/usr/local/sbin/$name" ]; then cp -a "/usr/local/sbin/$name" "$backup/helpers/"; fi
done
for file in /etc/systemd/system/altserver-native* /etc/systemd/system/altserver-anisette* /etc/systemd/system/iphone-mobdev*; do
  if [ -e "$file" ]; then cp -a "$file" "$backup/units/"; fi
done

# Prevent the old monitor from replacing the --rm container during migration.
systemctl stop altserver-native-healthcheck.timer altserver-native-boot-recover.service
systemctl stop altserver-native-healthcheck.service
trap 'systemctl start altserver-native-healthcheck.timer' EXIT
case "$ANISETTE_DOCKER_IMAGE" in
  dadoum/anisette-v3-server|dadoum/anisette-v3-server:*)
    python3 "$root/scripts/runtime/altserver-anisette-migrate"
    ;;
  *) echo "Custom anisette image requires manual state migration" >&2; exit 1 ;;
esac

sh "$root/scripts/install-helper-scripts.sh"
sh "$root/scripts/install-systemd-units.sh"
systemctl restart altserver-anisette-docker.service
systemctl restart iphone-mobdev-address.service iphone-mobdev-service.service
systemctl start altserver-native-netmuxd.service altserver-native.service
# A running process does not pick up Environment=TZ=UTC until restarted.
pid="$(systemctl show altserver-native.service -p MainPID --value)"
if ! tr '\000' '\n' <"/proc/$pid/environ" | grep -qx 'TZ=UTC'; then
  systemctl restart altserver-native.service
fi
systemctl restart altserver-native-healthcheck.timer
printf 'Runtime upgraded. Backup: %s\n' "$backup"
printf 'Verify with: sudo /usr/local/sbin/altserver-native-healthcheck\n'
