import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Vision

/// Local portrait effects for still photos. Failed or empty Vision masks leave
/// the input image untouched so an effect never damages an export.
enum PortraitEffects {
    static func applyLighting(to image: CIImage, source: CGImage, allIntensity: Double,
                              faceIntensities: [Int: Double]) -> CIImage {
        guard allIntensity > 0 || faceIntensities.values.contains(where: { $0 > 0 }) else { return image }
        let request = VNDetectFaceLandmarksRequest()
        do {
            try VNImageRequestHandler(cgImage: source, orientation: .up).perform([request])
        } catch {
            return image
        }
        let faces = (request.results ?? []).sorted { $0.boundingBox.midX < $1.boundingBox.midX }
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

    static func applyBackgroundBlur(to image: CIImage, source: CGImage, intensity: Double) -> CIImage {
        guard intensity > 0 else { return image }
        let request = VNGeneratePersonInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: source, orientation: .up)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return image }
            let pixelBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances, from: handler)
            let extent = image.extent
            let rawMask = CIImage(cvPixelBuffer: pixelBuffer)
            guard rawMask.extent.width > 0, rawMask.extent.height > 0 else { return image }
            let scaledMask = rawMask.transformed(by: CGAffineTransform(
                scaleX: extent.width / rawMask.extent.width,
                y: extent.height / rawMask.extent.height
            )).cropped(to: extent)
            let feather = scaledMask
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(1, min(extent.width, extent.height) * 0.007)])
                .cropped(to: extent)
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = image.clampedToExtent()
            blur.radius = Float(max(1, min(48, max(extent.width, extent.height) * 0.03 * intensity)))
            guard let softenedBackground = blur.outputImage?.cropped(to: extent) else { return image }
            let blend = CIFilter.blendWithMask()
            blend.inputImage = image
            blend.backgroundImage = softenedBackground
            blend.maskImage = feather
            return (blend.outputImage ?? image).cropped(to: extent)
        } catch {
            return image
        }
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
