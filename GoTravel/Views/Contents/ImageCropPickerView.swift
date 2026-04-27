import SwiftUI
import PhotosUI
import UIKit

// MARK: - ImageCropPickerView（写真選択 → クロップのラッパー）
struct ImageCropPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    var aspectRatio: CGFloat = 1.0

    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isPickerDismissed = false

    var body: some View {
        ZStack {
            if let selectedImage {
                ImageCropperView(
                    image: selectedImage,
                    aspectRatio: aspectRatio,
                    onCrop: { cropped in
                        image = cropped
                        presentationMode.wrappedValue.dismiss()
                    },
                    onCancel: {
                        self.selectedImage = nil
                        presentationMode.wrappedValue.dismiss()
                    },
                    onReselect: {
                        self.selectedImage = nil
                        showImagePicker = true
                    }
                )
            } else {
                Color.black.ignoresSafeArea()
                    .onAppear { showImagePicker = true }
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            isPickerDismissed = true
        }) {
            ImagePickerView(sourceType: .photoLibrary, image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newValue in
            if newValue == nil, isPickerDismissed {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - ImageCropperView（クロップUI）
struct ImageCropperView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    let onCrop: (UIImage) -> Void
    let onCancel: () -> Void
    let onReselect: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showHint = true
    @State private var showGrid = false
    @State private var initialized = false

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 6.0

    var body: some View {
        GeometryReader { geometry in
            let cropSize = calculateCropSize(in: geometry.size)

            ZStack {
                Color.black.ignoresSafeArea()

                // 画像
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                showGrid = true
                                let newScale = lastScale * value
                                scale = min(max(newScale, minScale), maxScale)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                withAnimation(.easeOut(duration: 0.3)) { showGrid = false }
                                clampOffset(geometry: geometry, cropSize: cropSize)
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                showGrid = true
                                let newOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = newOffset
                            }
                            .onEnded { _ in
                                lastOffset = offset
                                withAnimation(.easeOut(duration: 0.3)) { showGrid = false }
                                clampOffset(geometry: geometry, cropSize: cropSize)
                            }
                    )

                // 暗転オーバーレイ（クロップ枠の外）
                CropOverlay(cropSize: cropSize)
                    .allowsHitTesting(false)

                // グリッド線（操作中に表示）
                if showGrid {
                    CropGridView(cropSize: cropSize)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                // コーナーハンドル（常時表示）
                CropCornerHandles(cropSize: cropSize)
                    .allowsHitTesting(false)

                // UI レイヤー
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }

                        Spacer()

                        Text("写真を調整")
                            .font(.headline)
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: {
                            cropImage(geometry: geometry, cropSize: cropSize)
                        }) {
                            Text("完了")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.yellow)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Spacer()

                    // ヒントとボタン
                    VStack(spacing: 16) {
                        if showHint {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.pinch")
                                    .font(.caption)
                                Text("ピンチで拡大・ドラッグで移動")
                                    .font(.caption)
                            }
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())
                            .transition(.opacity)
                        }

                        HStack(spacing: 24) {
                            // 写真を選び直す
                            Button(action: onReselect) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.subheadline)
                                    Text("選び直す")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                            }

                            // リセット
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    resetTransform(geometry: geometry, cropSize: cropSize)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.subheadline)
                                    Text("リセット")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, 48)
                    }
                }
            }
            .onAppear {
                guard !initialized else { return }
                initialized = true
                let initial = fillScale(containerSize: geometry.size, cropSize: cropSize)
                scale = initial
                lastScale = initial

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut(duration: 0.6)) { showHint = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func calculateCropSize(in containerSize: CGSize) -> CGSize {
        let padding: CGFloat = 40
        let maxWidth = containerSize.width - padding * 2
        let maxHeight = containerSize.height - 180 // ヘッダー・ボタン用の余白

        if aspectRatio == 1.0 {
            let size = min(maxWidth, maxHeight)
            return CGSize(width: size, height: size)
        } else {
            let width = min(maxWidth, maxHeight * aspectRatio)
            return CGSize(width: width, height: width / aspectRatio)
        }
    }

    // 画像がクロップ枠を覆う最小スケールを計算
    private func fillScale(containerSize: CGSize, cropSize: CGSize) -> CGFloat {
        let imgAspect = image.size.width / image.size.height
        let contAspect = containerSize.width / containerSize.height
        let fittedW: CGFloat
        let fittedH: CGFloat
        if imgAspect > contAspect {
            fittedH = containerSize.height
            fittedW = fittedH * imgAspect
        } else {
            fittedW = containerSize.width
            fittedH = fittedW / imgAspect
        }
        let scaleW = cropSize.width / fittedW
        let scaleH = cropSize.height / fittedH
        return max(max(scaleW, scaleH), 1.0)
    }

    private func resetTransform(geometry: GeometryProxy, cropSize: CGSize) {
        let initial = fillScale(containerSize: geometry.size, cropSize: cropSize)
        scale = initial
        lastScale = initial
        offset = .zero
        lastOffset = .zero
    }

    // ドラッグ後に画像がクロップ枠から外れないようにクランプ
    private func clampOffset(geometry: GeometryProxy, cropSize: CGSize) {
        let imgAspect = image.size.width / image.size.height
        let contAspect = geometry.size.width / geometry.size.height
        let fittedW: CGFloat
        let fittedH: CGFloat
        if imgAspect > contAspect {
            fittedH = geometry.size.height
            fittedW = fittedH * imgAspect
        } else {
            fittedW = geometry.size.width
            fittedH = fittedW / imgAspect
        }
        let dispW = fittedW * scale
        let dispH = fittedH * scale
        let maxX = max(0, (dispW - cropSize.width) / 2)
        let maxY = max(0, (dispH - cropSize.height) / 2)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = CGSize(
                width: min(max(offset.width, -maxX), maxX),
                height: min(max(offset.height, -maxY), maxY)
            )
        }
        lastOffset = offset
    }

    // MARK: - Crop
    private func cropImage(geometry: GeometryProxy, cropSize: CGSize) {
        let containerSize = geometry.size
        let imgSize = image.size
        let imgAspect = imgSize.width / imgSize.height
        let contAspect = containerSize.width / containerSize.height

        let fittedSize: CGSize
        if imgAspect > contAspect {
            let h = containerSize.height
            fittedSize = CGSize(width: h * imgAspect, height: h)
        } else {
            let w = containerSize.width
            fittedSize = CGSize(width: w, height: w / imgAspect)
        }

        let displayedSize = CGSize(width: fittedSize.width * scale, height: fittedSize.height * scale)
        let imageOrigin = CGPoint(
            x: (containerSize.width - displayedSize.width) / 2 + offset.width,
            y: (containerSize.height - displayedSize.height) / 2 + offset.height
        )

        let cropRect = CGRect(
            x: (containerSize.width - cropSize.width) / 2,
            y: (containerSize.height - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        )

        let relOrigin = CGPoint(x: cropRect.origin.x - imageOrigin.x, y: cropRect.origin.y - imageOrigin.y)
        let scale2img = imgSize.width / displayedSize.width
        var cropInImg = CGRect(
            x: relOrigin.x * scale2img,
            y: relOrigin.y * scale2img,
            width: cropRect.width * scale2img,
            height: cropRect.height * scale2img
        )
        cropInImg = cropInImg.intersection(CGRect(origin: .zero, size: imgSize))

        guard !cropInImg.isNull, cropInImg.width > 0, cropInImg.height > 0 else {
            onCrop(image)
            return
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let cropped = UIGraphicsImageRenderer(size: cropInImg.size, format: format).image { _ in
            image.draw(at: CGPoint(x: -cropInImg.origin.x, y: -cropInImg.origin.y))
        }
        onCrop(cropped)
    }
}

// MARK: - CropOverlay（暗転マスク）
struct CropOverlay: View {
    let cropSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.55)
                Rectangle()
                    .frame(width: cropSize.width, height: cropSize.height)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - CropGridView（グリッド線）
struct CropGridView: View {
    let cropSize: CGSize

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let left = (geometry.size.width - cropSize.width) / 2
                let top = (geometry.size.height - cropSize.height) / 2
                let w = cropSize.width
                let h = cropSize.height

                // 縦線 × 2
                ForEach([1, 2], id: \.self) { i in
                    let x = left + w * CGFloat(i) / 3
                    Path { p in
                        p.move(to: CGPoint(x: x, y: top))
                        p.addLine(to: CGPoint(x: x, y: top + h))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.7)
                }
                // 横線 × 2
                ForEach([1, 2], id: \.self) { i in
                    let y = top + h * CGFloat(i) / 3
                    Path { p in
                        p.move(to: CGPoint(x: left, y: y))
                        p.addLine(to: CGPoint(x: left + w, y: y))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.7)
                }
            }
        }
    }
}

// MARK: - CropCornerHandles（コーナーハンドル）
struct CropCornerHandles: View {
    let cropSize: CGSize
    private let len: CGFloat = 22
    private let thick: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let left = (geometry.size.width - cropSize.width) / 2
            let top = (geometry.size.height - cropSize.height) / 2
            let right = left + cropSize.width
            let bottom = top + cropSize.height

            ZStack {
                // 枠線
                Path { p in
                    p.addRect(CGRect(x: left, y: top, width: cropSize.width, height: cropSize.height))
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 1)

                // 4コーナー
                ForEach(corners(left: left, top: top, right: right, bottom: bottom), id: \.id) { corner in
                    Path { p in
                        p.move(to: corner.h1)
                        p.addLine(to: corner.origin)
                        p.addLine(to: corner.v1)
                    }
                    .stroke(Color.white, style: StrokeStyle(lineWidth: thick, lineCap: .round))
                }
            }
        }
    }

    private struct Corner {
        let id: Int
        let origin: CGPoint
        let h1: CGPoint
        let v1: CGPoint
    }

    private func corners(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) -> [Corner] {
        [
            Corner(id: 0, origin: CGPoint(x: left, y: top),     h1: CGPoint(x: left + len, y: top),    v1: CGPoint(x: left,  y: top + len)),
            Corner(id: 1, origin: CGPoint(x: right, y: top),    h1: CGPoint(x: right - len, y: top),   v1: CGPoint(x: right, y: top + len)),
            Corner(id: 2, origin: CGPoint(x: left, y: bottom),  h1: CGPoint(x: left + len, y: bottom), v1: CGPoint(x: left,  y: bottom - len)),
            Corner(id: 3, origin: CGPoint(x: right, y: bottom), h1: CGPoint(x: right - len, y: bottom),v1: CGPoint(x: right, y: bottom - len)),
        ]
    }
}
