import Foundation

public struct WindowKey: Hashable {
    public let pid: Int32
    public let id: UInt32
    public init(pid: Int32, id: UInt32) { self.pid = pid; self.id = id }
}

public struct WindowOrder {
    private var stamps: [WindowKey: UInt64] = [:]
    private var clock: UInt64 = 0
    public init() {}
    public mutating func touch(_ key: WindowKey) {
        clock += 1
        stamps[key] = clock
    }
    public mutating func prune(live: Set<WindowKey>) { stamps = stamps.filter { live.contains($0.key) } }
    public func sorted(_ keys: [WindowKey]) -> [WindowKey] {
        keys.enumerated().sorted {
            let a = stamps[$0.element, default: 0], b = stamps[$1.element, default: 0]
            return a == b ? $0.offset < $1.offset : a > b
        }.map(\.element)
    }
}

public struct Selection {
    public private(set) var index = 0
    public private(set) var count = 0
    public init() {}
    public mutating func reset(count: Int, selectPrevious: Bool) {
        self.count = max(0, count)
        index = selectPrevious && count > 1 ? 1 : 0
    }
    public mutating func move(_ delta: Int) {
        guard count > 0 else { return }
        index = ((index + delta) % count + count) % count
    }
    public mutating func select(_ index: Int) {
        guard (0..<count).contains(index) else { return }
        self.index = index
    }
}

public final class ByteCache<Key: Hashable, Value> {
    private var items: [Key: (value: Value, cost: Int, stamp: UInt64)] = [:]
    private var clock: UInt64 = 0
    public let limit: Int
    public private(set) var bytes = 0
    public var count: Int { items.count }
    public init(limit: Int) { self.limit = max(0, limit) }
    public func value(for key: Key) -> Value? {
        guard var item = items[key] else { return nil }
        clock += 1; item.stamp = clock; items[key] = item
        return item.value
    }
    @discardableResult public func insert(_ value: Value, for key: Key, cost: Int) -> Bool {
        if let old = items.removeValue(forKey: key) { bytes -= old.cost }
        guard cost >= 0, cost <= limit else { return false }
        while bytes > limit - cost, let oldest = items.min(by: { $0.value.stamp < $1.value.stamp })?.key {
            bytes -= items.removeValue(forKey: oldest)!.cost
        }
        clock += 1; items[key] = (value, cost, clock); bytes += cost
        return true
    }
    public func removeAll() { items.removeAll(keepingCapacity: false); bytes = 0 }
}

public enum ThumbnailSize {
    public static func fit(width: Double, height: Double, maxWidth: Int = 480, maxHeight: Int = 300) -> (Int, Int) {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return (1, 1) }
        let scale = min(1, Double(maxWidth) / width, Double(maxHeight) / height)
        return (max(1, Int(width * scale)), max(1, Int(height * scale)))
    }
}

// An invalidated session still occupies its slot until the OS callback returns.
public struct CaptureGate {
    public private(set) var generation: UInt64 = 0
    public private(set) var inFlight = false
    public init() {}
    public mutating func invalidate() { generation += 1 }
    public mutating func begin() -> UInt64? {
        guard !inFlight else { return nil }
        inFlight = true
        return generation
    }
    public mutating func complete(_ token: UInt64) -> Bool {
        guard inFlight else { return false }
        inFlight = false
        return token == generation
    }
}
