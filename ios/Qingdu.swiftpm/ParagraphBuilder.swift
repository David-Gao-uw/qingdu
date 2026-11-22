import CoreGraphics
import Foundation

/// 把文字识别得到的一行行文字拼回段落。
/// 只依赖 CoreGraphics，方便在 Mac 上单独测试。
enum ParagraphBuilder {
    /// 一行识别结果，坐标是像素，原点在左上角
    struct Line {
        var text: String
        var box: CGRect
    }

    /// 遇到空行、首行缩进、上一行没写满、小标题时另起一段
    static func paragraphs(from lines: [Line]) -> [String] {
        let rows = mergeIntoRows(lines)
        guard !rows.isEmpty else { return [] }

        let lineHeight = percentile(rows.map(\.box.height), 0.5)
        let left = percentile(rows.map(\.box.minX), 0.1)
        let right = percentile(rows.map(\.box.maxX), 0.9)

        var paragraphs: [String] = []
        var current = ""
        var previous: Line?
        for row in rows {
            let text = row.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            if let prev = previous, !current.isEmpty {
                let gap = row.box.minY - prev.box.maxY
                let shortBy = right - prev.box.maxX
                let startsNew = gap > lineHeight * 0.9
                    || row.box.minX > left + lineHeight * 1.2       // 首行缩进
                    || shortBy > lineHeight * 6                     // 上一行明显没写满（标题、落款）
                    || (shortBy > lineHeight * 1.5 && endsSentence(prev.text)) // 上一行以句号结尾且没写满
                    || isHeading(text) || isHeading(prev.text)
                if startsNew {
                    paragraphs.append(current)
                    current = ""
                }
            }
            current = join(current, text)
            previous = row
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs
    }

    /// 同一高度的几块文字合成一行（从左到右）
    private static func mergeIntoRows(_ lines: [Line]) -> [Line] {
        var rows: [Line] = []
        for line in lines.sorted(by: { $0.box.midY < $1.box.midY }) {
            if let last = rows.last, abs(last.box.midY - line.box.midY) < min(last.box.height, line.box.height) * 0.5 {
                let (first, second) = last.box.minX <= line.box.minX ? (last, line) : (line, last)
                rows[rows.count - 1] = Line(text: join(first.text, second.text), box: last.box.union(line.box))
            } else {
                rows.append(line)
            }
        }
        return rows
    }

    /// 中文直接相连；英文单词之间留一个空格
    private static func join(_ a: String, _ b: String) -> String {
        guard let x = a.last, let y = b.first else { return a + b }
        return x.isASCII && x.isLetter && y.isASCII && y.isLetter ? a + " " + b : a + b
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return "。！？；：.!?;:".contains(last)
    }

    private static func isHeading(_ text: String) -> Bool {
        text.count <= 20 && text.range(of: #"^([一二三四五六七八九十]+[、.．]|（[一二三四五六七八九十]+）|\(?\d{1,2}[)）、.．])"#,
                                       options: .regularExpression) != nil
    }

    private static func percentile(_ values: [CGFloat], _ p: Double) -> CGFloat {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * p))]
    }
}
