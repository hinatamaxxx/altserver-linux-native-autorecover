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
| 外部の形式変換プログラム | netmuxd本体をそのまま利用できるが、変換部分の保守と実機検証が必要。採否は利用者の方針確認中 |
| Windows/macOS版AltServerへ移行 | Linuxサーバーとは運用先が変わる。今回のLinux構成の修正としては扱わず、未導入 |

現時点ではv0.1.4指定を維持しています。「バージョン依存がなくなった」とはしていません。
