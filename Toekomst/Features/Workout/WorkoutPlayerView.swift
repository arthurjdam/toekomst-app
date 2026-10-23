import SwiftUI
import UIKit
import ToekomstKit

/// The full-screen workout player.
struct WorkoutPlayerView: View {
    @Bindable var model: WorkoutPlayerModel
    @Environment(AppModel.self) private var app
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            switch model.screen {
            case .exercise: ExerciseScreen(model: model)
            case .rest: RestScreen(model: model)
            case .transition: TransitionScreen(model: model)
            case .circuit: CircuitScreen(model: model)
            case .finishing: finishing
            case .summary: SummaryScreen(model: model) { app.activeWorkout = nil }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.screen)
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
                    Text("Exercise \(model.engine.exerciseNumber(of: step)) of \(model.engine.exerciseCount) · \(model.engine.group(of: step).title)")
                        .textStyle(.label).foregroundStyle(Palette.ink2)
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
                .accessibilityHint("Switches between time left and time elapsed")
            Button { model.pause() } label: { Glyph(.pause, size: 20) }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Pause")
        }
    }
}

/// Exercises as squares, grouped; the current exercise expands into one tick per set.
struct SessionProgressBar: View {
    let engine: WorkoutEngine
    @Environment(\.theme) private var theme

    var body: some View {
        let groups = engine.progress()
        HStack(spacing: 12) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, items in
                let hasCurrent = items.contains { if case .current = $0 { return true } else { return false } }
                HStack(spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        switch item {
                        case .done:
                            RoundedRectangle(cornerRadius: 2).fill(Palette.ink2).frame(width: 8, height: 8)
                        case .upcoming:
                            RoundedRectangle(cornerRadius: 2).strokeBorder(Palette.lineStrong, lineWidth: 1).frame(width: 8, height: 8)
                        case .current(let sets):
                            HStack(spacing: 3) {
                                ForEach(Array(sets.enumerated()), id: \.offset) { _, set in
                                    RoundedRectangle(cornerRadius: 2).fill(color(for: set))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 8)
                        }
                    }
                }
                .frame(maxWidth: hasCurrent ? .infinity : nil)
            }
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(engine.completedStepCount) of \(engine.steps.count) sets done")
    }

    private func color(for set: SetProgress) -> Color {
        switch set {
        case .done: return theme.signal
        case .current: return Palette.lineStrong
        case .upcoming: return Palette.surface3
        }
    }
}
