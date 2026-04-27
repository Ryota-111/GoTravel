GoTravel (Travory) の App Store リリース前チェックリストを実行してください。

以下の手順で確認を進めてください：

## Step 1: コードの状態確認
次のBashコマンドを実行して現状を把握してください：
- `git status` で未コミットの変更がないか確認
- `git log --oneline -5` で最新コミットを確認
- `grep -r "print(" GoTravel/Services/ GoTravel/ViewModels/ --include="*.swift" | grep -v "//"`  でデバッグprintが残っていないか確認

## Step 2: バージョン・ビルド番号の確認
project.pbxproj から MARKETING_VERSION と CURRENT_PROJECT_VERSION を読み取り、前回リリースから適切にインクリメントされているか確認してください。

## Step 3: StoreKit設定の確認
GoTravel/GoTravel.storekit ファイルを確認し、シミュレーターテスト用の設定がスキームに残っていないか注意喚起してください（本番ビルドではスキームのStoreKit Configurationを外す必要あり）。

## Step 4: チェックリストを表示
以下のチェックリストを表示し、各項目にチェックを促してください：

### 📦 コード・ビルド
- [ ] 未コミットの変更がない（git status クリーン）
- [ ] デバッグ用 print() が残っていない
- [ ] StoreKit Configuration をスキームから外した（本番ビルド時）
- [ ] Release ビルドでビルドエラーがない

### 🔢 バージョン管理
- [ ] MARKETING_VERSION（例: 1.2.0）を更新した
- [ ] CURRENT_PROJECT_VERSION（ビルド番号）をインクリメントした

### 🏪 App Store Connect
- [ ] アプリ内課金の4商品（tip.small/medium/large/xlarge）が「審査の準備完了」状態
- [ ] 新バージョンの「新機能」欄を日本語で記入した
- [ ] スクリーンショットが最新UIを反映している（iPhone 6.7インチ必須）
- [ ] キーワード・説明文に変更があれば更新した

### 🔐 権限・エンタイトルメント
- [ ] CloudKit コンテナID: `iCloud.com.gmail.taismryotasis.Travory` が正しい
- [ ] WeatherKit 有効
- [ ] Apple Sign In 有効
- [ ] Push通知の権限（UNUserNotificationCenter）が正常動作

### 📱 実機テスト
- [ ] iPhone 実機でビルド・起動確認
- [ ] Apple Sign In でのログインが正常動作
- [ ] CloudKit データの同期が正常動作
- [ ] サンドボックス環境でのIAP購入テスト完了
- [ ] タスク通知が正常に届く

### 🌐 プライバシー・コンプライアンス
- [ ] App Store Connect のプライバシー情報が最新機能を反映している
- [ ] 収集データ（CloudKit/Apple ID）の申告が正確

## Step 5: 総合判定
確認結果をもとに「リリース可能」または「要対応項目あり（〇〇）」を判定して伝えてください。
