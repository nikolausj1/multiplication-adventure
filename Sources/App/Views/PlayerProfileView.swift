import SwiftUI
import SwiftData

/// The kid's trophy room (from the map's player chip): identity on the left
/// (avatar he can change, name he can edit, grade, rank), conquests on the
/// right (guardian portraits, stars, streak, XP).
struct PlayerProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var editingName = false
    @State private var draftName = ""
    @State private var pickingAvatar = false
    @FocusState private var nameFocused: Bool

    private var profile: Profile? { activeProfiles.first }

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: Theme.Metric.gap) {
                HStack {
                    Text("MY ADVENTURE")
                        .font(Theme.Font.label(15)).tracking(3)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30)).foregroundStyle(.white)
                            .frame(width: 48, height: 48).contentShape(Rectangle())
                            .shadow(radius: 3)
                    }
                    .accessibilityLabel("Close")
                }
                HStack(alignment: .top, spacing: Theme.Metric.gap) {
                    identityCard
                    trophyCard
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Metric.pad)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var backdrop: some View {
        ZStack {
            Color.black
            if Art.exists("map_bg") {
                Color.clear
                    .overlay(Image("map_bg").resizable().scaledToFill())
                    .clipped()
                    .opacity(0.4)
            }
            Color.black.opacity(0.35)
            DriftingMist().ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private var identityCard: some View {
        VStack(spacing: 14) {
            Button {
                pickingAvatar.toggle()
                Feedback.fire(.keyTap)
            } label: {
                AvatarBadge(key: profile?.avatarSymbol ?? "avatar1", size: 130)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
            }
            Text("tap to change")
                .font(Theme.Font.label(11)).foregroundStyle(.white.opacity(0.5))

            if editingName {
                TextField("", text: $draftName)
                    .font(Theme.Font.display(26)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(saveName)
                    .onChange(of: draftName) { _, new in
                        if new.count > 12 { draftName = String(new.prefix(12)) }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 14)
                    .background(Color.white.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    draftName = profile?.name ?? ""
                    editingName = true
                    nameFocused = true
                } label: {
                    HStack(spacing: 8) {
                        Text(profile?.name ?? "Player")
                            .font(Theme.Font.display(28)).foregroundStyle(.white)
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(.white.opacity(0.55))
                    }
                }
                .accessibilityLabel("Change name")
            }

            if let g = profile?.grade, !g.isEmpty {
                Text(g == "Pre-K" || g == "K" ? "Going into \(g)" : "Going into grade \(g)")
                    .font(Theme.Font.label(13)).foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }

            let rank = RankLadder.rank(forMasteredCount: profile?.masteredCount ?? 0)
            Label(rank.name.uppercased(), systemImage: "medal.fill")
                .font(Theme.Font.label(15)).tracking(2)
                .foregroundStyle(Theme.Color.accent)
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: 320)
        .darkPlate()
        .overlay {
            if pickingAvatar { avatarPickerOverlay }
        }
    }

    private var avatarPickerOverlay: some View {
        VStack(spacing: 10) {
            Text("Pick your explorer")
                .font(Theme.Font.display(18)).foregroundStyle(.white)
            AvatarCarousel(selected: Binding(
                get: { profile?.avatarSymbol ?? "avatar1" },
                set: { new in
                    profile?.avatarSymbol = new
                    try? context.save()
                }), itemSize: 96)
            Button("Done") { pickingAvatar = false }
                .font(Theme.Font.label(16)).foregroundStyle(Theme.Color.accent)
                .padding(.top, 12)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: Theme.Metric.corner))
    }

    private var trophyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GUARDIANS DEFEATED")
                .font(Theme.Font.label(13)).tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 10) {
                ForEach(WorldCatalog.worlds, id: \.index) { world in
                    let cleared = profile?.clearedWorlds.contains(world.index) ?? false
                    VStack(spacing: 5) {
                        Group {
                            if Art.exists("\(world.assetKey)_boss") {
                                Image("\(world.assetKey)_boss")
                                    .resizable().scaledToFit()
                            } else {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .frame(height: 92)
                        .saturation(cleared ? 1 : 0)
                        .opacity(cleared ? 1 : 0.3)
                        .overlay(alignment: .topTrailing) {
                            if cleared {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.Color.correct)
                                    .background(Circle().fill(.white).frame(width: 15, height: 15))
                            }
                        }
                        Text(cleared ? world.bossName : "???")
                            .font(Theme.Font.label(10))
                            .foregroundStyle(cleared ? .white : .white.opacity(0.4))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Divider().overlay(.white.opacity(0.2))
            HStack(spacing: 12) {
                statChip {
                    StarGlyph(filled: true, size: 18)
                    Text("\(profile?.questStars ?? 0)")
                        .font(Theme.Font.number(20)).foregroundStyle(.white)
                    Text("stars").font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.6))
                }
                statChip {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Theme.Color.accent)
                    Text("\(profile?.streakDays ?? 0)")
                        .font(Theme.Font.number(20)).foregroundStyle(.white)
                    Text("day streak").font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.6))
                }
                statChip {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 14)).foregroundStyle(Theme.Color.accent)
                    Text("\(profile?.totalXP ?? 0)")
                        .font(Theme.Font.number(20)).foregroundStyle(.white)
                    Text("XP").font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(Theme.Metric.pad)
        .frame(maxWidth: .infinity)
        .darkPlate()
    }

    private func statChip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 6, content: content)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(.white.opacity(0.1)))
    }

    private func saveName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { profile?.name = trimmed; try? context.save() }
        editingName = false
    }
}
