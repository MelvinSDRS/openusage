import Foundation
import Observation

/// What the user changed about how one provider card looks: its name and its color. Each field is
/// optional; `nil` keeps the app's default.
struct ProviderAppearance: Codable, Equatable, Sendable {
    var name: String?
    var color: ProviderColor?

    var isEmpty: Bool { name == nil && color == nil }
}

/// Per-card name and color overrides (`openusage.providerAppearance.v1`), keyed by provider id — the
/// stable card id, so a second Claude account (`claude@ab12cd34`) keeps its own name and color across
/// launches and account swaps.
///
/// The registry stays immutable: `LayoutStore` passes every provider it hands to the UI through
/// `applied(to:)`, so the dashboard, Customize, the menu-bar strip, share cards, and Total Spend all
/// read the same overridden values; the color only drives the Total Spend ring and legend. The
/// store is `@Observable`, so a rename re-renders those surfaces live. The local HTTP API and the
/// CLI keep the provider's own name (machine-readable output, matched by id).
@MainActor
@Observable
final class ProviderAppearanceStore {
    static let storageKey = "openusage.providerAppearance.v1"
    /// Card headers are one line; longer names would only ever truncate.
    static let maxNameLength = 40

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var overrides: [String: ProviderAppearance]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            do {
                self.overrides = try JSONDecoder().decode([String: ProviderAppearance].self, from: data)
            } catch {
                AppLog.error(.config, "provider appearance overrides were undecodable; using default names and colors: \(error.localizedDescription)")
                self.overrides = [:]
            }
        } else {
            self.overrides = [:]
        }
    }

    func customName(for providerID: String) -> String? { overrides[providerID]?.name }
    func color(for providerID: String) -> ProviderColor? { overrides[providerID]?.color }

    /// Sets (or, for blank input, clears) a provider's custom name. Trimmed and capped here, at the
    /// user-input boundary, so every reader can trust the stored value.
    func setName(_ name: String?, for providerID: String) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let value = trimmed.isEmpty ? nil : String(trimmed.prefix(Self.maxNameLength))
        update(providerID) { $0.name = value }
    }

    func setColor(_ color: ProviderColor?, for providerID: String) {
        update(providerID) { $0.color = color }
    }

    /// Back to default names and colors for every provider (Settings → Reset All Settings).
    func resetAll() {
        guard !overrides.isEmpty else { return }
        overrides = [:]
        defaults.removeObject(forKey: Self.storageKey)
    }

    /// The provider as the UI should show it: custom name and color layered over the registry's.
    func applied(to provider: Provider) -> Provider {
        guard let appearance = overrides[provider.id] else { return provider }
        var provider = provider
        if let name = appearance.name { provider.displayName = name }
        provider.color = appearance.color
        return provider
    }

    private func update(_ providerID: String, _ change: (inout ProviderAppearance) -> Void) {
        var appearance = overrides[providerID] ?? ProviderAppearance()
        change(&appearance)
        guard appearance != (overrides[providerID] ?? ProviderAppearance()) else { return }
        overrides[providerID] = appearance.isEmpty ? nil : appearance
        persist()
    }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(overrides), forKey: Self.storageKey)
        } catch {
            AppLog.error(.config, "failed to encode provider appearance overrides; keeping previous persisted state: \(error.localizedDescription)")
        }
    }
}
