# トラブルシュート / Troubleshooting

## 日本語

### まず確認する

```sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

正常なら `healthy` と表示されます。

### AltStoreに `AltServer could not be found` と出る

この表示は、実際には「AltServerが見つからない」だけでなく、「AltServerは見えているがiPhone接続に失敗している」場合にも出ることがあります。

このリポジトリは、この症状を完全に根本修正するものではなく、`netmuxd` の一時的な不調をhealthcheckで復旧する設計です。詳しくは [known-issues.md](known-issues.md) を見てください。

確認:

```sh
avahi-browse -rt _altserver._tcp
avahi-browse -rt _apple-mobdev2._tcp
sudo /usr/local/sbin/altserver-native-healthcheck
```

復旧:

```sh
sudo systemctl restart altserver-native-netmuxd.service
sudo systemctl restart iphone-mobdev-address.service iphone-mobdev-service.service
sudo systemctl restart altserver-native.service
sudo /usr/local/sbin/altserver-native-healthcheck
```

### Debian再起動後に動かない

iPhone側で「信頼」が再表示される場合があります。表示されたら押してください。

その後:

```sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

### USBでiPhoneが見えない

確認:

```sh
lsusb
idevice_id -l
idevicepair list
```

`lsusb` にApple/iPhoneが出ない場合は、Debianから物理USBとして見えていません。USBケーブルを抜き差しし、iPhoneをロック解除して「信頼」を押してください。

### Wi-Fi refreshだけ失敗する

iPhone側のWi-Fi同期用ポートが見えているか確認します。

```sh
avahi-browse -rt _apple-mobdev2._tcp
```

`port = [62078]` が出るのが期待値です。

### anisetteのエラーが出る

確認:

```sh
curl -i http://127.0.0.1:6969/
systemctl status altserver-anisette-docker.service
```

正常ならJSON応答が返ります。

復旧:

```sh
sudo systemctl restart altserver-anisette-docker.service
```

### ログを見る

```sh
journalctl -u altserver-native.service -n 100 --no-pager
journalctl -u altserver-native-netmuxd.service -n 100 --no-pager
journalctl -u altserver-anisette-docker.service -n 100 --no-pager
journalctl -t altserver-health -n 100 --no-pager
```

ログには端末IDなどが出る場合があります。GitHub issueなどに貼る前に、UDID、MACアドレス、IPアドレス、Apple IDが含まれていないか確認してください。

## English

### First Check

```sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

The expected result is `healthy`.

### AltStore Says `AltServer could not be found`

This message can also appear when AltServer is discoverable but cannot connect to the iPhone.

This repository does not fully fix the upstream root cause. It mitigates temporary `netmuxd` failures through healthcheck-based recovery. See [known-issues.md](known-issues.md).

Check:

```sh
avahi-browse -rt _altserver._tcp
avahi-browse -rt _apple-mobdev2._tcp
sudo /usr/local/sbin/altserver-native-healthcheck
```

Recover:

```sh
sudo systemctl restart altserver-native-netmuxd.service
sudo systemctl restart iphone-mobdev-address.service iphone-mobdev-service.service
sudo systemctl restart altserver-native.service
sudo /usr/local/sbin/altserver-native-healthcheck
```

### After Debian Reboot

The iPhone may show Trust again. Tap Trust if it appears, then run:

```sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

### USB Device Not Visible

```sh
lsusb
idevice_id -l
idevicepair list
```

If `lsusb` does not show an Apple/iPhone device, Debian cannot see the physical USB device. Reconnect USB, unlock the iPhone, and tap Trust.

### Logs

```sh
journalctl -u altserver-native.service -n 100 --no-pager
journalctl -u altserver-native-netmuxd.service -n 100 --no-pager
journalctl -u altserver-anisette-docker.service -n 100 --no-pager
journalctl -t altserver-health -n 100 --no-pager
```

Logs may contain device identifiers. Redact UDID, MAC address, IP address, and Apple ID before posting logs publicly.
