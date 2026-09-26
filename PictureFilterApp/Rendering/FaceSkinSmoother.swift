import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// A conservative still-image skin softener. Vision runs locally and the mask
/// leaves the eyes and mouth clear; images without a detected face pass through.
enum FaceSkinSmoother {
    static func apply(to image: CIImage, source: CGImage, intensity: Double) throws -> CIImage {
        guard intensity > 0 else { return image }
        let request = VNDetectFaceLandmarksRequest()
        do {
            try VNImageRequestHandler(cgImage: source, orientation: .up).perform([request])
        } catch {
            // Vision may not be available in a simulator runtime; keep the
            // regular edit/export path usable when face inference fails.
            return image
        }
        guard let faces = request.results, !faces.isEmpty,
              let mask = makeMask(faces: faces, width: source.width, height: source.height) else { return image }

        let extent = image.extent
        let blurred = image.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1, min(extent.width, extent.height) * 0.004)])
            .cropped(to: extent)

        let intensityMask = CIFilter.colorMatrix()
        intensityMask.inputImage = CIImage(cgImage: mask)
        let factor = CGFloat(min(1, max(0, intensity)))
        intensityMask.rVector = CIVector(x: factor, y: 0, z: 0, w: 0)
        intensityMask.gVector = CIVector(x: 0, y: factor, z: 0, w: 0)
        intensityMask.bVector = CIVector(x: 0, y: 0, z: factor, w: 0)
        intensityMask.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let rawMask = intensityMask.outputImage else { return image }
        let maskImage = rawMask
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1, min(extent.width, extent.height) * 0.012)])
            .cropped(to: extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = blurred
        blend.backgroundImage = image
        blend.maskImage = maskImage
        return (blend.outputImage ?? image).cropped(to: extent)
    }

    private static func makeMask(faces: [VNFaceObservation], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for face in faces {
            let box = face.boundingBox
            let rect = CGRect(x: box.minX * CGFloat(width), y: box.minY * CGFloat(height),
                              width: box.width * CGFloat(width), height: box.height * CGFloat(height))
            let faceMask = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.04)
            context.setFillColor(gray: 1, alpha: 1)
            context.fillEllipse(in: faceMask)
            guard let landmarks = face.landmarks else { continue }
            context.setFillColor(gray: 0, alpha: 1)
            for feature in [landmarks.leftEye, landmarks.rightEye, landmarks.leftEyebrow,
                            landmarks.rightEyebrow, landmarks.outerLips, landmarks.innerLips] {
                guard let feature, !feature.normalizedPoints.isEmpty else { continue }
                let points = feature.normalizedPoints.map { point in
                    CGPoint(x: (box.minX + CGFloat(point.x) * box.width) * CGFloat(width),
                            y: (box.minY + CGFloat(point.y) * box.height) * CGFloat(height))
                }
                let bounds = points.dropFirst().reduce(CGRect(origin: points[0], size: .zero)) { rect, point in
                    rect.union(CGRect(origin: point, size: .zero))
                }
                let padding = max(2, min(bounds.width, bounds.height) * 0.25)
                context.fillEllipse(in: bounds.insetBy(dx: -padding, dy: -padding))
            }
        }
        return context.makeImage()
    }
}
