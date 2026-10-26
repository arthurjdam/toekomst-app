import SwiftUI
import UIKit
import ToekomstKit

/// The full-screen workout player.
struct WorkoutPlayerView: View {
    @Bindable var model: WorkoutPlayerModel
    @Environment(AppModel.self) private var app
    @Environment(\.theme) private var theme
    /// Shared elements (card, title, weight, sets, main button) morph between
    /// screens within this namespace.
    @Namespace private var stage
    /// A set logged from the sheet, applied once the sheet has closed so the
    /// screen change and progress bar animate in view rather than behind it.
    @State private var pendingLog: PendingLog?

    private struct PendingLog {
        let load: Double?
        let reps: Int
        let repsInReserve: Int
    }

    /// Exercise, rest and up next share one header so its progress bar can
    /// animate from state to state while the page below changes.
    private var showsHeader: Bool {
        [.exercise, .rest, .transition].contains(model.screen)
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                WorkoutHeader(model: model)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
            // Screens cross-fade while their shared elements morph from the old
            // layout to the new one, so a change reads as one screen reshaping.
            ZStack {
                switch model.screen {
                case .exercise: ExerciseScreen(model: model, stage: stage).transition(.opacity)
                case .rest: RestScreen(model: model, stage: stage).transition(.opacity)
                case .transition: TransitionScreen(model: model, stage: stage).transition(.opacity)
                case .circuit: CircuitScreen(model: model, stage: stage).transition(.opacity)
                case .finishing: finishing.transition(.opacity)
                case .summary: SummaryScreen(model: model) { app.activeWorkout = nil }.transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.bg)
        .animation(Motion.stage, value: model.screen)
        .sheet(isPresented: $model.showReadiness) {
            ReadinessSheet(session: model.session) { answers in
                model.begin(with: answers)
            } onCancel: {
                app.activeWorkout = nil
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $model.showLogSheet, onDismiss: commitPendingLog) {
            LogSetSheet(model: model) { load, reps, reserve in
                pendingLog = PendingLog(load: load, reps: reps, repsInReserve: reserve)
                model.showLogSheet = false
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $model.showInfo) {
            if let item = model.currentItem {
                ExerciseInfoSheet(item: item)
            }
        }
        .confirmationDialog("Workout paused", isPresented: $model.showPauseMenu, titleVisibility: .visible) {
            Button("Resume") { model.resume() }
            if model.screen == .exercise {
                Button("Skip this set") {
                    model.resume()
                    model.skipCurrent()
                }
            }
            Button("End and save") { model.finish() }
            Button("Discard workout", role: .destructive) { app.activeWorkout = nil }
        } message: {
            Text("\(model.engine.logs.count) of \(model.engine.steps.count) sets logged.")
        }
        .onChange(of: model.showPauseMenu) { _, showing in
            if !showing, model.isPaused { model.resume() }
        }
        .sensoryFeedback(trigger: model.setsLogged) { _, _ in
            app.settings.haptics ? .success : nil
        }
        .sensoryFeedback(trigger: model.phasesEnded) { _, _ in
            app.settings.haptics ? .impact(weight: .heavy) : nil
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = app.settings.keepScreenOn
        }
        .task {
            // Present the ready check after the cover finishes animating in.
            guard !model.hasBegun else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            model.showReadiness = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            model.stop()
        }
    }

    private func commitPendingLog() {
        guard let log = pendingLog else { return }
        pendingLog = nil
        withAnimation(Motion.stage) {
            model.logSet(load: log.load, reps: log.reps, repsInReserve: log.repsInReserve)
        }
    }

    private var finishing: some View {
        VStack(spacing: 16) {
            if let error = model.finishError {
                Text("Couldn't save the session").textStyle(.titleM).foregroundStyle(Palette.ink)
                Text(error).textStyle(.callout).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
                Button("Try again") { Task { await model.submitLog() } }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                ProgressView().tint(Palette.ink2)
                Text("Saving session").textStyle(.label).foregroundStyle(Palette.ink2)
            }
        }
        .padding(20)
    }
}

/// Session progress, the live clock, time left and pause.
struct WorkoutHeader: View {
    let model: WorkoutPlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SessionProgressBar(engine: model.engine)
            HStack {
                LiveIndicator(startedAt: model.engine.startedAt, isRunning: model.hasBegun && !model.isPaused)
                Spacer()
                WorkoutControls(model: model)
            }
            .frame(height: 44)
        }
    }
}

/// Time left and the pause button.
struct WorkoutControls: View {
    let model: WorkoutPlayerModel

    var body: some View {
        HStack(spacing: 4) {
            Text("~\(model.minutesLeft) min left")
                .textStyle(.readout)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .wipe(on: model.minutesLeft)
            Button { model.pause() } label: { Glyph(.pause, size: 20) }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Pause")
        }
    }
}

/// Exercises as squares, grouped; the current exercise expands into one tick
/// per set. A logged set animates in two visible steps: its tick fills left
/// to right, then (if the exercise is finished) it collapses to a square while
/// the next exercise opens up into its ticks.
struct SessionProgressBar: View {
    let engine: WorkoutEngine
    /// Steps shown as filled.
    @State private var filled: Int
    /// Steps the layout (which exercise is open) reflects. Trails `filled`.
    @State private var layout: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    init(engine: WorkoutEngine) {
        self.engine = engine
        _filled = State(initialValue: engine.completedStepCount)
        _layout = State(initialValue: engine.completedStepCount)
    }

    var body: some View {
        GeometryReader { geometry in
            let groups = engine.progress(atStep: layout)
            let indices = engine.stepIndices
            let openWidth = openSlotWidth(total: geometry.size.width, groups: groups)
            HStack(spacing: Self.groupGap) {
                ForEach(Array(groups.enumerated()), id: \.offset) { groupIndex, items in
                    HStack(spacing: Self.slotGap) {
                        ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                            let sets = engine.setCount(for: WorkoutStep(groupIndex: groupIndex, itemIndex: itemIndex, setNumber: 1))
                            ProgressSlot(
                                expanded: item.isCurrent,
                                width: item.isCurrent ? openWidth : ProgressRowLayout.square,
                                steps: (1...sets).map { indices[WorkoutStep(groupIndex: groupIndex, itemIndex: itemIndex, setNumber: $0)] ?? 0 },
                                filled: filled
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 10)
        .task(id: engine.completedStepCount) {
            let target = engine.completedStepCount
            guard target != filled || target != layout else { return }
            withAnimation(Motion.progress) { filled = target }
            try? await Task.sleep(nanoseconds: reduceMotion ? 0 : 380_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.progress) { layout = target }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(engine.completedStepCount) of \(engine.steps.count) sets done")
    }

    private static let groupGap: CGFloat = 12
    private static let slotGap: CGFloat = 4

    /// The open exercise takes what the squares and gaps leave, pixel-snapped.
    private func openSlotWidth(total: CGFloat, groups: [[ExerciseProgress]]) -> CGFloat {
        let slots = groups.reduce(0) { $0 + $1.count }
        let open = groups.reduce(0) { $0 + $1.filter(\.isCurrent).count }
        let gaps = CGFloat(max(0, groups.count - 1)) * Self.groupGap
            + groups.reduce(0) { $0 + CGFloat(max(0, $1.count - 1)) * Self.slotGap }
        return ProgressRowLayout.openWidth(total: total, squares: slots - open, gaps: gaps, scale: displayScale)
    }
}

/// One exercise in the progress bar: an 8-point square, or set ticks while open.
private struct ProgressSlot: View {
    let expanded: Bool
    let width: CGFloat
    /// The step index of each set, in order.
    let steps: [Int]
    let filled: Int

    var body: some View {
        let done = steps.allSatisfy { $0 < filled }
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(done ? Palette.ink2 : Palette.ink2.opacity(0))
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Palette.lineStrong, lineWidth: 1)
                        .opacity(done ? 0 : 1)
                }
                .opacity(expanded ? 0 : 1)
            // Collapsed, the ticks' spacing goes to zero so they fit inside the
            // square without clipping (which would also trim its outline).
            HStack(spacing: expanded ? 3 : 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    ProgressTick(isFilled: step < filled, isNext: step == filled)
                }
            }
            .opacity(expanded ? 1 : 0)
        }
        .frame(width: width, height: ProgressRowLayout.square)
    }
}

/// A set tick: a track, with a signal fill that wipes in from the left.
private struct ProgressTick: View {
    let isFilled: Bool
    let isNext: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isNext ? Palette.lineStrong : Palette.surface3)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(theme.signal)
                        .frame(width: isFilled ? geometry.size.width : 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

private extension ExerciseProgress {
    var isCurrent: Bool {
        if case .current = self { return true }
        return false
    }
}
