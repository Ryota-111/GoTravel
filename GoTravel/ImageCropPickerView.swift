import SwiftUI
import PhotosUI
import UIKit

struct ImageCropPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?

    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isPickerDismissed = false

    var aspectRatio: CGFloat = 1.0

    var body: some View {
        ZStack {
            if let selectedImage = selectedImage {
                ImageCropperView(
                    image: selectedImage,
                    aspectRatio: aspectRatio,
                    onCrop: { croppedImage in
                        print("🖼️ ImageCropPickerView: トリミング完了 - サイズ: \(croppedImage.size)")
                        image = croppedImage
                        print("🖼️ ImageCropPickerView: 画像をバインディングに設定")
                        presentationMode.wrappedValue.dismiss()
                    },
                    onCancel: {
                        print("❌ ImageCropPickerView: キャンセル")
                        self.selectedImage = nil
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else {
                Color.clear
                    .onAppear {
                        showImagePicker = true
                    }
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            print("📷 ImagePickerView閉じた")
            isPickerDismissed = true
        }) {
            ImagePickerView(sourceType: .photoLibrary, image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newValue in
            if let img = newValue {
                print("📸 ImageCropPickerView: selectedImage更新 - サイズ: \(img.size)")
            } else if isPickerDismissed && newValue == nil {
                // Pickerが閉じられて、画像がnilの場合のみ親を閉じる
                print("⚠️ ImageCropPickerView: 画像が選択されなかったので閉じます")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct ImageCropperView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 6.0

    var body: some View {
        GeometryReader { geometry in
            let cropSize = calculateCropSize(in: geometry.size)

            ZStack {
                Color.black.ignoresSafeArea()

                // 表示画像
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                // 相対値を使ってスムーズに
                                let newScale = lastScale * value
                                scale = min(max(newScale, minScale), maxScale)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height)
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )

                // 切り抜き枠（中央）
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize.width, height: cropSize.height)
                    .allowsHitTesting(false)

                // 暗いオーバーレイ
                CropOverlay(cropSize: cropSize)
                    .allowsHitTesting(false)

                // ボタン
                VStack {
                    Spacer()
                    HStack(spacing: 40) {
                        Button(action: onCancel) {
                            Text("キャンセル")
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(25)
                        }

                        Button(action: {
                            cropImage(geometry: geometry, cropSize: cropSize)
                        }) {
                            Text("完了")
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(25)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }

    private func calculateCropSize(in containerSize: CGSize) -> CGSize {
        let padding: CGFloat = 40
        let maxWidth = containerSize.width - padding * 2
        let maxHeight = containerSize.height - padding * 2

        if aspectRatio == 1.0 {
            let size = min(maxWidth, maxHeight)
            return CGSize(width: size, height: size)
        } else {
            // 横長 or 縦長に合わせる
            let width = min(maxWidth, maxHeight * aspectRatio)
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        }
    }

    private func cropImage(geometry: GeometryProxy, cropSize: CGSize) {
        let containerSize = geometry.size
        let imgSize = image.size // UIImageの"ポイント"単位
        let imgAspect = imgSize.width / imgSize.height
        let containerAspect = containerSize.width / containerSize.height

        // 1) scaledToFit によるフィットサイズ（scaleEffect前）
        let fittedSize: CGSize
        if imgAspect > containerAspect {
            // 画像が横長 -> containerの幅に合わせる
            let w = containerSize.width
            let h = w / imgAspect
            fittedSize = CGSize(width: w, height: h)
        } else {
            // 画像が縦長 -> containerの高さに合わせる
            let h = containerSize.height
            let w = h * imgAspect
            fittedSize = CGSize(width: w, height: h)
        }

        // 2) 実際に表示されているサイズ（scaleEffect を反映）
        let displayedSize = CGSize(width: fittedSize.width * scale, height: fittedSize.height * scale)

        // 3) 表示中画像の左上座標（コンテナ座標系）
        let imageOrigin = CGPoint(
            x: (containerSize.width - displayedSize.width) / 2 + offset.width,
            y: (containerSize.height - displayedSize.height) / 2 + offset.height
        )

        // 4) 切り抜き枠（コンテナ座標系：中央に配置）
        let cropRectInContainer = CGRect(
            x: (containerSize.width - cropSize.width) / 2,
            y: (containerSize.height - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        )

        // 5) 切り抜き枠が表示画像内での相対位置（表示画像の左上を(0,0)とした座標）
        let relativeOriginInDisplayed = CGPoint(
            x: cropRectInContainer.origin.x - imageOrigin.x,
            y: cropRectInContainer.origin.y - imageOrigin.y
        )

        // 6) 表示 -> 画像（ポイント）へのスケール係数
        // displayedSize.width は view 上のポイント、imgSize.width は画像のポイント
        let displayToImageScale = imgSize.width / displayedSize.width

        // 切り抜き領域（画像のポイント座標系）
        var cropRectInImagePoints = CGRect(
            x: relativeOriginInDisplayed.x * displayToImageScale,
            y: relativeOriginInDisplayed.y * displayToImageScale,
            width: cropRectInContainer.width * displayToImageScale,
            height: cropRectInContainer.height * displayToImageScale
        )

        // 7) 画像の bounds と交差させてクリップ（範囲外ははみ出さないように）
        let imageBounds = CGRect(origin: .zero, size: imgSize)
        cropRectInImagePoints = cropRectInImagePoints.intersection(imageBounds)

        if cropRectInImagePoints.isNull || cropRectInImagePoints.width <= 0 || cropRectInImagePoints.height <= 0 {
            // 切り抜き範囲が無効なら（全部はみ出してる等） → 元画像を返す
            onCrop(image)
            return
        }

        // 8) UIGraphicsImageRenderer を用いて、UIImage の回転/向きも考慮して切り抜く
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale // ピクセル単位を保つ
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: cropRectInImagePoints.size, format: format)
        let cropped = renderer.image { _ in
            // 描画するときに、切り取り領域が (0,0) に来るように画像をマイナスオフセットで描画する
            let drawOrigin = CGPoint(x: -cropRectInImagePoints.origin.x, y: -cropRectInImagePoints.origin.y)
            image.draw(at: drawOrigin)
        }

        onCrop(cropped)
    }
}

// Overlay（切り抜き領域以外を暗くする）
struct CropOverlay: View {
    let cropSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let container = geometry.size
            ZStack {
                // 黒半透明全体
                Color.black.opacity(0.6)

                // 中央に透明枠をくり抜く
                Rectangle()
                    .frame(width: cropSize.width, height: cropSize.height)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: container.width, height: container.height)
        }
    }
}
