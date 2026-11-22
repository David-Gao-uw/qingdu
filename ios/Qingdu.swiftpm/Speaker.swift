import AVFoundation

/// 普通话朗读。一次读一串内容，每读到一条就通知界面高亮。
@MainActor
@Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    /// 正在读的那一条的 id
    private(set) var speakingID: String?
    private(set) var isSpeaking = false
    @ObservationIgnored var onStart: ((String) -> Void)?

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var ids: [ObjectIdentifier: String] = [:]
    @ObservationIgnored private var lastUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// items：(id, 要读的文字)
    func speak(_ items: [(id: String, text: String)]) {
        stop()
        guard !items.isEmpty else { return }
        // 用「播放」类别：手机开着静音键也能读出声
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        let voice = AVSpeechSynthesisVoice(language: "zh-CN")
        for item in items {
            let utterance = AVSpeechUtterance(string: item.text)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85   // 比默认稍慢
            utterance.postUtteranceDelay = 0.25
            ids[ObjectIdentifier(utterance)] = item.id
            lastUtterance = utterance
            synthesizer.speak(utterance)
        }
        isSpeaking = true
    }

    func stop() {
        guard isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    private func finish() {
        ids.removeAll()
        lastUtterance = nil
        speakingID = nil
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard let id = self.ids[key] else { return }
            self.speakingID = id
            self.onStart?(id)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in
            if let last = self.lastUtterance, ObjectIdentifier(last) == key { self.finish() }
        }
    }
}
