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
}
