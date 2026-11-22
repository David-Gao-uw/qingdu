import UIKit
import Vision

/// 用 Vision 识别图片里的中文，再交给 ParagraphBuilder 拼回段落
enum TextRecognizer {
    /// 识别多张图片，按页顺序返回段落
    static func paragraphs(from images: [UIImage]) async throws -> [String] {
        var result: [String] = []
        for image in images {
            result += ParagraphBuilder.paragraphs(from: try await recognizeLines(in: image))
        }
        return result
    }

    static func recognizeLines(in image: UIImage) async throws -> [ParagraphBuilder.Line] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            try recognizeLines(in: cgImage, orientation: orientation)
        }.value
    }

    static func recognizeLines(in cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> [ParagraphBuilder.Line] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])

        // 识别结果是归一化坐标（原点在左下）；按图片朝向换算成像素，原点在左上
        let rotated = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
        let width = CGFloat(rotated ? cgImage.height : cgImage.width)
        let height = CGFloat(rotated ? cgImage.width : cgImage.height)
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let b = observation.boundingBox
            return ParagraphBuilder.Line(text: text, box: CGRect(x: b.minX * width, y: (1 - b.maxY) * height,
                                                                 width: b.width * width, height: b.height * height))
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
