import SwiftUI
import ToekomstKit

/// Pick the training days for a week; the planner orders the sessions so
/// sessions sharing muscles don't land back to back. Rows can be dragged to
/// override the order.
struct WeekPlanView: View {
    let weekStart: LocalDate
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LoadState<WeekPlanDraft> = .loading
    @State private var selected: Set<Weekday> = []
    @State private var manualOrder: [String]?
    @State private var repeatEveryWeek = false
    @State private var saving = false
    @State private var error: String?
    /// Lets a session card slide to its new day when the order changes.
    @Namespace private var cards

    var body: some View {
        Group {
            switch draft {
            case .loading:
                LoadingView().transition(.opacity)
            case .failed(let message):
                LoadingView(message: message) { Task { await load() } }
                    .transition(.opacity)
            case .loaded(let draft):
                content(draft).transition(.opacity)
            }
        }
        .animation(Motion.flat, value: draft.phase)
        .background(Palette.bg)
        .task { await load() }
        .presentationBackground(Palette.bg)
    }

    private func load() async {
        do {
            let loaded = try await model.repository.weekPlanDraft(for: weekStart)
            selected = Set(loaded.selectedDays)
            repeatEveryWeek = loaded.repeatEveryWeek
            draft = .loaded(loaded)
        } catch {
            draft = .failed(error.localizedDescription)
        }
    }

    private func makePlan(_ draft: WeekPlanDraft) -> WeekPlanner.Plan<SessionTemplate> {
        let days = Array(selected)
        if let manualOrder, manualOrder.count == selected.count {
            let templates = manualOrder.compactMap { id in draft.templates.first { $0.id == id } }
            return WeekPlanner.evaluate(days: days, sessions: templates, kind: \.kind)
        }
        return WeekPlanner.plan(days: days, sessions: draft.templates, kind: \.kind)
    }

    private func content(_ draft: WeekPlanDraft) -> some View {
        let plan = makePlan(draft)
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick your days").textStyle(.titleL).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Choose any \(draft.templates.count). The app orders the sessions so the same muscles get a rest day.")
                        .textStyle(.callout).foregroundStyle(Palette.ink2)
                }
                dayPicker(draft, plan: plan)
                statusBox(plan, needed: draft.templates.count)
                weekList(plan)
                repeatToggle
                if let error {
                    Text(error).textStyle(.footnote).foregroundStyle(Palette.negative)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(saving ? "Saving…" : "Save week") {
                Task { await save(plan) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!plan.status.isReady || saving)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Palette.bg)
            .overlay(alignment: .top) { Hairline() }
        }
    }

    private var weekLabel: String {
        let range = Format.weekRange(weekStart)
        guard let today = model.today.value?.date else { return range }
        switch today.startOfWeek.days(until: weekStart) / 7 {
        case 0: return "This week · \(range)"
        case 1: return "Next week · \(range)"
        default: return range
        }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(QuietButtonStyle())
            Spacer()
            Text(weekLabel).textStyle(.label).foregroundStyle(Palette.ink2)
        }
    }

    private func dayPicker(_ draft: WeekPlanDraft, plan: WeekPlanner.Plan<SessionTemplate>) -> some View {
        let ready = selected.count == draft.templates.count
        return VStack(spacing: 8) {
            SectionHeader(
                title: "Training days",
                detail: "\(selected.count) of \(draft.templates.count)",
                detailColor: ready ? Palette.ink2 : Palette.ink
            )
            .glitch(on: selected.count)
            HStack(spacing: 6) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    let on = selected.contains(day)
                    let date = weekStart.adding(days: day.rawValue - 1)
                    Button {
                        withAnimation(Motion.flat) {
                            if on { selected.remove(day) } else { selected.insert(day) }
                            manualOrder = nil
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.shortName).textStyle(.label)
                            Text("\(date.day)").textStyle(.readout)
                        }
                        .foregroundStyle(on ? Palette.bg : Palette.ink2)
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background(on ? Palette.ink : Palette.surface1, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? Palette.ink : Palette.line, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(day.fullName)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: selected)
        }
    }

    private func statusBox(_ plan: WeekPlanner.Plan<SessionTemplate>, needed: Int) -> some View {
        let (badge, color, text) = statusCopy(plan, needed: needed)
        return HStack(alignment: .top, spacing: 12) {
            Badge(text: badge, foreground: color)
                .glitch(on: badge)
            Text(text).textStyle(.footnote).foregroundStyle(Palette.ink)
                .glitch(on: text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func statusCopy(_ plan: WeekPlanner.Plan<SessionTemplate>, needed: Int) -> (String, Color, String) {
        switch plan.status {
        case .needMore(let count):
            return ("Pick \(count) more", Palette.ink, "This block is built on \(needed) sessions a week.")
        case .tooMany:
            return ("Too many", Palette.ink, "Tap a day to remove it. The block runs \(needed) sessions a week.")
        case .good:
            return ("✓ Good", Palette.positive, "No two sessions that load the same muscles land on back-to-back days. Legs recover before the next circuit.")
        case .longRun(let run):
            return ("✓ Works", Palette.positive, "\(run) days in a row is fine for this order, but expect the last one to feel harder.")
        case .tight(let first, let second):
            let index = plan.clashes.first ?? 0
            let a = plan.sessions[index].kind.displayName
            let b = plan.sessions[index + 1].kind.displayName.lowercased()
            return ("▼ Tight", Palette.negative, "\(a) and \(b) land on \(first.shortName) and \(second.shortName). The same muscles get no rest. Try moving one of them a day.")
        }
    }

    private func weekList(_ plan: WeekPlanner.Plan<SessionTemplate>) -> some View {
        let ready = plan.status.isReady
        return VStack(spacing: 8) {
            SectionHeader(title: "Your week", detail: ready ? "Hold ≡ to reorder" : nil)
            VStack(spacing: 6) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    let date = weekStart.adding(days: day.rawValue - 1)
                    if ready, let index = plan.days.firstIndex(of: day) {
                        let template = plan.sessions[index]
                        let warn = plan.clashes.contains(index) || plan.clashes.contains(index - 1)
                        sessionRow(day: day, date: date, template: template, warn: warn)
                            .draggable(template.id) {
                                KindBadge(kind: template.kind).padding(8)
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let dragged = items.first, dragged != template.id else { return false }
                                swap(dragged, template.id, in: plan)
                                return true
                            }
                    } else {
                        HStack(spacing: 12) {
                            Text(day.shortName).textStyle(.label).foregroundStyle(Palette.ink3).frame(width: 40)
                            Text("Rest").textStyle(.footnote).foregroundStyle(Palette.ink3)
                            Hairline()
                        }
                        .frame(height: 28)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.fullName), rest")
                    }
                }
            }
        }
    }

    private func sessionRow(day: Weekday, date: LocalDate, template: SessionTemplate, warn: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(day.shortName).textStyle(.label).foregroundStyle(Palette.ink2)
                Text("\(date.day)").textStyle(.readout).foregroundStyle(Palette.ink)
            }
            .frame(width: 40)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    KindBadge(kind: template.kind)
                    Text(template.title).textStyle(.headline).foregroundStyle(Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Glyph(.dragHandle, size: 20).foregroundStyle(Palette.ink3).frame(width: 44, height: 44)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(warn ? Palette.negative : .clear, lineWidth: 1))
            .matchedGeometryEffect(id: template.id, in: cards)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.fullName), \(template.kind.displayName), \(template.title)\(warn ? ", clashes with a neighbouring day" : "")")
    }

    private func swap(_ first: String, _ second: String, in plan: WeekPlanner.Plan<SessionTemplate>) {
        var order = plan.sessions.map(\.id)
        guard let a = order.firstIndex(of: first), let b = order.firstIndex(of: second) else { return }
        order.swapAt(a, b)
        withAnimation(Motion.flat) { manualOrder = order }
    }

    private var repeatToggle: some View {
        Toggle(isOn: $repeatEveryWeek) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Use these days every week").textStyle(.headline).foregroundStyle(Palette.ink)
                Text("Off: you'll be asked each Sunday.").textStyle(.footnote).foregroundStyle(Palette.ink2)
            }
        }
        .tint(Palette.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.surface1, in: RoundedRectangle(cornerRadius: 20))
    }

    private func save(_ plan: WeekPlanner.Plan<SessionTemplate>) async {
        saving = true
        defer { saving = false }
        do {
            _ = try await model.repository.saveWeekPlan(WeekPlanRequest(
                weekStart: weekStart,
                trainingDays: plan.days,
                sessionOrder: plan.sessions.map(\.id),
                repeatEveryWeek: repeatEveryWeek
            ))
            await model.dataDidChange()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
