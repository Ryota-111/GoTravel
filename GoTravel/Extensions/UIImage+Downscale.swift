import UIKit

extension UIImage {

    /// 保存するときの長辺の上限。
    ///
    /// 端末のカメラは 4000px を超える写真を返す。原寸のまま持つと、
    /// 1枚が数MBになり、iCloud に預けるようになった今は
    /// **お客様の iCloud 容量をそのぶん消費する。**
    /// 画面で使うのはカードの背景と詳細の1枚なので、この大きさで足りる。
    /// アルバム側（`AlbumManager`）も同じ値を使っている
    static let storedPhotoMaxPixel: CGFloat = 2048

    /// 長辺が `maxPixel` を超える場合だけ縮小する。
    /// 小さい画像を引き伸ばすことはない
    func downscaled(maxPixel: CGFloat = UIImage.storedPhotoMaxPixel) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxPixel else { return self }

        let scale = maxPixel / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// 端末に保存し、iCloud にも預ける写真の作り方。
    ///
    /// **写真を保存するときは必ずこれを通す。** `jpegData` を直に呼ぶと
    /// 原寸のまま保存され、容量を無駄に食う
    func storedPhotoData(compressionQuality: CGFloat = 0.7) -> Data? {
        downscaled().jpegData(compressionQuality: compressionQuality)
    }
}
