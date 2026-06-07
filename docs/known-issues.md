# 既知の問題と設計方針 / Known Issues

## 日本語

### 根本問題

このセットアップは、AltServer-Linux、`netmuxd`、Avahi/mDNS、iPhone側のWi-Fi同期機能を組み合わせています。現時点で一番不安定になりやすいのは `netmuxd` 周りです。

実機検証では、iPhoneのWi-Fi同期ポート `62078/tcp` には到達できているのに、`netmuxd` のDeviceListからiPhoneが一時的に消えることがありました。この状態になると、AltServer自体は動いていてmDNS広告も出ているのに、AltStore側では `AltServer could not be found` と表示されることがあります。

### なぜ完全な根本解決ではないのか

本当の根本解決には、次のどちらかが必要です。

- `netmuxd` 側でiPhoneのmDNS再検出、再登録、heartbeat周りを修正する
- AltServer-Linux側で待受ポート固定や再接続処理を改善する

このリポジトリは、そこまでのコード修正は行いません。公開版では「壊れにくくする」「壊れても早く戻す」ことを目的にしています。

### 現在の対策

- `netmuxd v0.1.4` に固定する
- `netmuxd v0.3.2` は現時点では使わない
- healthcheckを1分ごとに実行する
- `netmuxd` だけ不調な場合は、AltServer本体を再起動しない
- AltServer本体の待受ポートが無駄に変わらないようにする
- iPhoneのmDNS/IP情報を1分ごとに再広告する

### ポート固定について

AltServer-Linux `v0.0.5` の `AltServer` には、待受ポートを指定するオプションがありません。ポートを固定できればAltStore側のキャッシュずれは減る可能性がありますが、`netmuxd` がiPhoneを見失う問題そのものは解決しません。

### 将来の改善案

- `netmuxd v0.1.4` と `v0.3.2` の差分を調べる
- `v0.3.2` がAltServer-Linuxで壊れる原因を特定する
- AltServer-Linux互換の `netmuxd` パッチを作る
- AltServer-Linux側に固定ポート指定を追加できるか調べる

## English

### Root Issue

This setup combines AltServer-Linux, `netmuxd`, Avahi/mDNS, and the iPhone Wi-Fi sync service. The most fragile part observed during verification is `netmuxd`.

In testing, the iPhone Wi-Fi sync port `62078/tcp` was reachable, but the iPhone sometimes disappeared from `netmuxd`'s DeviceList. In that state, AltServer can still be running and advertised through mDNS, while AltStore reports `AltServer could not be found`.

### Why This Is Not A Full Root Fix

A true root fix likely requires one of these:

- Fixing iPhone mDNS rediscovery, re-registration, or heartbeat behavior in `netmuxd`.
- Improving AltServer-Linux reconnection behavior or adding a fixed listening port option.

This repository does not patch those upstream codebases. The public version focuses on making the setup practical: reduce failures and recover quickly when they happen.

### Current Mitigations

- Pin `netmuxd v0.1.4`.
- Avoid `netmuxd v0.3.2` for now.
- Run healthcheck every 1 minute.
- Do not restart AltServer itself when only `netmuxd` is unhealthy.
- Avoid unnecessary AltServer port changes.
- Republish iPhone mDNS/IP information every 1 minute.

### Fixed Port

AltServer-Linux `v0.0.5` does not expose an option to set a fixed listening port. A fixed port could reduce AltStore-side cache mismatch, but it would not solve the underlying issue where `netmuxd` temporarily loses the iPhone.

### Future Work

- Compare `netmuxd v0.1.4` and `v0.3.2` behavior.
- Identify why `v0.3.2` breaks with AltServer-Linux.
- Patch `netmuxd` for AltServer-Linux compatibility.
- Investigate whether AltServer-Linux can support a fixed listening port.
