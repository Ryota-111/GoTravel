# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GoTravel（アプリ名 Travory）は SwiftUI + Core Data + CloudKit の iOS 旅行計画アプリ。構成は MVVM。

## Important Notes

- **CloudKit コンテナID**: `iCloud.com.gmail.taismryotasis.Travory`。データは `NSPersistentCloudKitContainer`（`CoreDataManager.shared`）でプライベートDBに自動同期する
- **共有機能のみパブリックDB**: 旅行計画の共有（共有コード）だけは `SharedTravelPlan` レコードとして
  パブリックDBに手動で読み書きする。Core Data 自動同期はプライベートDBで他人から見えないため
  → **詳細は [docs/共有機能.md](docs/共有機能.md)**（仕組み・CloudKit環境の罠・問い合わせ対応手順）
- **iCloud 必須**: 未サインイン時は `MainTabView` 起動時にアラートを表示
- **認証**: Apple Sign In が必須。`AuthViewModel` が `@EnvironmentObject` としてアプリ全体に注入される
- **日本語UI**: インターフェースは日本語。ロケールは `ja_JP` に固定
- **画像**: 実データは Documents ディレクトリに保存し、Core Data にはファイル名だけを記録する
