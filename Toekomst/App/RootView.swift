import SwiftUI
import UIKit
import ToekomstKit

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            tab(.today) { TodayView() }
            tab(.schedule) { ScheduleView() }
            tab(.progress) { ProgressScreen() }
            tab(.settings) { SettingsView() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TorqueTabBar(selection: $model.selectedTab)
        }
        .background(Palette.bg)
        .task { await model.loadToday() }
        .fullScreenCover(item: $model.activeWorkout, onDismiss: model.workoutDidClose) { workout in
            WorkoutPlayerView(model: workout)
                .environment(\.theme, model.settings.accent.colors)
        }
        .sheet(item: $model.weekPlanTarget) { target in
            WeekPlanView(weekStart: target.weekStart)
                .environment(\.theme, model.settings.accent.colors)
        }
    }

    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .session(let id, let backTitle):
                        SessionPreviewView(sessionID: id, backTitle: backTitle)
                    case .lift(let lift):
                        LiftDetailView(lift: lift)
                    }
                }
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(tab)
    }
}

/// The Torque tab bar: four mono-labelled tabs over a hairline.
struct TorqueTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Glyph(tab.glyph)
                        Text(tab.title).textStyle(.label)
                    }
                    .foregroundStyle(selected ? Palette.ink : Palette.ink3)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Palette.bg)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// Keeps the swipe-back gesture working on screens that hide the navigation
/// bar in favour of Torque's own back buttons.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

/// Shared scaffold for top-level screens: black ground, scrolling content,
/// no system navigation bar.
struct ScreenScroll<Content: View>: View {
    var spacing: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Palette.bg)
        .toolbar(.hidden, for: .navigationBar)
    }
}
