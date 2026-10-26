import SwiftUI
import UIKit
import ToekomstKit

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        // All four tabs stay alive (and keep their navigation state); switching
        // fades and slides them flat instead of TabView's hard cut.
        ZStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = tab == model.selectedTab
                tabStack(tab)
                    .opacity(selected ? 1 : 0)
                    .offset(x: selected || reduceMotion ? 0 : offset(for: tab))
                    .allowsHitTesting(selected)
                    .accessibilityHidden(!selected)
                    .zIndex(selected ? 1 : 0)
            }
        }
        .animation(Motion.page, value: model.selectedTab)
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

    /// Tabs to the left of the selected one wait on the left, and vice versa,
    /// so a switch always travels in the direction of the tab bar.
    private func offset(for tab: AppTab) -> CGFloat {
        tab.index < model.selectedTab.index ? -Motion.pageOffset : Motion.pageOffset
    }

    @ViewBuilder
    private func tabStack(_ tab: AppTab) -> some View {
        NavigationStack {
            Group {
                switch tab {
                case .today: TodayView()
                case .schedule: ScheduleView()
                case .progress: ProgressScreen()
                case .settings: SettingsView()
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .session(let id, let backTitle):
                    SessionPreviewView(sessionID: id, backTitle: backTitle)
                case .lift(let lift):
                    LiftDetailView(lift: lift)
                }
            }
        }
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
                    .animation(Motion.flat, value: selected)
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
