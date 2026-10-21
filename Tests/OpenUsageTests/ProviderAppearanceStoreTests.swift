import XCTest
@testable import OpenUsage

@MainActor
final class ProviderAppearanceStoreTests: XCTestCase {
    private func makeScratchDefaults() -> UserDefaults {
        let suiteName = "OpenUsageTests.ProviderAppearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testNameAndColorSurviveRelaunchAndBlankNameRestoresDefault() {
        let defaults = makeScratchDefaults()
        let store = ProviderAppearanceStore(defaults: defaults)

        store.setName("  Work  ", for: "claude")
        store.setColor(.teal, for: "claude@ab12cd34")
        store.setName(String(repeating: "x", count: 60), for: "codex")

        let relaunched = ProviderAppearanceStore(defaults: defaults)
        XCTAssertEqual(relaunched.customName(for: "claude"), "Work", "names are trimmed at the input boundary")
        XCTAssertEqual(relaunched.color(for: "claude@ab12cd34"), .teal, "each account card keeps its own color")
        XCTAssertEqual(relaunched.customName(for: "codex")?.count, ProviderAppearanceStore.maxNameLength)

        relaunched.setName("   ", for: "claude")
        relaunched.setName(nil, for: "codex")
        XCTAssertNil(ProviderAppearanceStore(defaults: defaults).customName(for: "claude"))
        XCTAssertEqual(
            Set(ProviderAppearanceStore(defaults: defaults).overrides.keys), ["claude@ab12cd34"],
            "a card back to all defaults leaves no stored entry behind"
        )

        relaunched.resetAll()
        XCTAssertTrue(ProviderAppearanceStore(defaults: defaults).overrides.isEmpty)
    }

    /// Every surface (dashboard header, Customize, menu-bar strip, Total Spend) reads providers from
    /// `LayoutStore`, so a provider that skipped the appearance overlay would show its default name.
    func testLayoutStoreHandsTheUIProvidersWithTheUsersNameAndColor() {
        let defaults = makeScratchDefaults()
        let appearance = ProviderAppearanceStore(defaults: defaults)
        let layout = LayoutStore(
            registry: .mock,
            defaults: defaults,
            storageKey: "layout",
            applyAppearance: { appearance.applied(to: $0) }
        )

        appearance.setName("Personal", for: "claude")
        appearance.setColor(.pink, for: "claude")

        let claudeViews: [Provider?] = [
            layout.provider(id: "claude"),
            layout.displayGroups.first { $0.id == "claude" }?.provider,
            layout.customizeProviderRows.first { $0.id == "claude" }?.provider,
            layout.customizeDetail(for: "claude")?.provider,
        ]
        for provider in claudeViews {
            XCTAssertEqual(provider?.displayName, "Personal")
            XCTAssertEqual(provider?.color, .pink)
        }
        XCTAssertEqual(layout.provider(id: "codex")?.displayName, "Codex", "other providers keep their names")
        XCTAssertNil(layout.provider(id: "codex")?.color)
        XCTAssertEqual(layout.registry.provider(id: "claude")?.displayName, "Claude", "the registry keeps the default")
    }
}
