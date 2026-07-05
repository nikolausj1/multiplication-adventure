import SwiftUI
import SwiftData

/// The kid's trophy room (from the map's player chip), presented as a modal
/// card over the dimmed map: avatar + name hero on top, a pedestal gallery of
/// the seven guardians (tap a defeated one for its conquest date), and chunky
/// stat tiles along the bottom.
struct PlayerProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var editingName = false
    @State private var draftName = ""
    @State private var pickingAvatar = false
    @State private var selectedTrophy: Int?
    @FocusState private var nameFocused: Bool

    private var profile: Profile? { activeProfiles.first }
    private static let sheetBG = Color(red: 0.09, green: 0.10, blue: 0.14)

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }
            card
                .frame(maxWidth: 920)
                .padding(.vertical, 26)
        }
        .presentationBackground(.clear)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var card: some View {
        VStack(spacing: 18) {
            ZStack {
                hero
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                    }
                    .buttonStyle(ChunkyKeyStyle(base: Theme.Color.primary,
                                                deep: Theme.Color.primary.shaded(by: -0.35),
                                                corner: 20))
                    .accessibilityLabel("Close")
                    Spacer()
                }
            }
            guardians
                .frame(maxHeight: .infinity)
            statTiles
        }
        .padding(Theme.Metric.pad)
        .background(Self.sheetBG, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .overlay {
            if pickingAvatar { avatarPickerOverlay }
        }
    }

    // MARK: Hero — avatar + name, grade + rank

    private var hero: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                Button {
                    pickingAvatar = true
                    Feedback.fire(.keyTap)
                } label: {
                    AvatarBadge(key: profile?.avatarSymbol ?? "avatar1", size: 96)
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white, Theme.Color.primary)
                                .background(Circle().fill(Self.sheetBG).frame(width: 22, height: 22))
                        }
                }
                .accessibilityLabel("Change avatar")

                if editingName {
                    TextField("", text: $draftName)
                        .font(Theme.Font.display(38)).foregroundStyle(.white)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(saveName)
                        .onChange(of: draftName) { _, new in
                            if new.count > 12 { draftName = String(new.prefix(12)) }
                        }
                        .frame(maxWidth: 300)
                        .padding(.vertical, 6).padding(.horizontal, 14)
                        .background(Color.white.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 14))
                } else {
                    Button {
                        draftName = profile?.name ?? ""
                        editingName = true
                        nameFocused = true
                    } label: {
                        HStack(spacing: 10) {
                            Text(profile?.name ?? "Player")
                                .font(Theme.Font.display(38)).foregroundStyle(.white)
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 24)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .accessibilityLabel("Change name")
                }
            }
            HStack(spacing: 12) {
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
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.Color.accent.opacity(0.15)))
            }
        }
    }

    // MARK: Guardian pedestal gallery

    private var guardians: some View {
        VStack(spacing: 10) {
            Text("GUARDIANS DEFEATED")
                .font(Theme.Font.label(14)).tracking(3)
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 12) {
                ForEach(WorldCatalog.worlds, id: \.index) { world in
                    trophyTile(world)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: Theme.Metric.corner))
    }

    private func trophyTile(_ world: World) -> some View {
        let cleared = profile?.clearedWorlds.contains(world.index) ?? false
        let selected = selectedTrophy == world.index
        return Button {
            guard cleared else { return }
            selectedTrophy = selected ? nil : world.index
            Feedback.fire(.keyTap)
        } label: {
            VStack(spacing: 8) {
                Group {
                    if Art.exists("\(world.assetKey)_boss") {
                        Image("\(world.assetKey)_boss").resizable().scaledToFit()
                    } else {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(maxHeight: .infinity)
                .saturation(cleared ? 1 : 0)
                .opacity(cleared ? 1 : 0.3)
                .overlay(alignment: .topTrailing) {
                    if cleared {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.Color.correct)
                            .background(Circle().fill(.white).frame(width: 16, height: 16))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Text(cleared ? (selected ? defeatDate(world) : world.bossName) : "???")
                    .font(Theme.Font.label(11))
                    .foregroundStyle(cleared
                        ? (selected ? Theme.Color.accent : .white)
                        : .white.opacity(0.4))
                    .lineLimit(1).minimumScaleFactor(0.65)
            }
            .padding(.horizontal, 6).padding(.vertical, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cleared
                          ? AnyShapeStyle(LinearGradient(
                                colors: [Theme.Color.accent.opacity(0.28),
                                         Theme.Color.accent.opacity(0.10)],
                                startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(0.04))))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(cleared ? Theme.Color.accent.opacity(selected ? 0.9 : 0.35)
                                      : .white.opacity(0.08),
                              lineWidth: selected ? 2.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cleared ? "\(world.bossName), defeated" : "Guardian not yet defeated")
    }

    /// "Defeated Jul 8" from the world-clear milestone record.
    private func defeatDate(_ world: World) -> String {
        let record = (profile?.milestones ?? [])
            .first { $0.kindLabel == "Cleared \(world.name)" }
        guard let d = record?.earnedDate else { return world.bossName }
        return "Defeated \(d.formatted(.dateTime.month(.abbreviated).day()))"
    }

    // MARK: Stat tiles

    private var statTiles: some View {
        let fluentCount = (profile?.facts ?? []).filter { $0.stage >= .fluency }.count
        return HStack(spacing: 12) {
            statTile {
                StarGlyph(filled: true, size: 26)
            } value: {
                "\(profile?.questStars ?? 0)"
            } label: {
                "stars earned"
            }
            statTile {
                Image(systemName: "flame.fill").font(.system(size: 26))
                    .foregroundStyle(Theme.Color.accent)
            } value: {
                "\(profile?.streakDays ?? 0)"
            } label: {
                "day streak"
            }
            statTile {
                Image(systemName: "diamond.fill").font(.system(size: 22))
                    .foregroundStyle(Theme.Color.accent)
            } value: {
                "\(profile?.totalXP ?? 0)"
            } label: {
                "XP"
            }
            // The learning number, kid-framed.
            VStack(spacing: 5) {
                Text("\(fluentCount) of \(FactUniverse.count)")
                    .font(Theme.Font.number(24)).foregroundStyle(.white)
                ProgressView(value: Double(fluentCount), total: Double(FactUniverse.count))
                    .tint(Theme.Color.accent)
                    .padding(.horizontal, 18)
                Text("facts I know")
                    .font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08)))
        }
    }

    private func statTile(@ViewBuilder icon: () -> some View,
                          value: () -> String, label: () -> String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                icon()
                Text(value()).font(Theme.Font.number(28)).foregroundStyle(.white)
            }
            Text(label()).font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 92)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08)))
    }

    // MARK: Avatar picker overlay

    private var avatarPickerOverlay: some View {
        VStack(spacing: 14) {
            Text("Pick your explorer")
                .font(Theme.Font.display(22)).foregroundStyle(.white)
            AvatarCarousel(selected: Binding(
                get: { profile?.avatarSymbol ?? "avatar1" },
                set: { new in
                    profile?.avatarSymbol = new
                    try? context.save()
                }), itemSize: 120)
            Button {
                pickingAvatar = false
            } label: {
                Text("Done")
                    .font(Theme.Font.display(18))
                    .padding(.horizontal, 34).padding(.vertical, 11)
            }
            .buttonStyle(ChunkyKeyStyle(base: Theme.Color.correct,
                                        deep: Theme.Color.correct.shaded(by: -0.35),
                                        corner: Theme.Metric.corner))
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.sheetBG.opacity(0.97),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func saveName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { profile?.name = trimmed; try? context.save() }
        editingName = false
    }
}
