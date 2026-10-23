import SwiftUI
import UIKit
import ToekomstKit

/// The full-screen workout player.
struct WorkoutPlayerView: View {
    @Bindable var model: WorkoutPlayerModel
    @Environment(AppModel.self) private var app
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            ZStack {
                let page = AnyTransition.flatPush(reduceMotion: reduceMotion)
                switch model.screen {
                case .exercise: ExerciseScreen(model: model).transition(page)
                case .rest: RestScreen(model: model).transition(page)
                case .transition: TransitionScreen(model: model).transition(page)
                case .circuit: CircuitScreen(model: model).transition(page)
                case .finishing: finishing.transition(.opacity)
                case .summary: SummaryScreen(model: model) { app.activeWorkout = nil }.transition(page)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Palette.bg)
        .animation(Motion.page, value: model.screen)
        .sheet(isPresented: $model.showReadiness) {
            ReadinessSheet(session: model.session) { answers in
                model.begin(with: answers)
            } onCancel: {
                app.activeWorkout = nil
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $model.showLogSheet) {
            LogSetSheet(model: model)
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

/// Session progress, the exercise counter, time chip and pause.
struct WorkoutHeader: View {
    let model: WorkoutPlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SessionProgressBar(engine: model.engine)
            HStack {
                if let step = model.currentStep {
                    let label = "Exercise \(model.engine.exerciseNumber(of: step)) of \(model.engine.exerciseCount) · \(model.engine.group(of: step).title)"
                    Text(label)
                        .textStyle(.label).foregroundStyle(Palette.ink2)
                        .glitch(on: label)
                }
                Spacer()
                WorkoutControls(model: model)
            }
            .frame(height: 44)
        }
    }
}

/// Time-left chip and pause button.
struct WorkoutControls: View {
    @Bindable var model: WorkoutPlayerModel

    var body: some View {
        HStack(spacing: 4) {
            Button(model.timeChipText) { model.showElapsed.toggle() }
                .buttonStyle(.plain)
                .textStyle(.readout)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .glitch(on: model.showElapsed)
                .accessibilityHint("Switches between time left and time elapsed")
            Button { model.pause() } label: { Glyph(.pause, size: 20) }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Pause")
        }
    }
}

/// Exercises as squares, grouped; the current exercise expands into one tick
/// per set. Every exercise keeps the same view as the workout moves on, so
/// widths and colors interpolate flat instead of the bar being redrawn.
struct SessionProgressBar: View {
    let engine: WorkoutEngine

    var body: some View {
        let groups = engine.progress()
        HStack(spacing: 12) {
            ForEach(Array(groups.enumerated()), id: \.offset) { groupIndex, items in
                let hasCurrent = items.contains { $0.isCurrent }
                HStack(spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                        ProgressSlot(
                            state: item,
                            setCount: engine.setCount(for: WorkoutStep(groupIndex: groupIndex, itemIndex: itemIndex, setNumber: 1))
                        )
                    }
                }
                .frame(maxWidth: hasCurrent ? .infinity : nil)
            }
        }
        .frame(height: 10)
        .animation(Motion.flat, value: engine.completedStepCount)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(engine.completedStepCount) of \(engine.steps.count) sets done")
    }
}

/// One exercise in the progress bar: an 8-point square, or set ticks while current.
private struct ProgressSlot: View {
    let state: ExerciseProgress
    let setCount: Int
    @Environment(\.theme) private var theme

    var body: some View {
        let current = state.isCurrent
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(state == .done ? Palette.ink2 : Palette.ink2.opacity(0))
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Palette.lineStrong, lineWidth: 1)
                        .opacity(state == .upcoming ? 1 : 0)
                }
                .opacity(current ? 0 : 1)
            HStack(spacing: 3) {
                ForEach(0..<setCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2).fill(tickColor(index))
                }
            }
            .opacity(current ? 1 : 0)
        }
        .frame(width: current ? nil : 8, height: 8)
        .frame(maxWidth: current ? .infinity : 8)
        .clipped()
    }

    private func tickColor(_ index: Int) -> Color {
        switch state {
        case .done: return theme.signal
        case .upcoming: return Palette.surface3
        case .current(let sets):
            switch sets.indices.contains(index) ? sets[index] : .upcoming {
            case .done: return theme.signal
            case .current: return Palette.lineStrong
            case .upcoming: return Palette.surface3
            }
        }
    }
}

private extension ExerciseProgress {
    var isCurrent: Bool {
        if case .current = self { return true }
        return false
    }
}
