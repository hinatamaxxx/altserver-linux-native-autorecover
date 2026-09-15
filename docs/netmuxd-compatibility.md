# netmuxdのバージョン依存：原因と検証

調査日: 2026-09-16。対象は未改造の AltServer-Linux v0.0.5 / Debian amd64。

## 特定した原因

**iPhoneの接続先を表す `NetworkAddress` の形式が、AltServer内蔵の古いlibimobiledeviceと新しいnetmuxdの間で一致しません。**
IPアドレスやペアリングの正誤とは別の問題です。mDNSでAltServerが見えても、iPhoneへの接続段階で失敗します。

AltServerの同梱コードは先頭1バイトをアドレス構造体の長さ、2バイト目をアドレス種別として読みます（BSD形式）。
新しいnetmuxdのLinux版は先頭2バイトにアドレス種別を格納します。
IPv4の `02 00` を古いクライアントが読むと「長さ2、種別0」になり、`Unsupported address family` の分岐に入ります。

| 実際に照合した配布物 | NetworkAddress先頭4バイト | データ長 | 古いAltServerからの解釈 |
|---|---|---|---|
| 既存v0.1.4相当の本番バイナリ | `0a 02 00 00` | 152 | IPv4として解釈可能 |
| 公式v0.3.2 Linux amd64 | `02 00 00 00` | 152 | 種別0、非互換 |
| 公式v0.4.3 Linux amd64 | `02 00 00 00` | 128 | 種別0、非互換 |

v0.1.4の長さ10は標準的なBSD sockaddr_inの16とは異なります。既存環境での動作実績を、すべてのメモリ処理が正しいという保証にはしません。
v0.4.3配布物の `--about` はv0.4.2と表示されました。表示文字列だけでバージョンを判定せず、ダウンロードURLとGitHub公開SHA-256で配布物を識別しています。

## 根拠

- netmuxdの変更点: [1d0e437: Bump to latest libimobiledevice](https://github.com/jkcoxson/netmuxd/commit/1d0e4374f8baf065a69ebf186a12eb3a8d509e7a)。IPv4の先頭を `0a 02` から `02 00` に変更。
- 古い受信側: [AltServer-Linux v0.0.5のlibimobiledevice](https://github.com/NyaMisty/AltServer-Linux/tree/v0.0.5/libraries/libimobiledevice)。`src/idevice.c` の `idevice_from_mux_device` と `idevice_connect` が旧形式を前提にする。
- 現行送信側: [netmuxd v0.4.3 devices.rs](https://github.com/jkcoxson/netmuxd/blob/v0.4.3/src/devices.rs)。形式はコンパイル対象OSで決まり、CLIでBSD形式へ切り替える設定はない。
- 関連する上流報告: [libimobiledevice #1248](https://github.com/libimobiledevice/libimobiledevice/issues/1248)、[libusbmuxd #134](https://github.com/libimobiledevice/libusbmuxd/issues/134)。今回の実機比較とは別の、同種の形式不一致の報告。

これはバージョン依存を説明する具体的な欠陥です。過去のv0.3.2検証時の詳細ログは残っておらず、当時の全失敗がこの原因だけだったとまでは断定しません。heartbeatによる端末消失も別問題として残ります。

## 実機比較の方法と範囲

本番27015を維持し、未改造の公式配布物を27016/27017に一時起動しました。
`--disable-unix --disable-mdns --disable-heartbeat`、v0.4.3にはさらに `--disable-usb` を指定し、USBソケット、探索、heartbeatと本番の競合を避けました。
本番DeviceListで得た同じ端末情報を、検証用プロセスだけに `AddDevice` で登録し、実際のListDevices応答を比較しました。
ペアリング情報は既存ストレージから読み取るだけで、削除・再ペアリングはしていません。識別子・IP・鍵はこの記録に含めません。

ダウンロードしたtar.gzのSHA-256はGitHub Releases APIのdigestと一致:

```text
v0.3.2 netmuxd-x86_64-unknown-linux-gnu.tar.gz
1a85e69a258349d2e130aa8475f9d18f212331db3ab46843c0b8b05020f556bb
v0.4.3 netmuxd-x86_64-unknown-linux-gnu.tar.gz
85b6598284fc639f2a282584461d05e2090b79bdf3ec949d2a5e5d3dc655dde4
```

検証プロセスは停止済み。本番healthcheckは正常。新バージョンでのアプリ更新成功を示す試験ではありません。

読み取り専用の形式チェック:

```sh
python3 tools/check-netmux-compatibility.py
# 別ポートで起動済みの検証対象を調べる場合
python3 tools/check-netmux-compatibility.py --port 27016
```

終了コード0=旧形式として解釈可能、1=非互換または通信エラー、2=ネットワーク端末がなく判定不能。
このチェック単独ではheartbeat・認証・アプリ更新の正常性は保証しません。

## 本体を改造・フォークしない代替案

| 方法 | 調査結果 |
|---|---|
| 公式netmuxd最新版へ交換 | v0.4.3も旧AltServerとは形式が合わない |
| `--upstream-usbmuxd` 連携設定 | USB要求の転送には使えるが、ネットワーク端末のアドレス形式は変換しない |
| Debianのlibimobiledevice更新 | AltServer配布物は静的リンク。OSの共有ライブラリを交換しても内蔵コードは変わらない |
| usbmuxd2へ交換 | [現行Muxer.cpp](https://github.com/tihmstar/usbmuxd2/blob/744c46f/usbmuxd2/Muxer.cpp)もLinuxのsockaddr形式を返す。さらに公式リリースがなくビルド管理が必要。未導入 |
| AltServer公式Linux更新版 | 調査時点の最新公開リリースはv0.0.5。利用可能なActions artifactもなかった |
| 外部の形式変換プログラム | 利用者の「netmuxdを改造しなければよい」という方針で試験中。公式v0.4.3の応答形式を変換できることを実機確認 |
| Windows/macOS版AltServerへ移行 | Linuxサーバーとは運用先が変わる。今回のLinux構成の修正としては扱わず、未導入 |

通常インストーラではv0.1.4指定を維持しています。以下の一時試験を、永続的な移行の完了とはしていません。

## 外部変換の一時試験

`scripts/runtime/altserver-netmux-compat` はPython標準ライブラリだけで動作するlocalhost限定の中継です。
ListDevicesとAttachedのNetworkAddressだけをBSD形式へ変換します。ペアリング応答は元のフレームのまま転送し、Connect成功後はバイト列をそのまま双方向転送します。
netmuxd本体・依存ライブラリへのパッチはありません。

```sh
sudo sh scripts/trial-netmux-compat.sh
```

amd64用の公式v0.4.3アーカイブをSHA-256検証し、別ディレクトリに配置します。
既存のnetmuxdバイナリは保持し、`/run` 配下の一時unit設定で旧AltServer→27015の変換プロセス→27016の公式netmuxdへ接続します。
20分後に元の設定へ戻すsystemd timerを先に設定します。試験中のホスト再起動でも一時unit設定は消えます。

```sh
# 時間を待たずに元へ戻す
sudo sh /var/lib/altserver-native/netmux-compat-trial/rollback.sh
```

検証済み:

- Debian上で23件の回帰テスト成功。フレーム分割、端末一覧と通知の変換、ペアリング応答の完全一致、Connect後の双方向通信、送信終了後の応答、接続拒否後の継続、巨大フレーム拒否を含む。
- 一時構成の公式netmuxdバイナリのSHA-256が配布版と一致（`d42e0d1ed1a29c38693083db919e4cb2e1ce9e08799fa19a2ee388882d9bcc23`）。
- 実機のNetworkAddressが `bsd-ipv4` になり、healthcheckが正常。

- 利用者がUSBを外したAltStoreで「すべて更新」に成功し、二段階認証が要求されなかったことを確認。
- netmuxdと変換処理を再起動した後、端末の再検出とhealthcheck正常を確認。
- DynamicUser・ProtectSystem・ProtectHome・localhost限定のサンドボックス設定でも変換応答を確認。

未確認: iPhoneのWi-Fi切断後の再接続によるアプリ更新、長時間運用、ホスト全体の再起動。通常インストーラの旧版指定はまだ解除しません。

試験に成功した既存環境で設定を永続化する場合:

```sh
sudo sh scripts/keep-netmux-compat.sh
# 永続化後に元の構成へ戻す場合
sudo sh /var/lib/altserver-native/netmux-compat-trial/restore-original.sh
```

永続化は別名の公式バイナリと専用のsystemd drop-inを追加します。元のnetmuxdバイナリと基本unitは保持します。
一時試験が有効な間だけ実行できます。上記の復旧スクリプトを置く前に自動ロールバックを解除することはありません。
