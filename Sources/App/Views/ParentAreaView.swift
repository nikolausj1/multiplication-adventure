import SwiftUI
import SwiftData

/// Parent area: the transparent dashboard plus a gated Manage section (profiles,
/// reset, settings). Destructive actions sit behind a 2-digit × 2-digit parent gate;
/// viewing the dashboard stays open (§2).
struct ParentAreaView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    private var service: LearningService { LearningService(context: context) }

    @State private var showGate = false
    @State private var pending: (() -> Void)?

    @State private var showAdd = false
    @State private var addName = ""
    @State private var renameTarget: Profile?
    @State private var renameText = ""
    @State private var deleteTarget: Profile?
    @State private var resetTarget: Profile?

    private let avatars = ["figure.hiking", "tortoise.fill", "hare.fill", "bird.fill",
                           "pawprint.fill", "star.fill"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Metric.gap) {
                    profilesCard
                    settingsCard
                    DashboardView()
                }
                .padding(Theme.Metric.pad)
                .frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .background(Theme.Color.bg)
            .navigationTitle("Parents")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .sheet(isPresented: $showGate) {
            ParentGateView(onPass: { showGate = false; pending?(); pending = nil },
                           onCancel: { showGate = false; pending = nil })
        }
        .alert("New profile", isPresented: $showAdd) {
            TextField("Name", text: $addName)
            Button("Create") { _ = service.createProfile(name: addName, avatar: avatars.randomElement()!); addName = "" }
            Button("Cancel", role: .cancel) { addName = "" }
        }
        .alert("Rename profile", isPresented: Binding(get: { renameTarget != nil },
                                                      set: { if !$0 { renameTarget = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") { if let t = renameTarget { service.rename(t, to: renameText) }; renameTarget = nil }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .alert("Delete profile?", isPresented: Binding(get: { deleteTarget != nil },
                                                       set: { if !$0 { deleteTarget = nil } })) {
            Button("Delete", role: .destructive) { if let t = deleteTarget { service.delete(t) }; deleteTarget = nil }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: { Text("This permanently removes the profile and all its progress.") }
        .alert("Reset progress?", isPresented: Binding(get: { resetTarget != nil },
                                                       set: { if !$0 { resetTarget = nil } })) {
            Button("Reset", role: .destructive) { if let t = resetTarget { service.resetProgress(t) }; resetTarget = nil }
            Button("Cancel", role: .cancel) { resetTarget = nil }
        } message: { Text("This returns the profile to brand-new. It cannot be undone.") }
    }

    private func gated(_ action: @escaping () -> Void) { pending = action; showGate = true }

    // MARK: Profiles

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Profiles").font(Theme.Font.label(15)).foregroundStyle(Theme.Color.inkSoft)
                Spacer()
                Button { gated { showAdd = true } } label: { Label("Add", systemImage: "plus.circle.fill") }
                    .font(Theme.Font.label(14))
            }
            ForEach(profiles) { p in profileRow(p) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.pad).cardSurface()
    }

    private func profileRow(_ p: Profile) -> some View {
        HStack(spacing: 12) {
            Image(systemName: p.avatarSymbol).font(.system(size: 22)).foregroundStyle(Theme.Color.primary)
                .frame(width: 40, height: 40).background(Theme.Color.primary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(Theme.Font.label(16)).foregroundStyle(Theme.Color.ink)
                Text("\(p.masteredCount)/\(FactUniverse.count) mastered · \(p.totalXP) XP")
                    .font(Theme.Font.label(12)).foregroundStyle(Theme.Color.inkSoft)
            }
            Spacer()
            if p.isActive {
                Text("ACTIVE").font(Theme.Font.label(11)).tracking(1)
                    .foregroundStyle(.white).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.Color.correct))
            } else {
                Button("Switch") { gated { service.switchTo(p) } }.font(Theme.Font.label(13)).buttonStyle(.bordered)
            }
            Menu {
                Button { gated { renameTarget = p; renameText = p.name } } label: { Label("Rename", systemImage: "pencil") }
                Button { gated { resetTarget = p } } label: { Label("Reset progress", systemImage: "arrow.counterclockwise") }
                if profiles.count > 1 {
                    Button(role: .destructive) { gated { deleteTarget = p } } label: { Label("Delete", systemImage: "trash") }
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 22)).foregroundStyle(Theme.Color.inkSoft)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Settings (active profile)

    private var settingsCard: some View {
        let active = profiles.first(where: { $0.isActive })
        return VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(Theme.Font.label(15)).foregroundStyle(Theme.Color.inkSoft)
            if let a = active {
                Toggle("Sound effects", isOn: Binding(get: { a.soundOn }, set: { a.soundOn = $0; Feedback.soundEnabled = $0 }))
                Toggle("Speed Round unlocked", isOn: Binding(get: { a.speedRoundUnlocked }, set: { a.speedRoundUnlocked = $0 }))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Metric.pad).cardSurface()
        .tint(Theme.Color.primary)
    }
}

/// The parent gate: a 2-digit × 2-digit challenge a young child can't pass.
struct ParentGateView: View {
    let onPass: () -> Void
    let onCancel: () -> Void

    @State private var a = 12
    @State private var b = 13
    @State private var entry = ""
    @State private var wrong = false
    @State private var ready = false

    var body: some View {
        VStack(spacing: 18) {
            Text("Grown-ups only").font(Theme.Font.display(24)).foregroundStyle(Theme.Color.ink)
            Text("Solve to continue").font(Theme.Font.body()).foregroundStyle(Theme.Color.inkSoft)
            Text("\(a) × \(b)").font(Theme.Font.number(44)).foregroundStyle(Theme.Color.ink)
            Text(entry.isEmpty ? " " : entry)
                .font(Theme.Font.number(34)).frame(minWidth: 140, minHeight: 60)
                .background(Theme.Color.bg).clipShape(RoundedRectangle(cornerRadius: 14))
            if wrong { Text("Not quite — try again").font(Theme.Font.label()).foregroundStyle(Theme.Color.gentle) }
            NumberPadView(enterEnabled: !entry.isEmpty,
                          onDigit: { d in if entry.count < 4 { entry.append(String(d)) } },
                          onDelete: { _ = entry.popLast() },
                          onEnter: check)
            Button("Cancel", action: onCancel).font(Theme.Font.label()).padding(.top, 4)
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: 460)
        .onAppear {
            guard !ready else { return }
            a = Int.random(in: 11...29); b = Int.random(in: 11...29); ready = true
        }
    }

    private func check() {
        if Int(entry) == a * b { onPass() } else { wrong = true; entry = "" }
    }
}
