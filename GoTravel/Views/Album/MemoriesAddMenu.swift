import SwiftUI

/// 思い出タブの右下の「＋」（3.8）。
///
/// 思い出タブで作れるものが、アルバムのほかに写真コラージュ・ポスター・日記・ダイジェストと増えたため、
/// ＋を押したらすぐアルバムを作るのをやめ、選べるようにした
struct MemoriesAddMenu: View {
    @Binding var isOpen: Bool
    let onSelect: (Item) -> Void

    enum Item: CaseIterable {
        case collage, poster, diary, digest, album

        var title: String {
            switch self {
            case .collage: return MemoryKind.photoDump.title
            case .poster: return MemoryKind.poster.title
            case .diary: return MemoryKind.diary.title
            case .digest: return "旅のダイジェスト"
            case .album: return "アルバム"
            }
        }

        var english: String {
            switch self {
            case .collage: return "photo collage"
            case .poster: return "travel poster"
            case .diary: return "travel diary"
            case .digest: return "trip movie"
            case .album: return "new album"
            }
        }

        var icon: String {
            switch self {
            case .collage: return MemoryKind.photoDump.icon
            case .poster: return MemoryKind.poster.icon
            case .diary: return MemoryKind.diary.icon
            case .digest: return "play.rectangle.on.rectangle"
            case .album: return "rectangle.stack.badge.plus"
            }
        }
    }

    var body: some View {
        // アルバムは＋のすぐ上（今まで＋で作っていたもの）
        FloatingAddMenu(
            isOpen: $isOpen,
            entries: Item.allCases.map { item in
                .init(id: item.title, english: item.english, title: item.title, icon: item.icon,
                      spokenLabel: "\(item.title)を作る") { onSelect(item) }
            },
            buttonLabel: "作る",
            accessibilityHint: "写真コラージュ・ポスター・日記・ダイジェスト・アルバムから選べます",
            identifier: "memoriesAddButton")
    }
}
