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
                        image = croppedImage
                        presentationMode.wrappedValue.dismiss()
                    },
                    onCancel: {
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
            isPickerDismissed = true
        }) {
            ImagePickerView(sourceType: .photoLibrary, image: $selectedImage)
        }
        .onChange(of: selectedImage) { _, newValue in
            if newValue != nil {
            } else if isPickerDismissed && newValue == nil {
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

                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize.width, height: cropSize.height)
                    .allowsHitTesting(false)

                CropOverlay(cropSize: cropSize)
                    .allowsHitTesting(false)

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
            let width = min(maxWidth, maxHeight * aspectRatio)
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        }
    }

    private func cropImage(geometry: GeometryProxy, cropSize: CGSize) {
        let containerSize = geometry.size
        let imgSize = image.size
        let imgAspect = imgSize.width / imgSize.height
        let containerAspect = containerSize.width / containerSize.height
        let fittedSize: CGSize
        if imgAspect > containerAspect {
            let w = containerSize.width
            let h = w / imgAspect
            fittedSize = CGSize(width: w, height: h)
        } else {
            let h = containerSize.height
            let w = h * imgAspect
            fittedSize = CGSize(width: w, height: h)
        }

        let displayedSize = CGSize(width: fittedSize.width * scale, height: fittedSize.height * scale)
        let imageOrigin = CGPoint(
            x: (containerSize.width - displayedSize.width) / 2 + offset.width,
            y: (containerSize.height - displayedSize.height) / 2 + offset.height
        )

        let cropRectInContainer = CGRect(
            x: (containerSize.width - cropSize.width) / 2,
            y: (containerSize.height - cropSize.height) / 2,
            width: cropSize.width,
            height: cropSize.height
        )

        let relativeOriginInDisplayed = CGPoint(
            x: cropRectInContainer.origin.x - imageOrigin.x,
            y: cropRectInContainer.origin.y - imageOrigin.y
        )

        let displayToImageScale = imgSize.width / displayedSize.width
        var cropRectInImagePoints = CGRect(
            x: relativeOriginInDisplayed.x * displayToImageScale,
            y: relativeOriginInDisplayed.y * displayToImageScale,
            width: cropRectInContainer.width * displayToImageScale,
            height: cropRectInContainer.height * displayToImageScale
        )
        
        let imageBounds = CGRect(origin: .zero, size: imgSize)
        cropRectInImagePoints = cropRectInImagePoints.intersection(imageBounds)

        if cropRectInImagePoints.isNull || cropRectInImagePoints.width <= 0 || cropRectInImagePoints.height <= 0 {
            onCrop(image)
            return
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: cropRectInImagePoints.size, format: format)
        let cropped = renderer.image { _ in
            let drawOrigin = CGPoint(x: -cropRectInImagePoints.origin.x, y: -cropRectInImagePoints.origin.y)
            image.draw(at: drawOrigin)
        }

        onCrop(cropped)
    }
}

struct CropOverlay: View {
    let cropSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let container = geometry.size
            ZStack {
                Color.black.opacity(0.6)
                Rectangle()
                    .frame(width: cropSize.width, height: cropSize.height)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: container.width, height: container.height)
        }
    }
}
