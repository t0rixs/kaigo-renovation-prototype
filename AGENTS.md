# Project Instructions

## Work Log

- 作業を始める前に `WORKLOG.md` を確認する。
- 変更を完了するたびに、目的、実施内容、確認結果、残件を `WORKLOG.md` の末尾へ追記する。
- 過去の記録は削除または上書きせず、1枚の履歴として蓄積する。
- APIキー、署名情報、個人情報などの機密値を記録しない。

## Browser-First Updates

- Flutter Webを主対象とし、アプリ変更後はChromeで動作確認する。
- スマートフォン相当とPC相当の画面幅で、主要画面の表示と操作を確認する。
- 配布用確認では`./tool/build_web.sh`を使い、`build/web`を公開対象にする。
- Android / iOSの実機更新は自動では行わず、ユーザーが明示的に依頼した場合だけ実施する。
- ブラウザのIndexedDBにある案件データを削除する操作は、ユーザーの明示的な依頼なしに行わない。
- 確認結果は `WORKLOG.md` に記録する。
