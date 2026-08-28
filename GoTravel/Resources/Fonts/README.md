# 同梱フォント

テーマの「書体」を切り替えるために同梱しているフォント。

| ファイル | PostScript 名 | サイズ | 使うテーマ |
|---|---|---|---|
| ZenAntique-Regular.ttf | `ZenAntique-Regular` | 5.5 MB | レトロ・トラベル（見出し）、パスポート（見出し） |
| ZenKakuGothicNew-Regular.ttf | `ZenKakuGothicNew-Regular` | 2.4 MB | レトロ・トラベル、ガイドブック、パスポート（本文） |

合計 7.9 MB。日本語フォントは全漢字を持つため、1書体でこの大きさになる。

## Info.plist

`UIAppFonts` にファイル名を登録している。フォントを足すときは、
ここにも追記しないと読み込まれない。

## 参照のしかた

`ThemeStyle` の `displayFontName` / `bodyFontName` に **PostScript 名**を書く。
ファイル名ではないので注意。`ThemeStyle.isBundled` が実在を確かめ、
見つからなければ `fontDesign`（システムフォント）に落ちるので、
未同梱の名前を書いても表示は崩れない。

## サブセット化について

漢字を削ってサイズを落とす手はあるが、このアプリは地名や店名を
ユーザーが自由に入力する。稀な漢字が豆腐（□）になるため、
サブセット化はしていない。

## ライセンス

どちらも SIL Open Font License 1.1。同梱・再配布は可能で、
ライセンス全文を添付することが条件のため `OFL-*.txt` を同じ場所に置いている。
削除しないこと。

- Zen Antique — Copyright 2021 The Zen Antique Project Authors
  https://github.com/googlefonts/zen-antique
- Zen Kaku Gothic New — Copyright 2022 The Zen Kaku Gothic Project Authors
  https://github.com/googlefonts/zen-kakugothic

どちらも Reserved Font Name を持つため、改変版を同じ名前で配布することはできない。
そのまま使うぶんには問題ない。
