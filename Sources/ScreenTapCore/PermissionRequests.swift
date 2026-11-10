// SPDX-License-Identifier: MIT
// Copyright (c) 2026 peses0326

public enum PermissionKind: Hashable { case accessibility, screenRecording }

// A confirmed request must reach the OS before a Settings-only follow-up is offered.
// Denial has no side effects; repeated clicks never create another native prompt.
public final class PermissionRequests {
    private var requested: Set<PermissionKind> = []
    private let requestSystem: (PermissionKind) -> Void
    private let openSettings: (PermissionKind) -> Void
    public init(requestSystem: @escaping (PermissionKind) -> Void, openSettings: @escaping (PermissionKind) -> Void) {
        self.requestSystem = requestSystem; self.openSettings = openSettings
    }
    public func hasRequested(_ kind: PermissionKind) -> Bool { requested.contains(kind) }
    public func respond(to kind: PermissionKind, allowed: Bool) {
        guard allowed else { return }
        if requested.insert(kind).inserted { requestSystem(kind) }
        else { openSettings(kind) }
    }
}
