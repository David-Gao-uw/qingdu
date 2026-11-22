import SwiftUI
import VisionKit

/// 系统文档扫描器：自动找纸张边缘、拉正，可以一次扫多页
struct DocumentScanner: UIViewControllerRepresentable {
    /// 模拟器和部分设备没有扫描器
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    /// 扫描结束时调用；取消或失败时传空数组
    let completion: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: ([UIImage]) -> Void
        init(completion: @escaping ([UIImage]) -> Void) { self.completion = completion }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            completion((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completion([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            completion([])
        }
    }
}
