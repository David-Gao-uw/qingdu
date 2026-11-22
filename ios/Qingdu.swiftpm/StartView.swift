import SwiftUI
import PhotosUI

/// 开始页：扫描、从相册选、看示例
struct StartView: View {
    let open: (ReaderSource) -> Void

    @State private var showScanner = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var loadingPhotos = false
    @State private var showAbout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("拍下医院给的须知，帮你看清、读懂、照做。")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button { showScanner = true } label: {
                        ActionRow(icon: "doc.viewfinder", title: "扫描纸质须知", subtitle: "用相机拍下，自动识别文字", prominent: true)
                    }
                    .disabled(!DocumentScanner.isSupported)

                    PhotosPicker(selection: $photoItems, maxSelectionCount: 5, matching: .images) {
                        ActionRow(icon: "photo.on.rectangle", title: "从相册选择", subtitle: "微信里的图片请先保存到相册",
                                  loading: loadingPhotos)
                    }
                    .disabled(loadingPhotos)

                    Button { open(.sample) } label: {
                        ActionRow(icon: "doc.text", title: "看一份示例", subtitle: "结肠镜检查前须知")
                    }
                }
                .buttonStyle(.plain)

                if !DocumentScanner.isSupported {
                    Label("这台设备不能用相机扫描（例如模拟器），请从相册选择或看示例。", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("清读")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAbout = true } label: { Image(systemName: "info.circle") }
                    .accessibilityLabel("关于清读")
            }
        }
        .sheet(isPresented: $showAbout) { AboutView() }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { images in
                showScanner = false
                if !images.isEmpty { open(.scan(ScanBatch(images: images))) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadPhotos(items) }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        loadingPhotos = true
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        loadingPhotos = false
        photoItems = []
        if !images.isEmpty { open(.scan(ScanBatch(images: images))) }
    }
}

/// 开始页上的一行大按钮
private struct ActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var prominent = false
    var loading = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .frame(width: 52, height: 52)
                .foregroundStyle(prominent ? Color.white : Color.accentColor)
                .background(prominent ? Color.accentColor : Color.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if loading {
                ProgressView()
            } else {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }
}
