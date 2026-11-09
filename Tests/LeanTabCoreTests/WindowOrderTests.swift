import Foundation
import CoreGraphics
import LeanTabCore

final class WindowOrderTests {
    func testIndividualWindowsOfSameAppHaveIndependentRecency() {
        let browserA = WindowKey(pid: 10, id: 1), browserB = WindowKey(pid: 10, id: 2)
        let terminal = WindowKey(pid: 20, id: 3)
        var order = WindowOrder()
        order.touch(browserA); order.touch(terminal); order.touch(browserB)
        checkEqual(order.sorted([browserA, browserB, terminal]), [browserB, terminal, browserA])
        order.touch(browserA)
        checkEqual(order.sorted([browserA, browserB, terminal]), [browserA, browserB, terminal])
    }
    func testUnseenWindowsRetainInitialZOrderAndClosedWindowsArePruned() {
        let a = WindowKey(pid: 1, id: 1), b = WindowKey(pid: 2, id: 2), c = WindowKey(pid: 3, id: 3)
        var order = WindowOrder(); order.touch(c); order.prune(live: [a, b])
        checkEqual(order.sorted([b, a, c]), [b, a, c])
    }
    func testPIDPreventsReusedWindowIDFromInheritingRecency() {
        let old = WindowKey(pid: 1, id: 8), new = WindowKey(pid: 2, id: 8), other = WindowKey(pid: 3, id: 9)
        var order = WindowOrder(); order.touch(old)
        checkEqual(order.sorted([other, new]), [other, new])
    }
    func testQuickForwardReverseAndEmptySelection() {
        var selection = Selection()
        selection.reset(count: 3, selectPrevious: true); checkEqual(selection.index, 1)
        selection.move(-2); checkEqual(selection.index, 2)
        selection.move(7); checkEqual(selection.index, 0)
        selection.select(99); checkEqual(selection.index, 0)
        selection.reset(count: 0, selectPrevious: true); selection.move(-1)
        checkEqual(selection.index, 0)
    }
}

final class MemoryBudgetTests {
    func testStrictBudgetWithLRUEviction() {
        let cache = ByteCache<Int, String>(limit: 10)
        checkTrue(cache.insert("a", for: 1, cost: 4)); checkTrue(cache.insert("b", for: 2, cost: 4))
        checkEqual(cache.value(for: 1), "a")
        checkTrue(cache.insert("c", for: 3, cost: 4))
        checkNil(cache.value(for: 2)); checkEqual(cache.value(for: 1), "a")
        checkEqual(cache.bytes, 8)
        checkFalse(cache.insert("oversized", for: 4, cost: 11)); checkEqual(cache.bytes, 8)
        cache.removeAll(); checkEqual(cache.bytes, 0); checkEqual(cache.count, 0)
    }
    func testReplacementAndNegativeCostsCannotBreakAccounting() {
        let cache = ByteCache<Int, Int>(limit: 10)
        cache.insert(1, for: 1, cost: 9); cache.insert(2, for: 1, cost: 3)
        checkEqual(cache.bytes, 3)
        checkFalse(cache.insert(3, for: 1, cost: -1)); checkEqual(cache.bytes, 0)
    }
    func testMany4KWindowsNeverExceedBudget() {
        let cache = ByteCache<Int, Int>(limit: 12 * 1024 * 1024)
        let (w, h) = ThumbnailSize.fit(width: 3840, height: 2160)
        checkLessOrEqual(w, 480); checkLessOrEqual(h, 300)
        for id in 0..<1000 {
            cache.insert(id, for: id, cost: w * h * 4)
            checkLessOrEqual(cache.bytes, cache.limit)
        }
        checkLess(cache.count, 30)
    }
    func testPortraitTinyAndInvalidSizes() {
        let (w, h) = ThumbnailSize.fit(width: 1000, height: 4000)
        checkEqual(w, 75); checkEqual(h, 300)
        let (smallW, smallH) = ThumbnailSize.fit(width: 10, height: 10)
        checkEqual(smallW, 10); checkEqual(smallH, 10)
        let (badW, badH) = ThumbnailSize.fit(width: .infinity, height: 0)
        checkEqual(badW, 1); checkEqual(badH, 1)
    }
    func testClearReleasesCachedReferences() {
        final class Image {}
        let cache = ByteCache<Int, Image>(limit: 100)
        weak var reference: Image?
        do { let image = Image(); reference = image; cache.insert(image, for: 1, cost: 20) }
        checkNotNil(reference)
        cache.removeAll(); checkNil(reference)
    }
}

final class CaptureGateTests {
    func testDismissAndReopenNeverStartsASecondCapture() {
        var gate = CaptureGate()
        let old = gate.begin()!
        gate.invalidate()
        checkNil(gate.begin())
        checkFalse(gate.complete(old))
        let current = gate.begin()!
        checkTrue(gate.complete(current))
    }
    func testManyPageChangesRejectStaleResultAndKeepOneSlot() {
        var gate = CaptureGate()
        let token = gate.begin()!
        for _ in 0..<1000 { gate.invalidate(); checkNil(gate.begin()) }
        checkFalse(gate.complete(token))
        checkFalse(gate.inFlight)
        let latest = gate.begin()!
        checkEqual(latest, 1000)
        checkTrue(gate.complete(latest))
    }
    func testDuplicateCompletionCannotProduceAnImage() {
        var gate = CaptureGate()
        let token = gate.begin()!
        checkTrue(gate.complete(token))
        checkFalse(gate.complete(token))
    }
}

final class PreviewRegressionTests {
    func testOversizedCaptureIsDownsampledInsteadOfDiscarded() {
        guard let context = CGContext(data: nil, width: 1920, height: 1080, bitsPerComponent: 8,
            bytesPerRow: 1920 * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { checkTrue(false); return }
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1920, height: 1080))
        guard let raw = context.makeImage(), let thumbnail = ThumbnailBitmap.make(from: raw) else { checkTrue(false); return }
        checkEqual(thumbnail.width, 480); checkEqual(thumbnail.height, 270)
        checkLessOrEqual(thumbnail.bytesPerRow * thumbnail.height, 480 * 300 * 4)
        guard let data = thumbnail.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { checkTrue(false); return }
        checkTrue(bytes[0] > 240); checkTrue(bytes[0] > bytes[1]); checkTrue(bytes[0] > bytes[2]); checkEqual(bytes[3], 255)
    }
    func testPortraitCaptureStaysInsideBudget() {
        guard let context = CGContext(data: nil, width: 1000, height: 4000, bitsPerComponent: 8,
            bytesPerRow: 4000, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let raw = context.makeImage(), let thumbnail = ThumbnailBitmap.make(from: raw) else { checkTrue(false); return }
        checkEqual(thumbnail.width, 75); checkEqual(thumbnail.height, 300)
    }
    func testBlankMarginsGuttersAndUnusedCellsCancel() {
        for point in [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 40), CGPoint(x: 265, y: 80),
                      CGPoint(x: 40, y: 640), CGPoint(x: 700, y: 300), CGPoint(x: -5, y: 80)] {
            checkEqual(SwitcherHitTest.click(at: point, width: 1040, columns: 4, count: 5, offset: 0), .cancel)
        }
    }
    func testClickSelectsExactTileOnLaterPage() {
        checkEqual(SwitcherHitTest.click(at: CGPoint(x: 30, y: 80), width: 1040, columns: 4, count: 5, offset: 12), .select(12))
        checkEqual(SwitcherHitTest.click(at: CGPoint(x: 30, y: 270), width: 1040, columns: 4, count: 5, offset: 12), .select(16))
        checkEqual(SwitcherHitTest.click(at: CGPoint(x: 30, y: 80), width: 1040, columns: 4, count: 0, offset: 0), .cancel)
    }
}

// Standalone checks run with Command Line Tools; XCTest requires a full Xcode install.
var failures = 0
func checkTrue(_ condition: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !condition { print("FAIL \(file):\(line)"); failures += 1 }
}
func checkFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { checkTrue(!value, file: file, line: line) }
func checkEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { checkTrue(a == b, file: file, line: line) }
func checkLessOrEqual<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { checkTrue(a <= b, file: file, line: line) }
func checkLess<T: Comparable>(_ a: T, _ b: T, file: StaticString = #filePath, line: UInt = #line) { checkTrue(a < b, file: file, line: line) }
func checkNil<T>(_ a: T?, file: StaticString = #filePath, line: UInt = #line) { checkTrue(a == nil, file: file, line: line) }
func checkNotNil<T>(_ a: T?, file: StaticString = #filePath, line: UInt = #line) { checkTrue(a != nil, file: file, line: line) }

@main enum CoreChecks {
    static func main() {
        let order = WindowOrderTests(), memory = MemoryBudgetTests(), capture = CaptureGateTests(), preview = PreviewRegressionTests()
        let tests: [(String, () -> Void)] = [
            ("oversized screenshot produces visible bounded pixels", preview.testOversizedCaptureIsDownsampledInsteadOfDiscarded),
            ("portrait screenshot normalization", preview.testPortraitCaptureStaysInsideBudget),
            ("blank margins / gutters / empty cells cancel", preview.testBlankMarginsGuttersAndUnusedCellsCancel),
            ("exact tile clicks on later pages", preview.testClickSelectsExactTileOnLaterPage),
            ("capture dismissal / reopening", capture.testDismissAndReopenNeverStartsASecondCapture),
            ("1000 rapid page changes", capture.testManyPageChangesRejectStaleResultAndKeepOneSlot),
            ("duplicate capture completion", capture.testDuplicateCompletionCannotProduceAnImage),
            ("individual window MRU", order.testIndividualWindowsOfSameAppHaveIndependentRecency),
            ("stable fallback and pruning", order.testUnseenWindowsRetainInitialZOrderAndClosedWindowsArePruned),
            ("PID identity", order.testPIDPreventsReusedWindowIDFromInheritingRecency),
            ("forward / reverse / empty selection", order.testQuickForwardReverseAndEmptySelection),
            ("strict byte budget and LRU", memory.testStrictBudgetWithLRUEviction),
            ("replacement cost accounting", memory.testReplacementAndNegativeCostsCannotBreakAccounting),
            ("1000 4K window stress", memory.testMany4KWindowsNeverExceedBudget),
            ("portrait and invalid size", memory.testPortraitTinyAndInvalidSizes),
            ("clear releases image references", memory.testClearReleasesCachedReferences)
        ]
        for (name, test) in tests {
            let before = failures; test(); print("\(before == failures ? "PASS" : "FAIL") \(name)")
        }
        print("\(tests.count) checks, \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
