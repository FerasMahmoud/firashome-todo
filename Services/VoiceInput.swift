import Foundation
import Speech
import AVFoundation
import Combine

/// Live speech-to-text wrapper around `SFSpeechRecognizer` + `AVAudioEngine`.
///
/// Designed for the QuickAdd bottom sheet: the user taps the mic button,
/// `start()` opens the mic + recognition, and partial results stream into
/// `transcript` (a `@Published` string). Each partial replaces the current
/// value rather than appending — the caller decides how to merge it into the
/// existing title text (QuickAdd appends a trailing space + new transcript).
///
/// Concurrency model:
///   - Public API is `@MainActor`. Speech callbacks come in on the recognizer's
///     internal queue and are hopped to the main actor before publishing.
///   - `start()` is `async throws`; callers `await` it and decide how to
///     surface errors (QuickAdd silently no-ops and keeps the existing text).
///   - `stop()` is sync — it tears down audio + the recognition task. Safe to
///     call when nothing is running.
///
/// Permissions (Info.plist — required, the app hard-crashes otherwise):
///   - `NSSpeechRecognitionUsageDescription`  → e.g. "Used to transcribe
///     spoken tasks into the quick-add field."
///   - `NSMicrophoneUsageDescription`         → e.g. "Used to capture your
///     voice when adding tasks by speech."
///
/// On-device: when `SFSpeechRecognizer.supportsOnDeviceRecognition` returns
/// `true` AND the recognizer is available, `request.requiresOnDeviceRecognition`
/// is flipped on. That keeps audio off the network, which is the right
/// default for a private todo app and also makes the feature work in
/// Airplane Mode / poor signal.
@MainActor
final class VoiceInput: ObservableObject {

    // MARK: - Published state

    /// Latest partial transcript. Replaced (not appended) on every
    /// `recognitionTask` callback. Empty when not listening.
    @Published private(set) var transcript: String = ""

    /// True between a successful `start()` and the next `stop()` / error.
    @Published private(set) var isListening: Bool = false

    /// Last spoken-word rate-of-change sample (used by QuickAdd to decide
    /// whether to auto-scroll the live preview). 0 when idle.
    @Published private(set) var lastUpdatedAt: Date = .distantPast

    // MARK: - Configuration

    /// Locale for recognition. English by default — matches the rest of the
    /// app's NL parser vocabulary. A future settings row could expose this.
    private let locale: Locale

    // MARK: - Internals

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // MARK: - Init

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Public API

    /// Begin live transcription. Requests Speech + Microphone authorization
    /// if not yet decided; throws `VoiceInputError` for any failure so the
    /// caller can surface a toast / keep the existing title untouched.
    ///
    /// Idempotent: calling `start()` while already listening is a no-op.
    func start() async throws {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceInputError.recognizerUnavailable
        }

        try await requestSpeechAuthorization()
        try await requestMicrophoneAuthorization()

        // Tear down any previous run before reconfiguring — AVAudioEngine
        // asserts if `start()` is called twice without an intervening stop.
        teardown()

        let request = SFSpeechAudioBufferRecognitionRequest()
        // On-device when supported: keeps audio local + works offline.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        // Guard against zero-channel formats (Sim / some accessories) — they
        // would crash the engine the moment we attach the tap.
        guard format.channelCount > 0 else {
            throw VoiceInputError.audioFormatInvalid
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        // Audio session for recording. `.measurement` keeps the system from
        // applying AGC / noise-suppression that would mangle recognition.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        audioEngine.prepare()
        try audioEngine.start()

        transcript = ""
        isListening = true
        lastUpdatedAt = .now

        // Wire the recognition task. Callbacks fire on an internal queue —
        // hop to the main actor before mutating @Published state.
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.lastUpdatedAt = .now
                    if result.isFinal {
                        self.stop()
                    }
                }
                if let error {
                    // Common benign case: user ended the session, which
                    // surfaces as a cancelled error. Stop cleanly.
                    let nsErr = error as NSError
                    if nsErr.domain == "kAFAssistantErrorDomain", nsErr.code == 203 {
                        self.stop()
                        return
                    }
                    self.stop()
                }
            }
        }
    }

    /// End the current session. Safe to call when nothing is running.
    func stop() {
        guard isListening || task != nil || audioEngine.isRunning else {
            teardown()
            isListening = false
            return
        }
        teardown()
        isListening = false
    }

    /// Clear the buffered transcript. Call after the host view has merged
    /// the recognized text into its own state.
    func reset() {
        transcript = ""
        lastUpdatedAt = .distantPast
    }

    // MARK: - Teardown

    private func teardown() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        // Deactivate the audio session so playback (e.g. a reminder tone)
        // can resume on its own category.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Authorization helpers

    private func requestSpeechAuthorization() async throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return
        case .denied:
            throw VoiceInputError.speechDenied
        case .restricted:
            throw VoiceInputError.speechRestricted
        case .notDetermined:
            let granted: Bool = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
            }
            if !granted { throw VoiceInputError.speechDenied }
        @unknown default:
            throw VoiceInputError.speechDenied
        }
    }

    private func requestMicrophoneAuthorization() async throws {
        // iOS 17+ exposes the typed Swift API; older OSes still expose the
        // raw AVAudioSession.requestRecordPermission path.
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return
            case .denied:  throw VoiceInputError.microphoneDenied
            case .undetermined:
                let granted: Bool = await withCheckedContinuation { cont in
                    AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
                }
                if !granted { throw VoiceInputError.microphoneDenied }
            @unknown default:
                throw VoiceInputError.microphoneDenied
            }
        } else {
            let session = AVAudioSession.sharedInstance()
            switch session.recordPermission {
            case .granted: return
            case .denied:  throw VoiceInputError.microphoneDenied
            case .undetermined:
                let granted: Bool = await withCheckedContinuation { cont in
                    session.requestRecordPermission { cont.resume(returning: $0) }
                }
                if !granted { throw VoiceInputError.microphoneDenied }
            @unknown default:
                throw VoiceInputError.microphoneDenied
            }
        }
    }
}

// MARK: - Errors

/// User-presentable failure modes for `VoiceInput.start()`. Mapped from
/// the underlying Speech / AVFoundation errors so call-sites get clean
/// switch coverage without importing those layers.
enum VoiceInputError: LocalizedError {
    case recognizerUnavailable
    case audioFormatInvalid
    case speechDenied
    case speechRestricted
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: return "Speech recognition isn't available right now."
        case .audioFormatInvalid:    return "Couldn't access the microphone."
        case .speechDenied:          return "Enable Speech Recognition in Settings to add tasks by voice."
        case .speechRestricted:      return "Speech Recognition is restricted on this device."
        case .microphoneDenied:      return "Enable Microphone access in Settings to add tasks by voice."
        }
    }
}