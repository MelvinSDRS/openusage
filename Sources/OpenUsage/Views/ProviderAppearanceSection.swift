import SwiftUI

/// The Appearance card in a provider's Customize detail: a custom card name and a Total Spend color.
/// Both write straight to `ProviderAppearanceStore`, so the dashboard, the top bar title, and Total
/// Spend update while the user types or picks. Clearing the name (or picking Automatic)
/// restores the default.
struct ProviderAppearanceSection: View {
    let providerID: String

    @Environment(AppContainer.self) private var container
    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    /// The field's raw text. Kept apart from the store, which trims, so typing a space between two
    /// words isn't eaten mid-edit.
    @State private var draft = ""

    private var appearance: ProviderAppearanceStore { container.appearance }

    /// The provider's own name — the field's placeholder, and what an empty field falls back to.
    private var defaultName: String {
        container.registry.provider(id: providerID)?.displayName ?? providerID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: density.headerToCardSpacing) {
            Text("Appearance")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Text("Name")
                    TextField("Name", text: $draft, prompt: Text(defaultName))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, density.controlRowPadding)
                Divider()
                HStack(spacing: 10) {
                    // Never let the swatches squeeze the label into a vertical stack of letters.
                    Text("Color")
                        .fixedSize()
                    Spacer(minLength: 8)
                    ProviderColorSwatches(selection: Binding(
                        get: { appearance.color(for: providerID) },
                        set: { appearance.setColor($0, for: providerID) }
                    ))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, density.controlRowPadding)
            }
            .cardSurface()
        }
        .onAppear { draft = appearance.customName(for: providerID) ?? "" }
        .onChange(of: draft) { _, text in
            if text.count > ProviderAppearanceStore.maxNameLength {
                draft = String(text.prefix(ProviderAppearanceStore.maxNameLength))
                return
            }
            appearance.setName(text, for: providerID)
        }
    }
}

/// One row of round swatches: Automatic (a dashed ring — the provider's brand color), then every
/// `ProviderColor`. The selected swatch carries an outer ring. Sized so all eleven fit beside the
/// "Color" label in the popover's ~268pt row: 11 × 16pt + 10 × 4pt = 216pt.
private struct ProviderColorSwatches: View {
    @Binding var selection: ProviderColor?

    private static let side: CGFloat = 12

    var body: some View {
        HStack(spacing: 4) {
            swatch(nil) {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(.secondary)
            }
            ForEach(ProviderColor.allCases, id: \.self) { color in
                swatch(color) { Circle().fill(color.color) }
            }
        }
    }

    private func swatch(_ color: ProviderColor?, @ViewBuilder fill: () -> some View) -> some View {
        let selected = selection == color
        return Button {
            selection = color
        } label: {
            fill()
                .frame(width: Self.side, height: Self.side)
                .padding(2)
                .overlay {
                    if selected {
                        Circle().strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.5)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color?.title ?? "Automatic")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
