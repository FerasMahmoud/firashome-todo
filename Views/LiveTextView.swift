import SwiftUI
import VisionKit
import AVFoundation

/// Camera-based Live Text capture for the QuickAdd sheet.
///
/// Wraps `DataScannerViewController` (VisionKit, iOS 16+) and surfaces a
/// single recognized string — the most-recently-stabilized text in the
/// viewfinder — via a SwiftUI `@Binding`. The user aligns the camera at a
/// task written somewhere (paper, a whiteboard, another screen) and taps
/// **Use** to drop the recognized text into the quick-add field.
///
/// UX flow:
///   1. View appears → scanner starts automatically.
///   2. A small overlay shows the current recognized text live so the user
///      can confirm the camera is locked on.
///   3. **Use** dismisses with the recognized string; **Cancel** dismisses
///      with the binding untouched.
///
/// Permissions (Info.plist — required, the app hard-crashes otherwise):
///   - `NSCameraUsageDescription`  → e.g. "Used to scan text from paper or
///     another screen into the quick-add field."
///
/// Availability: `DataScannerViewController.isSupported` and
/// `isAvailable` are checked before presenting. On unsupported hardware
/// (Simulator, A12 and older) the view shows an inline message instead of
/// the scanner, so the QuickAdd flow never gets stuck on a blank camera.
struct LiveTextView: View {

    /// Bound to the caller's title text. Updated on **Use**; left alone on
    /// **Cancel** so the user can re-scan without losing what they had.
    @Binding var scannedText: String

    @Environment(\.dismiss) private var dismiss
    @State private var liveText: String = ""
    @State private var availability: Availability = .checking

    private enum Availability: Equatable {
        case checking
        case ready
        case unsupported(reason: String)
        case denied
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TK.canvas.ignoresSafeArea()

                switch availability {
                case .checking:
                    checkingLayer
                case .ready:
                    scannerLayer
                case .unsupported(let reason):
                    unavailableLayer(reason: reason)
                case .denied:
                    deniedLayer
                }
            }
            .navigationTitle("Scan text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(TK.secondary)
                        .accessibilityIdentifier("live-text-cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        scannedText = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    } label: {
                        Text("Use")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(canUse ? TK.accent : TK.secondary)
                    }
                    .disabled(!canUse)
                    .accessibilityIdentifier("live-text-use")
                }
            }
        }
        .task { evaluateAvailability() }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Layers

    /// Brief loading state shown while we probe camera permission + scanner
    /// availability. Keeps the camera viewfinder from flashing before we've
    /// confirmed it's actually allowed to run.
    private var checkingLayer: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
                .tint(TK.ink)
            Text("Preparing camera…")
                .font(TK.body)
                .foregroundStyle(TK.secondary)
        }
        .padding(24)
    }

    /// Camera + overlay. Scanner fills the screen; a compact pill at the
    /// bottom shows the live recognized text so the user gets feedback
    /// without taking their eyes off the viewfinder.
    private var scannerLayer: some View {
        ZStack {
            DataScannerRepresentable(text: $liveText)
                .ignoresSafeArea()

            VStack {
                Spacer()
                liveTextPill
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var liveTextPill: some View {
        let trimmed = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TK.ink)
                Text(trimmed)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TK.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(TK.card.opacity(0.94), in: RoundedRectangle(cornerRadius: TK.rRow, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TK.rRow, style: .continuous)
                    .stroke(TK.hairline, lineWidth: 0.5)
            )
            .animation(.easeInOut(duration: 0.18), value: trimmed)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TK.secondary)
                Text("Point at text to capture")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TK.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(TK.card.opacity(0.94), in: RoundedRectangle(cornerRadius: TK.rRow, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TK.rRow, style: .continuous)
                    .stroke(TK.hairline, lineWidth: 0.5)
            )
        }
    }

    private func unavailableLayer(reason: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(TK.secondary)
            Text("Live Text unavailable")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text(reason)
                .font(TK.body)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(TK.accent)
                .padding(.top, 8)
        }
        .padding(24)
    }

    private var deniedLayer: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(TK.secondary)
            Text("Camera access needed")
                .font(TK.headline)
                .foregroundStyle(TK.ink)
            Text("Enable Camera access in Settings to scan text into the quick-add field.")
                .font(TK.body)
                .foregroundStyle(TK.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(TK.accent)
                .padding(.top, 8)
        }
        .padding(24)
    }

    // MARK: - Availability

    private var canUse: Bool {
        !liveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func evaluateAvailability() {
        // Camera permission first — DataScannerViewController will refuse to
        // start without it, and the user-visible "denied" state is friendlier
        // than a silent black viewfinder.
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch camStatus {
        case .denied, .restricted:
            availability = .denied
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    availability = granted ? Self.checkScannerSupport() : .denied
                }
            }
            return
        case .authorized:
            availability = Self.checkScannerSupport()
        @unknown default:
            availability = .denied
        }
    }

    private static func checkScannerSupport() -> Availability {
        guard DataScannerViewController.isSupported else {
            return .unsupported(reason: "This device doesn't support Live Text capture.")
        }
        guard DataScannerViewController.isAvailable else {
            return .unsupported(reason: "Live Text is temporarily unavailable. Try again in a moment.")
        }
        return .ready
    }
}

// MARK: - DataScannerViewController bridge

/// `UIViewControllerRepresentable` over VisionKit's `DataScannerViewController`.
/// Streams the most recent stabilized text up to `text` so the SwiftUI
/// overlay can show it live. The scanner runs in `.text` mode with no
/// highlight — the user just needs the recognized string, not bounding boxes.
private struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var text: String

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // No external state to push in. Future: zoom / torch controls.
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didTapOn item: RecognizedItem) {
            // Treat a manual tap as "lock this in" — pull that item's text
            // out so the SwiftUI layer updates immediately.
            switch item {
            case .text(let textItem):
                text.wrappedValue = textItem.transcript
            default:
                break
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            update(from: allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            update(from: allItems)
        }

        /// Keep the binding in sync with the freshest text in view. Vision
        /// Kit already sorts by stability, so the last item is the best
        /// candidate to surface.
        private func update(from items: [RecognizedItem]) {
            let texts = items.compactMap { item -> String? in
                if case .text(let t) = item { return t.transcript }
                return nil
            }
            // Join with spaces so multi-region scans (e.g. a header + a body
            // line) read coherently. Trim to keep whitespace tidy.
            let combined = texts.joined(separator: " ")
            let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != text.wrappedValue {
                text.wrappedValue = trimmed
            }
        }
    }
}