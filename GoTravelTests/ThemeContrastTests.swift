import Testing
import SwiftUI
@testable import GoTravel

/// どのテーマでも、ボタン・リンク・カードの文字が読めること。
///
/// テーマを足したり色を変えたりしたときに、見えにくい組み合わせが出ないかをここで見張る。
/// 目安は太字・大きめの文字で 3.0（WCAG の大きい文字の基準）、本文で 4.5。
/// テーマが明暗を固定しているときは、その明暗だけを確かめる
struct ThemeContrastTests {

    private struct Case: CustomTestStringConvertible {
        let type: ThemePreset.ThemeType
        let scheme: ColorScheme
        var testDescription: String { "\(type.rawValue)・\(scheme == .dark ? "ダーク" : "ライト")" }
    }

    private static var cases: [Case] {
        ThemePreset.ThemeType.allCases.flatMap { type in
            (type.preferredColorScheme.map { [$0] } ?? [.light, .dark]).map { Case(type: type, scheme: $0) }
        }
    }

    @Test("差し色のリンクの文字が、画面とカードの上で読める", arguments: cases)
    private func accentText(_ c: Case) {
        let theme = ThemePreset(type: c.type)
        let dark = c.scheme == .dark
        let screen = dark ? theme.backgroundDark : theme.backgroundLight
        let card = dark ? theme.secondaryBackgroundDark : theme.secondaryBackgroundLight
        #expect(ThemePreset.contrastRatio(theme.actionFill, screen) >= 3.0)
        #expect(ThemePreset.contrastRatio(theme.actionFill, card) >= 3.0)
    }

    @Test("一覧のカード（予定・保存した場所）の面が、画面の地と見分けられ、上の文字が読める", arguments: cases)
    private func listCardSurface(_ c: Case) {
        let theme = ThemePreset(type: c.type)
        guard c.scheme == .light else { return }
        let surface = theme.listCardSurface(for: .light)
        #expect(ThemePreset.contrastRatio(surface, theme.backgroundLight) >= ThemePreset.listCardMinimumContrast)
        #expect(ThemePreset.contrastRatio(surface, theme.secondaryBackgroundLight) >= ThemePreset.listCardMinimumContrast)
        #expect(ThemePreset.contrastRatio(ThemePreset.readableText(on: surface), surface) >= 4.5)
    }

    @Test("塗りのボタンの文字が読める", arguments: cases)
    private func filledButton(_ c: Case) {
        let theme = ThemePreset(type: c.type)
        let label = ThemePreset.readableText(on: theme.actionFill)
        #expect(ThemePreset.contrastRatio(label, theme.actionFill) >= 3.0)
    }

    @Test("差し色を薄く敷いた面の上の文字が読める（取り込みのボタンなど）", arguments: cases)
    private func tintedSurface(_ c: Case) {
        let theme = ThemePreset(type: c.type)
        let card = c.scheme == .dark ? theme.secondaryBackgroundDark : theme.secondaryBackgroundLight
        let surface = ThemePreset.composite(theme.actionFill, over: card, opacity: 0.12)
        #expect(ThemePreset.contrastRatio(theme.tintedLabel(on: card), surface) >= 3.0)
    }

    @Test("カードの本文と、アプリ設定の半透明のカードの文字が読める", arguments: cases)
    private func cardText(_ c: Case) {
        let theme = ThemePreset(type: c.type)
        let dark = c.scheme == .dark
        let card = dark ? theme.secondaryBackgroundDark : theme.secondaryBackgroundLight
        #expect(ThemePreset.contrastRatio(ThemePreset.readableText(on: card), card) >= 4.5)

        let ground = dark ? theme.backgroundDark : theme.backgroundLight
        let card2 = ThemePreset.composite(theme.cardBackground2, over: ground)
        #expect(ThemePreset.contrastRatio(theme.textOnCardBackground2(for: c.scheme), card2) >= 4.5)
    }

    // MARK: - 3.0 で増えた画面

    @Test("プロフィールの行（半透明のカード）の題名・値と、見出しが読める", arguments: cases)
    private func profileRows(_ c: Case) {
        let theme = ThemePreset(type: c.type)
        let ground = c.scheme == .dark ? theme.backgroundDark : theme.backgroundLight
        let card = ThemePreset.composite(theme.cardBackground2, over: ground)
        #expect(ThemePreset.contrastRatio(theme.textOnCardBackground2(for: c.scheme), card) >= 4.5)
        #expect(ThemePreset.contrastRatio(theme.secondaryTextOnCardBackground2(for: c.scheme), card) >= 3.0)
        #expect(ThemePreset.contrastRatio(theme.secondaryTextOnScreen(for: c.scheme), ground) >= 3.0)
    }

    @Test("カレンダーの一覧・.ics の読み込みの、行の上のアイコンと操作の文字が読める", arguments: cases)
    private func listTint(_ c: Case) {
        let theme = ThemePreset(type: c.type)
        #expect(ThemePreset.contrastRatio(theme.listTint(for: c.scheme), ThemePreset.listRowBackground(for: c.scheme)) >= 4.5)
    }

    @Test("カレンダーの共有の案内とタグの絞り込みの文字が、画面の上のほうで読める", arguments: cases)
    private func calendarTip(_ c: Case) {
        let theme = ThemePreset(type: c.type)
        let top = theme.calendarScreenTop(for: c.scheme)
        let tipGround = ThemePreset.composite(theme.secondary, over: top, opacity: 0.08)
        #expect(ThemePreset.contrastRatio(ThemePreset.readableText(on: tipGround), tipGround) >= 4.5)
        #expect(ThemePreset.contrastRatio(theme.secondaryLabel(on: top, opacity: 0.08), tipGround) >= 3.0)
        let accent = theme.secondaryLabel(on: top, opacity: 0.08)
        #expect(ThemePreset.contrastRatio(ThemePreset.readableText(on: accent), accent) >= 3.0)
        let filterGround = ThemePreset.composite(theme.secondary, over: top, opacity: 0.12)
        #expect(ThemePreset.contrastRatio(theme.secondaryLabel(on: top, opacity: 0.12), filterGround) >= 3.0)
        // 題名（カレンダーの切り替え）
        let title = c.scheme == .dark ? theme.accent2 : theme.accent1
        #expect(ThemePreset.contrastRatio(title, top) >= 3.0)
    }
}
