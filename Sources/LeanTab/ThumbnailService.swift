import AppKit
import ScreenCaptureKit
import LeanTabCore

final class ThumbnailService {
    let cache = ByteCache<WindowKey, CGImage>(limit: 12 * 1024 * 1024)
    private var gate = CaptureGate()
    private var pending: (() -> Void)?
    private var pressure: DispatchSourceMemoryPressure?
    private var requested = 0
    private var matched = 0
    private var captured = 0
    private var failed = 0
    private var lastError = "none"
    private var lastSize = "none"
    private var api = "none"
    private var phase = "idle"
    private var lastPreviewFootprint = "not measured"
    var onPressure: (() -> Void)?
    var diagnosticReport: String {
        "Capture phase: \(phase)\nLast page requested/matched/captured/failed: \(requested)/\(matched)/\(captured)/\(failed)\nCapture API: \(api)\nLast raw image: \(lastSize)\nLast preview footprint: \(lastPreviewFootprint)\nLast capture error: \(lastError)\n"
    }

    init() {
        pressure = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        pressure?.setEventHandler { [weak self] in self?.clear(); self?.onPressure?() }
        pressure?.resume()
    }

    func clear() { gate.invalidate(); cache.removeAll(); pending = nil; phase = "idle" }

    private func completed(_ token: UInt64) -> Bool {
        if gate.complete(token) { return true }
        let request = pending; pending = nil; request?()
        return false
    }

    // Invalidated OS requests keep their slot until the callback returns. Only the
    // latest page is queued, so fast paging or reopening cannot accumulate captures.
    func load(_ records: [WindowRecord], onImage: @escaping () -> Void, onStatus: @escaping (String) -> Void) {
        clear()
        guard !records.isEmpty else { return }
        guard CGPreflightScreenCaptureAccess() else {
            lastError = "Screen Recording permission unavailable"
            onStatus(L.text("미리보기에는 화면 기록 권한이 필요합니다", "Screen Recording permission is needed for thumbnails")); return
        }
        guard !gate.inFlight else {
            pending = { [weak self] in self?.load(records, onImage: onImage, onStatus: onStatus) }
            phase = "waiting for previous capture"
            onStatus(L.text("미리보기를 준비하는 중…", "Preparing previews…")); return
        }
        guard let token = gate.begin() else { return }
        requested = records.count; matched = 0; captured = 0; failed = 0
        lastError = "none"; lastSize = "none"; phase = "enumerating"
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { [weak self] content, error in
            DispatchQueue.main.async {
                guard let self, self.completed(token) else { return }
                guard let content, error == nil else {
                    self.phase = "enumeration failed"
                    self.lastError = Self.describe(error)
                    onStatus(L.text("창 캡처 정보 오류 · 메뉴에서 진단을 복사해 주세요", "Window enumeration failed · copy diagnostics from the menu")); return
                }
                let ids = Set(records.map { $0.key.id })
                let windows = content.windows.filter { ids.contains($0.windowID) }
                self.matched = windows.count
                if windows.isEmpty {
                    self.phase = "no matching windows"
                    self.lastError = "AX window IDs did not match ScreenCaptureKit windows"
                    onStatus(L.text("미리보기 창을 찾지 못했습니다 · 메뉴에서 진단을 복사해 주세요", "No matching preview windows · copy diagnostics from the menu")); return
                }
                onStatus("")
                self.next(records[...], windows: windows, token: token, onImage: onImage, onStatus: onStatus)
            }
        }
    }

    private func next(_ records: ArraySlice<WindowRecord>, windows: [SCWindow], token: UInt64,
                      onImage: @escaping () -> Void, onStatus: @escaping (String) -> Void) {
        guard token == gate.generation else { return }
        guard let record = records.first else {
            phase = "complete"
            if failed > 0 {
                onStatus(L.text("일부 미리보기를 가져오지 못했습니다 · 메뉴에서 진단 복사", "Some previews failed · copy diagnostics from the menu"))
            }
            return
        }
        guard let window = windows.first(where: { $0.windowID == record.key.id }) else {
            next(records.dropFirst(), windows: windows, token: token, onImage: onImage, onStatus: onStatus); return
        }
        guard gate.begin() != nil else { return }
        phase = "capturing"
        capture(window) { [weak self] image, error, api in
            let rawSize = image.map { "\($0.width)x\($0.height)" } ?? "none"
            let copy = autoreleasepool { image.flatMap { ThumbnailBitmap.make(from: $0) } }
            DispatchQueue.main.async {
                guard let self, self.completed(token) else { return }
                self.api = api; self.lastSize = rawSize
                if let copy, self.cache.insert(copy, for: record.key, cost: copy.bytesPerRow * copy.height) {
                    self.captured += 1; onImage()
                    self.lastPreviewFootprint = MemoryDiagnostics.footprint()
                } else {
                    self.failed += 1
                    self.lastError = error.map { Self.describe($0) } ?? "Capture returned no usable bitmap (raw: \(rawSize))"
                }
                self.next(records.dropFirst(), windows: windows, token: token, onImage: onImage, onStatus: onStatus)
            }
        }
    }

    private func capture(_ window: SCWindow, completion: @escaping (CGImage?, Error?, String) -> Void) {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let (width, height) = ThumbnailSize.fit(width: window.frame.width, height: window.frame.height)
        if #available(macOS 26.0, *) {
            let config = SCScreenshotConfiguration()
            config.width = width; config.height = height
            config.showsCursor = false; config.ignoreShadows = true
            config.dynamicRange = .sdr
            SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: config) { image, error in
                if let image = image?.sdrImage { completion(image, nil, "SCScreenshotConfiguration") }
                else {
                    Self.captureLegacy(filter, width: width, height: height) { image, fallbackError in
                        completion(image, fallbackError ?? error, "SCStreamConfiguration fallback")
                    }
                }
            }
        } else {
            Self.captureLegacy(filter, width: width, height: height) { image, error in
                completion(image, error, "SCStreamConfiguration")
            }
        }
    }

    private static func captureLegacy(_ filter: SCContentFilter, width: Int, height: Int,
                                      completion: @escaping (CGImage?, Error?) -> Void) {
        let config = SCStreamConfiguration()
        config.width = width; config.height = height
        config.showsCursor = false; config.scalesToFit = true
        config.ignoreShadowsSingleWindow = true
        SCScreenshotManager.captureImage(contentFilter: filter, configuration: config, completionHandler: completion)
    }

    private static func describe(_ error: Error?) -> String {
        guard let error = error as NSError? else { return "No image and no OS error" }
        return "\(error.domain) (\(error.code)): \(error.localizedDescription)"
    }
}
