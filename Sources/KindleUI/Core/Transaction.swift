import Foundation

// MARK: - 11. .redacted(reason:), .unredacted(), Transaction & withTransaction

/// The context for the current state-update transaction on E-Ink.
public struct Transaction: Sendable, Equatable {
    public var disablesAnimations: Bool
    public var refreshWaveform: EInkWaveform

    public init(disablesAnimations: Bool = false, refreshWaveform: EInkWaveform = .gl16) {
        self.disablesAnimations = disablesAnimations
        self.refreshWaveform = refreshWaveform
    }
}

/// Executes a closure with the specified transaction and returns the result.
public func withTransaction<Result>(_ transaction: Transaction, _ body: () throws -> Result) rethrows -> Result {
    if transaction.refreshWaveform == .gc16 {
        KindleStateRegistry.shared.pendingFullRefresh = true
    }
    return try body()
}

extension View {
    /// Adds a reason to apply a redaction to this view hierarchy (e.g., `.placeholder` or `.privacy`).
    public func redacted(reason: RedactionReasons) -> some View {
        self.environment(\.redactionReasons, reason)
    }

    /// Removes any reason to apply a redaction to this view hierarchy.
    public func unredacted() -> some View {
        self.environment(\.redactionReasons, [])
    }
}
