import SwiftUI
import SwiftData

/// The kid's trophy room (from the map's player chip), presented as a modal
/// card over the dimmed map: avatar + name hero on top, a pedestal gallery of
/// the seven guardians (tap a defeated one for its conquest date), and chunky
/// stat tiles along the bottom.
struct PlayerProfileView: View {
    /// Shown as an in-hierarchy overlay (NOT a fullScreenCover): the cover's
    /// hosting layer ignores ignoresSafeArea(.keyboard) and shoves the card
    /// around when the name field focuses. In the normal hierarchy the
    /// keyboard changes nothing.
    var onClose: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Environment(\.verticalSizeClass) private var vSize   // .compact = iPhone landscape
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    @State private var editingName = false
    @State private var draftName = ""
    @State private var pickingAvatar = false
    @State private var selectedTrophy: Int?
    @FocusState private var nameFocused: Bool

    private var compact: Bool { vSize == .compact }
    private var profile: Profile? { activeProfiles.first }
    private static let sheetBG = Color(red: 0.09, green: 0.10, blue: 0.14)

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            card
                .frame(maxWidth: 920)
                .padding(.vertical, 26)
        }
        // Keyboard must not move the GUI — the name field is in the card's
        // top row and stays visible on its own.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            // Screenshot hook (simulator verification only).
            if ProcessInfo.processInfo.arguments.contains("-editName") {
                draftName = profile?.name ?? ""
                editingName = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { nameFocused = true }
            }
        }
    }

    private var card: some View {
        Group {
            // iPhone landscape: scroll so the guardians row isn't crushed.
            if compact { ScrollView { cardStack } } else { cardStack }
        }
        .padding(Theme.Metric.pad)
        .overlay(alignment: .topLeading) { ModalCloseButton { onClose() }.padding(14) }
        .background(Self.sheetBG, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
            .strokeBorder(.white.opacity(0.12), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .overlay {
            if pickingAvatar { avatarPickerOverlay }
        }
    }

    private var cardStack: some View {
        VStack(spacing: compact ? 12 : 18) {
            hero
            statTiles
            guardians
                .frame(maxHeight: compact ? 200 : .infinity)
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
                    AvatarBadge(key: profile?.avatarSymbol ?? "avatar1", size: compact ? 64 : 96)
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
                        .font(Theme.Font.display(compact ? 26 : 38)).foregroundStyle(.white)
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
                    HStack(spacing: 12) {
                        Text(profile?.name ?? "Player")
                            .font(Theme.Font.display(compact ? 26 : 38)).foregroundStyle(.white)
                        Button {
                            draftName = profile?.name ?? ""
                            editingName = true
                            nameFocused = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(Theme.Font.label(14))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(.white.opacity(0.15)))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                        }
                        .accessibilityLabel("Change name")
                    }
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
            // Two rows (4 + 3) so the portraits get real width.
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(WorldCatalog.worlds.prefix(4), id: \.index) { world in
                        trophyTile(world)
                    }
                }
                .frame(maxHeight: .infinity)
                HStack(spacing: 12) {
                    ForEach(WorldCatalog.worlds.dropFirst(4), id: \.index) { world in
                        trophyTile(world)
                    }
                }
                .frame(maxHeight: .infinity)
            }
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
                    if cleared, Art.exists("\(world.assetKey)_boss") {
                        // The reveal is the reward: unbeaten guardians stay hidden.
                        Image("\(world.assetKey)_boss").resizable().scaledToFit()
                    } else if cleared {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 52, weight: .bold))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if cleared {
                        Text("DEFEATED")
                            .font(Theme.Font.label(17)).tracking(1.5)
                            .foregroundStyle(Color(red: 0.9, green: 0.16, blue: 0.14))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.45)))
                            .rotationEffect(.degrees(4))
                    }
                }
                if cleared {
                    Text(selected ? defeatDate(world) : world.bossName)
                        .font(Theme.Font.label(17))
                        .foregroundStyle(selected ? Theme.Color.accent : .white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
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
                StarGlyph(filled: true, size: 32)
            } value: {
                "\(profile?.questStars ?? 0)"
            } label: {
                "stars earned"
            }
            statTile {
                Image(systemName: "flame.fill").font(.system(size: 32))
                    .foregroundStyle(Theme.Color.accent)
            } value: {
                "\(profile?.streakDays ?? 0)"
            } label: {
                "day streak"
            }
            statTile {
                Image(systemName: "bolt.fill").font(.system(size: 30))
                    .foregroundStyle(Color(red: 1, green: 0.42, blue: 0.13))
            } value: {
                "\(profile?.bestStreak ?? 0)"
            } label: {
                "answer streak"
            }
            statTile {
                Image(systemName: "diamond.fill").font(.system(size: 27))
                    .foregroundStyle(Theme.Color.accent)
            } value: {
                "\(profile?.totalXP ?? 0)"
            } label: {
                "XP"
            }
            // The learning number, kid-framed.
            VStack(spacing: 5) {
                Text("\(fluentCount) of \(FactUniverse.count)")
                    .font(Theme.Font.number(30)).foregroundStyle(.white)
                ProgressView(value: Double(fluentCount), total: Double(FactUniverse.count))
                    .tint(Theme.Color.accent)
                    .padding(.horizontal, 18)
                Text("facts I know")
                    .font(Theme.Font.label(16)).foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 72 : 118)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08)))
        }
    }

    private func statTile(@ViewBuilder icon: () -> some View,
                          value: () -> String, label: () -> String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                icon()
                Text(value()).font(Theme.Font.number(compact ? 26 : 36)).foregroundStyle(.white)
            }
            Text(label()).font(Theme.Font.label(16)).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 72 : 118)
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
