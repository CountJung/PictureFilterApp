import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Vision

/// Local portrait effects for still photos. Failed or empty Vision masks leave
/// the input image untouched so an effect never damages an export.
enum PortraitEffects {
    private static let normalizeBackground = CIColorKernel(source: """
        kernel vec4 normalizeBackground(__sample blurred, __sample original) {
            if (blurred.a < 0.0001) { return original; }
            return vec4(blurred.rgb / blurred.a * original.a, original.a);
        }
        """)

    static func applyLighting(to image: CIImage, source: CGImage, allIntensity: Double,
                              faceIntensities: [Int: Double], analyzedFaces: [VNFaceObservation]? = nil) -> CIImage {
        guard allIntensity > 0 || faceIntensities.values.contains(where: { $0 > 0 }) else { return image }
        let faces: [VNFaceObservation]
        if let analyzedFaces { faces = analyzedFaces }
        else {
            let request = VNDetectFaceLandmarksRequest()
            do { try VNImageRequestHandler(cgImage: source, orientation: .up).perform([request]) }
            catch { return image }
            faces = (request.results ?? []).sorted { $0.boundingBox.midX < $1.boundingBox.midX }
        }
        guard !faces.isEmpty,
              let mask = faceMask(faces: faces, width: source.width, height: source.height,
                                  allIntensity: allIntensity, faceIntensities: faceIntensities) else { return image }

        let extent = image.extent
        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = image
        exposure.ev = 0.55
        guard let lit = exposure.outputImage else { return image }
        let softMask = CIImage(cgImage: mask)
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1, min(extent.width, extent.height) * 0.012)])
            .cropped(to: extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = lit
        blend.backgroundImage = image
        blend.maskImage = softMask
        return (blend.outputImage ?? image).cropped(to: extent)
    }

    static func personMask(source: CGImage) throws -> CIImage? {
        let request = VNGeneratePersonInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: source, orientation: .up)
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
        return CIImage(cvPixelBuffer: try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances, from: handler))
    }

    static func applyBackgroundBlur(to image: CIImage, mask: CIImage?, intensity: Double) -> CIImage {
        guard intensity > 0, let rawMask = mask else { return image }
        let extent = image.extent
        guard rawMask.extent.width > 0, rawMask.extent.height > 0 else { return image }
        let scaledMask = rawMask.transformed(by: CGAffineTransform(
            scaleX: extent.width / rawMask.extent.width,
            y: extent.height / rawMask.extent.height
        )).cropped(to: extent)
        let feather = scaledMask.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1, min(extent.width, extent.height) * 0.007)])
            .applyingFilter("CIMaximumCompositing", parameters: [kCIInputBackgroundImageKey: scaledMask])
            .cropped(to: extent)
        // Blur background pixels only. Normalizing by the blurred alpha prevents
        // foreground colors from bleeding across hair and subject edges.
        let backgroundOnly = CIFilter.blendWithMask()
        backgroundOnly.inputImage = CIImage(color: .clear).cropped(to: extent)
        backgroundOnly.backgroundImage = image
        backgroundOnly.maskImage = scaledMask
        guard let weighted = backgroundOnly.outputImage else { return image }
        // Use the same blur working resolution as the portrait analysis. Large
        // Gaussian radii otherwise use different internal approximations.
        let scale = min(1, 1600 / max(extent.width, extent.height))
        let working = weighted.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = working.clampedToExtent()
        blur.radius = Float(max(extent.width, extent.height) * scale * 0.03 * min(1, intensity))
        guard let blurred = blur.outputImage?.transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)).cropped(to: extent),
              let softenedBackground = normalizeBackground?.apply(extent: extent, arguments: [blurred, image]) else { return image }
        let blend = CIFilter.blendWithMask()
        blend.inputImage = image
        blend.backgroundImage = softenedBackground
        blend.maskImage = feather
        return (blend.outputImage ?? image).cropped(to: extent)
    }

    private static func faceMask(faces: [VNFaceObservation], width: Int, height: Int,
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
            guard intensity > 0 else { continue }
            let box = face.boundingBox
            let rect = CGRect(x: box.minX * CGFloat(width), y: box.minY * CGFloat(height),
                              width: box.width * CGFloat(width), height: box.height * CGFloat(height))
            context.setFillColor(gray: CGFloat(min(0.72, intensity * 0.72)), alpha: 1)
            if let contour = face.landmarks?.faceContour, contour.normalizedPoints.count > 2 {
                let points = contour.normalizedPoints.map { point in
                    CGPoint(x: (box.minX + CGFloat(point.x) * box.width) * CGFloat(width),
                            y: (box.minY + CGFloat(point.y) * box.height) * CGFloat(height))
                }
                let path = CGMutablePath()
                path.addLines(between: points)
                let foreheadInset = rect.height * 0.14
                path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - foreheadInset))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - foreheadInset))
                path.closeSubpath()
                context.addPath(path)
                context.fillPath()
            } else {
                context.fillEllipse(in: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.03))
            }
        }
        return context.makeImage()
    }
}
