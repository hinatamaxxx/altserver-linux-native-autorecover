# 検証記録 / Verification Notes

## 公式netmuxd互換性プロファイル — 2026-09-16

- 未改造の公式netmuxd v0.4.3と、外部のアドレス形式変換でUSBなしのAltStore更新に成功。初回試験では追加の二段階認証なし。
- Wi-Fi再接続で端末一覧が空になる別の失敗を再現。公式AddDevice APIを使う自動再登録を追加し、その復旧後の更新成功を利用者が確認。
- プロセス再起動後の端末再検出とhealthcheck正常を確認。
- 27件の回帰テスト成功。公式配布物とのハッシュ一致、プロファイルの永続化、DynamicUser実行、15秒の復旧チェック設定、元のバイナリの保持を確認。
- このプロファイルでのホスト全体の再起動、新規クリーンインストール、長時間運用は未確認。

詳細は [netmuxd-compatibility.md](netmuxd-compatibility.md) を参照してください。以下の旧プロファイルの記録とは区別します。

### English — official netmuxd profile

- Unmodified official netmuxd v0.4.3 plus an external address adapter successfully refreshed apps over Wi-Fi without USB; the initial test required no additional two-factor prompt.
- Toggling Wi-Fi exposed missing device registration. Official AddDevice API recovery was added, and the user confirmed refresh success after automatic registration.
- Device discovery and health checks recovered after restarting the services.
- 27 regression tests passed. Official binary checksums, persistent profile installation, DynamicUser execution, the 15-second check interval and retention of the original binary were verified.
- Boot services and dependencies are configured for automatic startup. A full host reboot/power cycle, clean installation and long-duration operation remain untested for this profile.

See the [English investigation and deployment guide](netmuxd-compatibility.en.md). The historical results below apply to earlier profiles.

## v0.2.0 — 2026-09-16

Debian実機上で確認:

- 回帰テスト10件成功（分割受信、不正フレーム、別端末・古いIPの除外、移行、復旧間隔、UTC時刻の検証）。
- shell構文とsystemd unitの検証成功。
- 旧コンテナから端末IDとプロビジョニングを移行。
- コンテナ再作成前後で3種類の認証用識別情報のハッシュが同一。
- AltServerのUTC時刻が9時間ずれる問題を再現し、プロセスの `TZ=UTC` 設定後に修正を確認。
- 実際の `AnisetteDataResponse` の必須フィールド・型・時刻を検証。
- 更新後のhealthcheckが `healthy`。

AltStore 2.2.1では `NSCocoaErrorDomain 3840` が残りました。[公式更新案内](https://cdn.altstore.io/file/altstore/apps.json)に従い利用者が2.3へ更新し、二段階認証を完了した後、USBを外した状態でアプリ更新に成功したことを確認しました。Anisetteをさらに再起動し、識別情報が変わらないこととhealthcheck正常を再確認しています。

その再起動後、利用者が再度Wi-Fi更新に成功し、**二段階認証は要求されませんでした**。長期間にわたるApple側のセッション有効期間までは、この短時間の検証で保証できません。

ホスト全体の再起動と新規クリーンインストールは今回未実施です。以下の2026-06-07の結果とは区別してください。

## 日本語

検証日: 2026-06-07

検証環境:

```text
Debian GNU/Linux 13.1 (trixie)
kernel: 6.12.48+deb13-amd64
amd64 / x86_64
```

確認済み:

- shell script構文チェック
- AltServer-Linux `v0.0.5` の `AltServer-x86_64` 取得
- `jkcoxson/netmuxd v0.1.4` の `x86_64-linux-netmuxd` 取得
- iPhone USB接続後の「信頼」検出
- systemd unit導入
- `dadoum/anisette-v3-server` によるJSON応答
- healthcheck `healthy`
- 既存の `/opt/altserver-native`、systemd unit、`/etc/altserver-native.env` を削除した状態から `install.sh` で再構築
- USB接続でのAltStore/AltServer認識
- Wi-Fi接続でのAltStore/AltServer認識
- Debian再起動後、iPhone側で再度「信頼」を押した後に `healthy` 復帰

重要な発見:

`netmuxd v0.3.2` の現在のLinux向け配布アセットでは、AltServerのmDNS広告は出ているのに、AltServerがiPhoneへ接続できず、AltStore側には `AltServer could not be found` と表示されました。

動作実績のある既存環境の `netmuxd` は、サイズと公開アセット一覧から `jkcoxson/netmuxd v0.1.4` の `x86_64-linux-netmuxd` と一致しました。これに戻すとUSB/Wi-Fiの両方が復旧しました。

そのため、このセットアップでは `netmuxd v0.1.4` を固定しています。

## English

Verification date: 2026-06-07

Verified environment:

```text
Debian GNU/Linux 13.1 (trixie)
kernel: 6.12.48+deb13-amd64
amd64 / x86_64
```

Verified:

- shell syntax checks
- AltServer-Linux `v0.0.5` `AltServer-x86_64` download
- `jkcoxson/netmuxd v0.1.4` `x86_64-linux-netmuxd` download
- USB Trust detection
- systemd unit installation
- JSON response from `dadoum/anisette-v3-server`
- healthcheck returned `healthy`
- clean reinstall from removed `/opt/altserver-native`, systemd units, and `/etc/altserver-native.env`
- AltStore/AltServer detected over USB
- AltStore/AltServer detected over Wi-Fi
- after Debian reboot, healthcheck returned `healthy` after tapping Trust again on the iPhone

Important finding:

The current Linux release asset from `netmuxd v0.3.2` made AltServer discoverable through mDNS but unable to connect to the device. AltStore displayed `AltServer could not be found`.

The working binary from the existing environment matched `jkcoxson/netmuxd v0.1.4` `x86_64-linux-netmuxd` by size and release asset list. Switching back to that binary restored both USB and Wi-Fi operation.

This setup therefore pins `netmuxd v0.1.4`.
