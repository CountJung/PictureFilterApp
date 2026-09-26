import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// A conservative still-image skin softener. Vision runs locally and the mask
/// leaves the eyes and mouth clear; images without a detected face pass through.
enum FaceSkinSmoother {
    static func apply(to image: CIImage, source: CGImage, allIntensity: Double,
                      faceIntensities: [Int: Double]) throws -> CIImage {
        guard allIntensity > 0 || faceIntensities.values.contains(where: { $0 > 0 }) else { return image }
        let request = VNDetectFaceLandmarksRequest()
        do {
            try VNImageRequestHandler(cgImage: source, orientation: .up).perform([request])
        } catch {
            // Vision may not be available in a simulator runtime; keep the
            // regular edit/export path usable when face inference fails.
            return image
        }
        let faces = (request.results ?? []).sorted { $0.boundingBox.midX < $1.boundingBox.midX }
        guard !faces.isEmpty,
              let mask = makeMask(faces: faces, width: source.width, height: source.height,
                                  allIntensity: allIntensity, faceIntensities: faceIntensities) else { return image }

        let extent = image.extent
        let blurred = image.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1, min(extent.width, extent.height) * 0.004)])
            .cropped(to: extent)

        let maskImage = CIImage(cgImage: mask)
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1, min(extent.width, extent.height) * 0.012)])
            .cropped(to: extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = blurred
        blend.backgroundImage = image
        blend.maskImage = maskImage
        return (blend.outputImage ?? image).cropped(to: extent)
    }

    private static func makeMask(faces: [VNFaceObservation], width: Int, height: Int,
                                 allIntensity: Double, faceIntensities: [Int: Double]) -> CGImage? {
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for (index, face) in faces.enumerated() {
            let intensity = faceIntensities[index] ?? allIntensity
            guard intensity > 0, let landmarks = face.landmarks else { continue }
            let box = face.boundingBox
            let rect = CGRect(x: box.minX * CGFloat(width), y: box.minY * CGFloat(height),
                              width: box.width * CGFloat(width), height: box.height * CGFloat(height))
            context.setFillColor(gray: min(0.34, max(0, intensity * 0.34)), alpha: 1)
            if let contour = face.landmarks?.faceContour, contour.normalizedPoints.count > 2 {
                let contourPoints = contour.normalizedPoints.map { point in
                    CGPoint(x: (box.minX + CGFloat(point.x) * box.width) * CGFloat(width),
                            y: (box.minY + CGFloat(point.y) * box.height) * CGFloat(height))
                }
                let path = CGMutablePath()
                path.addLines(between: contourPoints)
                let foreheadInset = rect.height * 0.16
                path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.maxY - foreheadInset))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.maxY - foreheadInset))
                path.closeSubpath()
                context.addPath(path)
                context.fillPath()
            } else {
                context.fillEllipse(in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.04))
            }
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
