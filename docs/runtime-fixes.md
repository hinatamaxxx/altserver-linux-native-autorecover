# v0.2.0: 認証情報の維持とWi-Fi復旧

このページは基本プロファイルの説明です。公式netmuxd v0.4.3向けの外部変換・API再登録・15秒チェックは [日本語ガイド](netmuxd-compatibility.md) / [English guide](netmuxd-compatibility.en.md) を参照してください。

## 二段階認証が繰り返される構成上の原因

旧構成は `/home/Alcoholic/.config/anisette-v3/lib/` だけをDocker volumeへ保存していました。しかし、AltServerが利用するv1互換APIの `device.json` と `adi.pb` は親の `anisette-v3/` にあります。`--rm` 付きコンテナを再作成すると、この端末IDとプロビジョニング情報が失われます。

これは [anisette-v3-serverの初期化処理](https://github.com/Dadoum/anisette-v3-server/blob/b2ef80a5f02cf73d09e2bd1eefff9b39d9b8c2f4/source/app.d#L133) で確認できます。実機でも、旧コンテナのマウント外に両ファイルが存在していました。

新構成では `/var/lib/altserver-native/anisette` を設定ディレクトリ全体へマウントします。既存コンテナの状態を取り出し、別のバックアップも残してからコンテナを再作成します。保存済みデータが不完全な場合は、新しい端末IDで起動せずエラーにします。既存のライブラリ用volumeは削除しません。

これにより「コンテナの再作成で別の端末になる」原因を解消します。ただし、Apple側のセッション失効・アカウント保護やAltStore側の保存状態による認証要求は別の問題です。二段階認証が今後一切出ないことを保証する変更ではありません。

## 既存環境の更新

### UTC時刻の扱い

AltServer-Linux v0.0.5は、UTC形式のAnisette時刻を `mktime()` でローカル時刻として解釈します。DebianがJSTの場合、実際の応答時刻が9時間ずれることを実機の `AnisetteDataResponse` で確認しました。AltServerプロセスに `TZ=UTC` を設定し、ホスト全体のタイムゾーンを変えずに修正しています。healthcheckも実際の応答を読み、必須フィールドと時刻の鮮度を確認します。

この設定を既存プロセスへ反映するにはAltServerの再起動が1回必要です。更新スクリプトは設定変更時だけ再起動します。

旧コンテナを停止・削除する**前**に、更新したリポジトリから実行してください。

```sh
sudo sh scripts/upgrade-runtime.sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

この手順は既存の設定を読み、ヘルパーとsystemd unitを更新します。AltServer/netmuxdのバイナリ、USBペアリング、Apple IDの入力を変更する必要はありません。旧ヘルパー・unit・設定は、画面に表示される `/var/backups/altserver-runtime-*` に保存します。Anisetteの移行バックアップは `/var/lib/altserver-native/anisette-backup-*` にあります。

公式 `dadoum/anisette-v3-server` のUID/GID 1000を前提にしています。カスタムイメージは自動移行せず停止します。別のDockerホストへ接続する `DOCKER_HOST` 構成は対象外です。

## 認証用識別情報が変わらないことの確認

作業中のAltStore更新がないときに実行します。出力には識別情報の実値を表示しません。

```sh
sudo python3 tools/check-anisette-identity.py capture --baseline /run/altserver-identity.json
sudo systemctl restart altserver-anisette-docker.service
# サーバーの起動後に実行
sudo python3 tools/check-anisette-identity.py compare --baseline /run/altserver-identity.json
```

比較対象は端末ID・ローカルユーザーID・マシン識別情報のSHA-256です。時間で変化するワンタイムデータは比較しません。ベースラインの上書きは拒否するため、繰り返す場合は別のファイル名を指定してください。

## Wi-Fi復旧の変更

### NSCocoaErrorDomain 3840が残る場合

2026年9月の[公式配信情報](https://cdn.altstore.io/file/altstore/apps.json)では、AltStore 2.2.2の説明にApple IDサインイン時の形式エラー修正と、AltServerを使った手動での上書き更新が案内されています。AltStoreを先に削除する必要はありません。対応OSに合う最新版を公式配信元から入手してください。

[AltSignのUser-Agent修正](https://github.com/rileytestut/AltSign/pull/51)は、Appleの認証エンドポイントがHTMLの503応答を返し、plistの解析で3840になる問題を説明しています。認証はiPhoneのAltStore内でも行われるため、LinuxのAnisetteやnetmuxdだけを直しても、古いクライアントの認証処理は変わりません。エラーログの `Encountered unknown tag html` などで切り分けてください。3840だけで原因を断定しないでください。

AltServer-Linux v0.0.5の初回署名処理にも古い認証User-Agentが含まれています。このバイナリでの再インストールが失敗する場合は、更新済みの公式AltServerを使って同じアカウントでAltStoreを上書き更新する必要があります。ペアリングデータを消す処理や再起動の繰り返しでは修正できません。

- IP候補は設定済みMAC、または設定済み端末に一致するmDNSだけから取得します。
- 自分で広告した `iphone-alt.local` を探索結果として再利用しません。
- 固定IPのフォールバックは、端末IDが確認できた場合に限って使用します。最近のiOSで未認証の端末ID照会が拒否される場合は、MAC/mDNSの一致が必要です。
- IPが同一ならAvahiの設定を書き換えず、再読み込みもしません。
- usbmuxのヘッダーと本文は必要な長さまで受信し、長さ・形式・応答タグを検証します。
- netmuxdが応答するが端末だけ見失った場合は、iPhoneの広告を再送して再登録を待ちます。AltServer/netmuxdは再起動しません。
- v0.1.4の `AddDevice` はheartbeatを二重起動するため利用しません。[該当する上流ソース](https://github.com/jkcoxson/netmuxd/blob/2331c8f76d2991559b9f5ecca772bac05d2a4f14/src/main.rs#L288)
- サービス障害は3回連続の確認後に対象サービスのみ再起動し、5分の再起動間隔を設けます。
- iPhoneが不在でもAnisette・AltServer・netmuxdの状態は確認します。
- AltServerの広告はホストIPだけでなく、実際のプロセスの待受ポートと照合します。
- boot recoveryと定期チェックは同時に復旧処理を実行しません。

`healthy` はインフラの正常性と対象端末の登録を示します。実際の署名・Apple認証・アプリ転送の成功は、iPhoneのAltStoreで確認してください。

終了コード: `0` 正常、`1` インフラ障害または検査エラー、`2` 端末不在またはペアリング待ち、`75` 別のチェックが実行中。timerはチェック終了から1分後に次を実行します。

## ロールバック

表示されたバックアップの `helpers/` と `units/` を管理者が確認し、必要なファイルだけ元の場所へ戻して `systemctl daemon-reload` を実行できます。ただし、旧Anisette unitの `ExecStartPre=docker rm -f` と旧起動スクリプトを無条件に戻すと、再び認証情報を失う構成になります。永続化済みディレクトリを維持してください。認証データのバックアップや実機ログをGitHubに含めないでください。

## English summary

This page describes the base profile. For the opt-in official netmuxd v0.4.3 profile, external translation, API registration, 15-second checks, persistence and restoration, see the [English guide](netmuxd-compatibility.en.md).

The old mount persisted libraries only; the v1 device identity and provisioning lived in the disposable container layer. The upgrade copies the existing complete configuration before container replacement and retains a backup. It validates that stable identity fields survive recreation. Apple may still require 2FA for independent session/account reasons.

Discovery now matches the configured device, rejects synthetic feedback, handles fragmented usbmux frames, and reloads Avahi only on an address change. Missing devices trigger rediscovery without daemon restarts; confirmed daemon failures use a cooldown. Upstream heartbeat behavior and end-to-end AltStore authentication remain separate validation concerns.

AltServer v0.0.5 interprets the UTC Anisette timestamp through local `mktime()`. A nine-hour offset was reproduced on the JST host. Setting `TZ=UTC` for the AltServer process corrects its response without changing the host timezone. Apply the runtime upgrade before stopping or removing the old disposable container:

```sh
sudo sh scripts/upgrade-runtime.sh
sudo /usr/local/sbin/altserver-native-healthcheck
```

The upgrade preserves existing binary and USB pairing choices, migrates the full Anisette configuration, and backs up helpers/units/settings under the printed `/var/backups/altserver-runtime-*` path. Identity backups remain under `/var/lib/altserver-native/anisette-backup-*`. Migration expects the official image's UID/GID 1000; custom images and remote DOCKER_HOST setups are not automatically supported.

Stable identity can be compared with `tools/check-anisette-identity.py capture` and `compare` using a root-only baseline path. The tool compares hashes of stable fields, not time-varying one-time data, and refuses to overwrite a baseline. See the commands in the Japanese section above.

If NSCocoaErrorDomain 3840 remains, distinguish malformed authentication responses from network discovery. The [official AltStore feed](https://cdn.altstore.io/file/altstore/apps.json) documented the September 2026 client authentication fix and manual overwrite update; [AltSign PR #51](https://github.com/rileytestut/AltSign/pull/51) explains the User-Agent-related HTML response. Error 3840 alone is not a unique diagnosis. Updating server recovery does not update the authentication implementation inside an older iPhone client.

Base-profile checks run one minute after completion; the new compatibility profile overrides this to 15 seconds. Exit codes are 0 for healthy infrastructure/registration, 1 for infrastructure or probe failure, 2 for an unavailable/unregistered phone, and 75 for another recovery check holding the lock. A healthy probe is not proof of app signing or installation success; confirm that in AltStore.

When restoring runtime backups, preserve the persistent Anisette state. Blindly restoring the old container-removal startup behavior can reintroduce identity loss. Do not publish authentication backups or device logs.
