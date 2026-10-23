import SwiftUI
import ToekomstKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = model.settings
        ScreenScroll {
            Text("Settings").textStyle(.titleL).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)

            section("Workout") {
                toggleRow("Auto-start next set", detail: "Opens the next set when rest reaches 0:00.", isOn: $settings.autoStartAfterRest)
                Hairline()
                toggleRow("Keep screen on", detail: "While a workout is running.", isOn: $settings.keepScreenOn)
                Hairline()
                toggleRow("Haptics", detail: "Taps when a set is saved or a timer ends.", isOn: $settings.haptics)
            }

            section("Appearance") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Accent").textStyle(.headline).foregroundStyle(Palette.ink)
                    SegmentedControl(
                        options: AccentTheme.allCases.map { Choice(value: $0, label: $0.label) },
                        selection: $settings.accent,
                        accessibilityLabel: "Accent"
                    )
                }
                .padding(16)
            }

            section("Training") {
                Button {
                    if let today = model.today.value?.date {
                        model.weekPlanTarget = WeekPlanTarget(weekStart: today.startOfWeek.adding(days: 7))
                    }
                } label: {
                    row("Training days", value: "Plan next week", chevron: true)
                }
                .buttonStyle(PressableStyle())
                Hairline()
                row("Units", value: "lb")
            }

            section("Data") {
                row("Back-end", value: "Fixtures · offline")
                Hairline()
                row("Fixture date", value: model.today.value.map { Format.dayHeader($0.date) } ?? "—")
                Hairline()
                Button {
                    confirmReset = true
                } label: {
                    Text("Reset fixture data")
                        .textStyle(.headline).foregroundStyle(Palette.negative)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }

            section("About") {
                row("Version", value: Bundle.main.versionString)
                Hairline()
                Text("Set in Kode Mono and Barlow, both under the SIL Open Font License 1.1.")
                    .textStyle(.footnote).foregroundStyle(Palette.ink2)
                    .padding(16)
            }
        }
        .confirmationDialog("Reset fixture data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { Task { await model.resetFixtureData() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Logged sessions, check-ins and week plans from this launch are cleared.")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            VStack(spacing: 0) { content() }
                .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func toggleRow(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.headline).foregroundStyle(Palette.ink)
                Text(detail).textStyle(.footnote).foregroundStyle(Palette.ink2)
            }
        }
        .tint(Palette.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func row(_ title: String, value: String, chevron: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title).textStyle(.headline).foregroundStyle(Palette.ink)
            Spacer()
            Text(value).textStyle(.readout).foregroundStyle(Palette.ink2)
            if chevron {
                Glyph(.chevronRight, size: 18).foregroundStyle(Palette.ink3)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
