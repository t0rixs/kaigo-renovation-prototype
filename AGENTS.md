# Project Instructions

## Work Log

- 作業を始める前に `WORKLOG.md` を確認する。
- 変更を完了するたびに、目的、実施内容、確認結果、残件を `WORKLOG.md` の末尾へ追記する。
- 過去の記録は削除または上書きせず、1枚の履歴として蓄積する。
- APIキー、署名情報、個人情報などの機密値を記録しない。

## Physical Device Updates

- `lib/`、`assets/`、`pubspec.yaml`、`android/`、`ios/`、`web/`など、実行されるアプリへ影響する変更を「アプリ変更」とする。
- アプリ変更を完了する前に `flutter devices` を実行する。
- 接続中の物理Android端末またはiPhoneがある場合は、解析とテストの成功後、その端末へ最新版をインストールする。エミュレーター、シミュレーター、Chrome、macOSはこのルールの対象外とする。
- Android実機は `flutter build apk --debug` の後、`adb -s <device-id> install -r -t build/app/outputs/flutter-apk/app-debug.apk` で上書き更新し、既存のアプリ内データを維持する。
- 既存アプリを削除してデータを消す可能性があるため、Android実機の更新に `flutter install`は使用しない。
- iPhone実機は署名設定を確認し、既存のアプリ内データを維持できる更新方法を使用する。再インストールが必要な場合は、実行前にユーザーへデータへの影響を伝える。
- インストール後は可能な範囲でアプリの起動を確認し、端末名、更新結果、確認結果を `WORKLOG.md` に記録する。
- 接続実機のロック、権限、署名などで更新できない場合は黙って省略せず、実行した内容と阻害要因を報告して `WORKLOG.md` に残す。
- Markdownなど文書だけの変更では、実機更新は不要とする。
