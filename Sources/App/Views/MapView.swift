import SwiftUI
import SwiftData

/// The adventure map — the home/hub. A winding trail of 7 world nodes fitted to one
/// landscape screen; locked worlds are fogged, the current world pulses. Tapping an
/// unlocked node starts a themed session. The gear opens the parent area.
struct MapView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var vSize   // compact = iPhone landscape
    @Query(filter: #Predicate<Profile> { $0.isActive }) private var activeProfiles: [Profile]

    private var compact: Bool { vSize == .compact }

    @State private var sessionWorld: WorldSelection?
    @State private var showParent = false
    @State private var showProfile = false
    @State private var showStreak = false
    @State private var showTimesTable = false
    @State private var showCertificate = false
    @State private var showMapComplete = false
    // Golden Guardians phase 4, beat 1: all seven guardians gilded.
    @State private var showGuardiansAssemble = false

    // Golden Guardians phase 3: the map transformation. `revealGoldenMap`
    // gates the golden visuals independently of the persisted
    // `mapCompleteCelebrated` flag so the transform can never be seen while
    // the completion overlay is still up (spec acceptance 2) — it starts
    // false and is set once, either immediately on appear (already in the
    // golden era at launch: static, no animation) or when the overlay is
    // dismissed for the first time (fresh transform: animated). Both are
    // transient @State, never persisted — a later launch in the golden era
    // just renders golden statically, per spec.
    @State private var revealGoldenMap = false
    @State private var playTransformAnimation = false
    // Visual redesign: two quick lightning-flash pulses that open the reveal
    // sequence (flash -> B&W -> guardians slam in), before `revealGoldenMap`
    // flips. A plain @State opacity driven by a short withAnimation chain —
    // see `runRevealFlashes()`.
    @State private var flashOpacity: Double = 0
    // Visual redesign: true once the finale color flood has played (or, on a
    // later launch, once `Profile.guardiansColorFloodPlayed` says it already
    // has). Gates the B&W scene (`sceneIsBW`) and the return of
    // `GoldenMapTint`. Kept separate from `revealGoldenMap` because the
    // golden era has two visually distinct sub-phases: B&W-with-gold-nodes
    // (pre-finale) and fully colored (post-finale) — see docs/golden-
    // guardians-spec.md's redesign addendum.
    @State private var sceneColorRestored = false
    // Golden Guardians WP5: award sequencing. The map-complete takeover's
    // dismissal used to trigger the phase-3 transform directly; now the
    // certificate sits between them (spec acceptance 1: awarded at map
    // completion, no mastery precondition). This flag is set only on that
    // first-award path and consumed by the certificate cover's `onDismiss`,
    // so the transform plays exactly once, right after the FIRST certificate
    // viewing — never on the trophy-button re-open path (which never sets
    // this flag) and never before/during the certificate itself (acceptance 2).
    @State private var pendingFirstTransform = false

    // Locked-node tap response + the fog-lift reveal when a new world opens.
    @State private var shakeTarget: Int?
    @State private var shakePhase: CGFloat = 0
    @State private var hintNode: Int?
    @State private var revealWorld: Int?
    @State private var baselineCurrent = 0

    private var profile: Profile? { activeProfiles.first }
    private var snapshots: [FactSnapshot] { (profile?.facts ?? []).map(\.snapshot) }
    private var clearedSet: Set<Int> { profile?.clearedWorlds ?? [] }
    private var currentIndex: Int { profile?.currentWorldIndex ?? 0 }
    /// The anytime Speed Round is a parent-enabled extra; the boss challenge is
    /// the built-in timed moment.
    private var canSpeedRound: Bool { profile?.speedRoundUnlocked ?? false }
    /// The True/False Lightning Round: a parent-enabled extra, gated the same way
    /// as the Speed Round (see ParentAreaView's Settings toggle).
    private var canLightning: Bool { profile?.lightningRoundUnlocked ?? false }
    /// Golden Guardians phase 3: the map is beaten and the completion
    /// celebration has played. From here every node routes straight into
    /// that world's golden fight — no menu, no chooser (spec: "the exciting
    /// thing should not have a chooser in front of it").
    private var isGoldenEra: Bool {
        clearedSet.count == WorldCatalog.count && (profile?.mapCompleteCelebrated ?? false)
    }
    /// Golden Guardians phase 4: every world's guardian has been gilded — the
    /// three final beats (assemble takeover, certificate seal, map caption)
    /// all key off this.
    private var allGilded: Bool {
        (profile?.gildedWorlds.count ?? 0) == WorldCatalog.count
    }
    /// Visual redesign: the whole scene (backdrop + banner) desaturates for
    /// the golden era's pre-finale stretch — gold nodes/trail/labels are the
    /// only color on screen, "the guardians drained this world's color."
    /// Once the finale flood plays (or has already played on a prior
    /// launch), the scene is fully colored again.
    private var sceneIsBW: Bool { revealGoldenMap && !sceneColorRestored }

    /// Fractional positions of each world node, forming a left→right winding trail,
    /// vertically centered in the space between the title banner and screen bottom.
    private let pts: [CGPoint] = [
        CGPoint(x: 0.09, y: 0.82), CGPoint(x: 0.22, y: 0.56), CGPoint(x: 0.35, y: 0.80),
        CGPoint(x: 0.49, y: 0.55), CGPoint(x: 0.63, y: 0.78), CGPoint(x: 0.78, y: 0.55),
        CGPoint(x: 0.91, y: 0.76),
    ]

    /// iPhone landscape is short: the capped banner takes the top ~0.32, so the
    /// trail is compressed into the lower band (upper row ~0.56, lower ~0.80) with
    /// smaller nodes so both rows clear the banner and neither clips the bottom.
    private let ptsCompact: [CGPoint] = [
        CGPoint(x: 0.09, y: 0.80), CGPoint(x: 0.22, y: 0.56), CGPoint(x: 0.35, y: 0.80),
        CGPoint(x: 0.49, y: 0.56), CGPoint(x: 0.63, y: 0.80), CGPoint(x: 0.78, y: 0.56),
        CGPoint(x: 0.91, y: 0.79),
    ]
    private var nodePoints: [CGPoint] { compact ? ptsCompact : pts }

    var body: some View {
        ZStack {
            mapBackdrop
                .saturation(sceneIsBW ? 0 : 1)
            // Visual redesign: the warm tint is a "golden hour over a
            // colored map" effect, so it fights flat grayscale — it only
            // returns once the finale flood has restored the scene's color.
            if revealGoldenMap, sceneColorRestored {
                GoldenMapTint()
                    .transition(.opacity)
            }
            GeometryReader { geo in
                let scaled = nodePoints.map { CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height) }
                ZStack {
                    TrailPath(points: scaled)
                        .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 14]))
                        .foregroundStyle(revealGoldenMap
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(red: 1, green: 0.86, blue: 0.5).opacity(0.8),
                                         Color(red: 0.9, green: 0.66, blue: 0.22).opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(.white.opacity(0.55)))
                    ForEach(WorldCatalog.worlds, id: \.index) { world in
                        nodeView(world)
                            .position(scaled[world.index])
                    }
                }
            }
            DriftingMist().ignoresSafeArea()
            // Golden Guardians phase 4, beat 3: the quiet completion
            // statement, permanent from the moment every guardian is gilded.
            // Sits in the strip below the node labels/trail (the Master
            // Quest bar that used to live here is removed entirely — WP5),
            // so it never collides with the nodes or their labels on either
            // form factor. No digits, no CTA — it simply exists.
            if isGoldenEra, allGilded, revealGoldenMap, !showMapComplete, !showGuardiansAssemble {
                if compact {
                    VStack { Spacer(); goldenCompletionCaptionSlim }
                } else {
                    VStack { Spacer(); goldenCompletionCaption }
                }
            }
            // Full-bleed title banner: painted sky fades into the map's fog.
            if Art.exists("map_banner") {
                VStack(spacing: 0) {
                    // Full-bleed, top-pinned on iPad (natural fitted height, 3.57:1).
                    // NOTE: never use `.frame(maxHeight: .infinity)` on a scaledToFit
                    // image — it expands the frame and centers the art vertically,
                    // floating the banner into the middle of the screen.
                    //
                    // iPhone landscape uses a SEPARATE, horizontally outpainted
                    // 5.57:1 asset. At the ~150pt cap the short screen needs (the
                    // full-width 3.57:1 art buries the top row of nodes), the
                    // original only spanned ~535pt of a 956pt screen and left bare
                    // map either side. Scaling it up to fill instead blew up the
                    // wordmark, so the art was widened rather than enlarged. 956/5.57
                    // ≈ 172, so width is the binding constraint and it reaches both
                    // edges. See scripts/outpaint-banner.py.
                    if compact {
                        Image("map_banner_wide").resizable().scaledToFit().frame(maxHeight: 175)
                    } else {
                        Image("map_banner").resizable().scaledToFit()
                    }
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea(edges: [.top, .horizontal])
                .allowsHitTesting(false)
                .saturation(sceneIsBW ? 0 : 1)
            }
            VStack { header; Spacer() }
            // Visual redesign: the reveal sequence's two lightning flashes —
            // a plain white layer on top of everything, driven by
            // `runRevealFlashes()`. Sits above the banner/header so it reads
            // as a flash over the whole scene.
            Color.white.opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        // In-hierarchy overlay, NOT a fullScreenCover: a cover's hosting layer
        // applies a lingering keyboard inset (keyboard still animating away
        // when a world is tapped right after name editing) that clips the
        // number pad off the bottom — and ignoresSafeArea(.keyboard) inside a
        // cover is ignored. Same lesson as PlayerProfileView.
        .overlay {
            if let sel = sessionWorld {
                SessionView(worldIndex: sel.id, speedRound: sel.speed, lightningRound: sel.lightning,
                            boss: sel.boss, golden: sel.golden, training: sel.training,
                            onTrain: { w in
                    // Close the current (golden) overlay, then reopen a
                    // training session on the same world once it's out of
                    // the way — "after the current overlay closes" (spec).
                    withAnimation(.easeOut(duration: 0.25)) { sessionWorld = nil }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        sessionWorld = WorldSelection(id: w, training: true)
                    }
                },
                            onClose: {
                    withAnimation(.easeOut(duration: 0.25)) { sessionWorld = nil }
                    checkUnlockReveal()
                })
                .environment(\.worldTheme, .forWorld(sel.id))
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showParent, onDismiss: {
            baselineCurrent = currentIndex
            #if DEBUG
            // The Golden Guardians Preview buttons in ParentAreaView's dev
            // pane mutate the profile while this map is live behind the
            // modal — resync here so the map lands correctly without a
            // relaunch. Release builds never compile this call: the dev
            // pane itself is #if DEBUG-gated, so nothing but this hook would
            // ever flip these flags outside of real gameplay anyway.
            syncGoldenPreviewState()
            #endif
        }) { ParentAreaView() }
        // In-hierarchy overlay, NOT a cover: the cover's hosting layer fights
        // the keyboard (see PlayerProfileView) — here the GUI stays frozen.
        // The map subtree has no text input of its own, so it ignores the
        // keyboard wholesale; without this the inset still squeezes the card.
        .overlay {
            if showProfile {
                PlayerProfileView(onClose: {
                    withAnimation(.easeOut(duration: 0.2)) { showProfile = false }
                })
                .transition(.opacity)
            }
        }
        .overlay {
            if showMapComplete {
                MapCompleteOverlay {
                    withAnimation(.easeOut(duration: 0.4)) { showMapComplete = false }
                    // Golden Guardians WP5 (spec acceptance 1): the map-
                    // complete takeover awards the certificate immediately —
                    // no mastery precondition. `-demoMapComplete` can show
                    // this overlay directly (skipping checkUnlockReveal), so
                    // mapCompleteCelebrated is set here too, guarded so the
                    // real gameplay path (already set before the overlay
                    // appeared) is a no-op.
                    if let p = profile, clearedSet.count == WorldCatalog.count, !p.mapCompleteCelebrated {
                        p.mapCompleteCelebrated = true
                        try? context.save()
                    }
                    // The phase-3 transform no longer runs here. It moves
                    // behind the certificate (spec acceptance 2: the golden
                    // map is revealed only after the completion celebration
                    // — which now includes the certificate — is dismissed).
                    // This flag is consumed by the certificate cover's
                    // onDismiss below, once, the first time this path fires.
                    if isGoldenEra, !revealGoldenMap {
                        pendingFirstTransform = true
                    }
                    showCertificate = true
                }
                .transition(.opacity)
            }
        }
        .overlay {
            if showGuardiansAssemble {
                GuardiansAssembleOverlay {
                    withAnimation(.easeOut(duration: 0.4)) { showGuardiansAssemble = false }
                    // Visual redesign, phase 4 beat 4: the finale color
                    // flood — the whole scene's saturation returns (and
                    // GoldenMapTint fades back in with it) once the takeover
                    // is dismissed. The certificate (which also gains its
                    // gold seal here — CertificateView derives that from the
                    // profile) follows once the flood is visible, not
                    // instantly, so the flood actually gets seen.
                    if let p = profile {
                        p.guardiansColorFloodPlayed = true
                        try? context.save()
                    }
                    if reduceMotion {
                        sceneColorRestored = true
                        showCertificate = true
                    } else {
                        withAnimation(.easeInOut(duration: 1.2)) { sceneColorRestored = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            showCertificate = true
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: sessionWorld != nil)
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showStreak) { StreakView() }
        .fullScreenCover(isPresented: $showTimesTable) { TimesTableView() }
        // Full-screen, not a sheet: a sheet wrapped the gilded art in a white
        // card and pinned it to the system form-sheet size on iPad. No text
        // input here, so the keyboard-inset caveat that rules out covers for
        // sessions does not apply.
        .fullScreenCover(isPresented: $showCertificate, onDismiss: {
            // Golden Guardians WP5: the phase-3 map transform runs here, once
            // the certificate that was awarded on map completion is
            // dismissed — never before or during it (spec acceptance 2).
            // `pendingFirstTransform` is only ever set on that first award
            // path (see the map-complete overlay above), so the trophy-
            // button reopen and the phase-4 gold-seal reopen never replay it.
            guard pendingFirstTransform else { return }
            pendingFirstTransform = false
            guard isGoldenEra, !revealGoldenMap else { return }
            // Visual redesign: the reveal sequence — two quick lightning
            // flashes, then the scene desaturates to B&W over ~0.8s while the
            // seven guardians slam in staggered, all gold, on their grayscale
            // circles. Reduced Motion skips straight to the settled state:
            // no flashes, no slam, B&W scene with gold guardians at rest.
            guard !reduceMotion else { revealGoldenMap = true; return }
            runRevealFlashes {
                playTransformAnimation = true
                withAnimation(.easeIn(duration: 0.8)) { revealGoldenMap = true }
            }
        }) {
            // Golden Guardians phase 4, beat 2: once every world is gilded,
            // the certificate the child already owns gains a gold seal —
            // upgrading something he possesses rather than granting a new
            // thing. Derived from profile state so every path that opens the
            // certificate (trophy button, the assemble overlay dismissing,
            // -autostartCertificate) reflects it automatically.
            CertificateView(name: profile?.name ?? "Champion", goldSeal: allGilded)
        }
        .onAppear {
            baselineCurrent = currentIndex
            // Already in the golden era at launch (a later session, or
            // -demoGoldenEra): render golden immediately with no animation —
            // the transform only ever plays once, right after the map-
            // complete overlay is freshly dismissed (see that overlay below).
            if isGoldenEra {
                revealGoldenMap = true
                // Statically settle the finale flood too if it already played
                // in an earlier session — otherwise this launch is caught
                // between the assemble takeover and its dismissal (or is
                // `-gildWorlds 127` demoing that exact moment), and the flood
                // is still owed live, once the takeover below is dismissed.
                sceneColorRestored = profile?.guardiansColorFloodPlayed ?? false
            }
            // Recovery path (see checkGuardiansAssemble's doc comment): covers
            // both a relaunch between the seventh gild and the celebration,
            // and `-demoGoldenEra -gildWorlds 127` showing the takeover
            // straight from launch.
            checkGuardiansAssemble()
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-autostartSession") { sessionWorld = WorldSelection(id: currentIndex) }
            // Repro for the clipped-pad bug: open the profile name editor
            // (keyboard up, pair with -editName), then start a session while
            // the keyboard is still animating away — the exact race kids hit.
            if args.contains("-demoKeyboardSession") {
                showProfile = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    showProfile = false
                    sessionWorld = WorldSelection(id: currentIndex)
                }
            }
            if args.contains("-autostartParent") { showParent = true }
            // Boss Gallery lives one level deeper, behind the parent gate's dev
            // card — ParentAreaView's own onAppear checks this same flag to
            // unlock dev mode and open the gallery once it's on screen.
            if args.contains("-autostartBossGallery") { showParent = true }
            if args.contains("-autostartProfile") { showProfile = true }
            if args.contains("-autostartStreak") { showStreak = true }
            if args.contains("-autostartTimesTable") { showTimesTable = true }
            if args.contains("-demoMapComplete") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { showMapComplete = true }
            }
            if args.contains("-autostartCertificate") { showCertificate = true }
            if args.contains("-autostartSpeed") { sessionWorld = WorldSelection(id: currentIndex, speed: true) }
            if args.contains("-autostartLightning") || args.contains("-demoLightningResults") {
                sessionWorld = WorldSelection(id: currentIndex, lightning: true)
            }
            if args.contains("-autostartBoss") { sessionWorld = WorldSelection(id: currentIndex, boss: true) }
            if args.contains("-autostartGolden") {
                var w = currentIndex
                if let i = args.firstIndex(of: "-goldenWorld"), i + 1 < args.count, let n = Int(args[i + 1]) {
                    w = n
                }
                sessionWorld = WorldSelection(id: w, golden: true)
            }
            // Demo: play the fog-lift reveal on the current node (pair with -demoProgress).
            if args.contains("-demoReveal") { revealWorld = currentIndex }
        }
    }

    // MARK: Backdrop

    private var mapBackdrop: some View {
        ZStack {
            if Art.exists("map_bg") {
                // Contained fill (see WorldBackdrop): keeps the image's overflow
                // out of layout so 4:3 screens don't push siblings off-screen.
                Color.clear
                    .overlay(Image("map_bg").resizable().scaledToFill())
                    .clipped()
            } else {
                LinearGradient(colors: [Theme.Color.bg, Theme.Color.primary.opacity(0.25)],
                               startPoint: .top, endPoint: .bottom)
            }
            Color.black.opacity(0.10)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            // Player chip: dark glass to match the session plates. Tapping it
            // opens the kid's trophy-room profile.
            Button { withAnimation(.easeOut(duration: 0.2)) { showProfile = true } } label: {
                HStack(spacing: 10) {
                    AvatarBadge(key: profile?.avatarSymbol ?? "avatar1", size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile?.name ?? "Player").font(Theme.Font.display(16)).foregroundStyle(.white)
                        HStack(spacing: 3) {
                            // Gem, not star: stars are world progress, XP is treasure.
                            Image(systemName: "diamond.fill").font(.system(size: 9))
                                .foregroundStyle(Theme.Color.accent)
                            Text("\(profile?.totalXP ?? 0) XP")
                                .font(Theme.Font.label(12)).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.vertical, 7).padding(.horizontal, 9).padding(.trailing, 7)
                .darkPlate(corner: 27)
            }
            .buttonStyle(PopButtonStyle())
            .accessibilityLabel("My profile")
            Spacer()
            // Title lives in the full-bleed banner; fall back to the floating
            // logo or text when banner art is absent.
            if !Art.exists("map_banner") {
                if Art.exists("map_header") {
                    Image("map_header").resizable().scaledToFit()
                        .frame(height: 118)
                        .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
                } else {
                    Text("Multiplication Adventure")
                        .font(Theme.Font.display(20)).foregroundStyle(.white).shadow(radius: 3)
                        .padding(.top, 10)
                }
                Spacer()
            }
            // Golden Guardians WP5 (spec acceptance 1): the trophy button
            // gates on MAP CONQUEST, not mastery — beating the map awards
            // the certificate immediately, with no fact-mastery precondition.
            if clearedSet.count == WorldCatalog.count {
                Button { showCertificate = true } label: {
                    Image(systemName: "trophy.fill").font(.system(size: 19))
                        .foregroundStyle(Theme.Color.accent)
                        .frame(width: 44, height: 44).darkPlate(corner: 22)
                }
                .accessibilityLabel("Certificate")
            }
            if canSpeedRound {
                Button { sessionWorld = WorldSelection(id: currentIndex, speed: true) } label: {
                    Label("Speed", systemImage: "timer").font(Theme.Font.label(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13).frame(height: 44).darkPlate(corner: 22)
                }
            }
            if canLightning {
                Button { sessionWorld = WorldSelection(id: currentIndex, lightning: true) } label: {
                    Label("Lightning", systemImage: "bolt.fill").font(Theme.Font.label(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13).frame(height: 44).darkPlate(corner: 22)
                }
            }
            // Times-table reference — a lookup chart, deliberately map-only so
            // it's never available mid-quest.
            Button { showTimesTable = true } label: {
                Text("Times Table")
                    .font(Theme.Font.label(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13).frame(height: 44).darkPlate(corner: 22)
            }
            .buttonStyle(PopButtonStyle())
            .accessibilityLabel("Times tables")
            if let p = profile {
                // The daily flame: lit = today's quest done; dim = not yet today.
                // Tapping opens the streak calendar.
                let practicedToday = p.lastPracticeDate.map { Calendar.current.isDateInToday($0) } ?? false
                Button { showStreak = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(practicedToday ? Theme.Color.accent : Color.white.opacity(0.3))
                        if p.streakDays > 0 {
                            Text("\(p.streakDays)").font(Theme.Font.number(16))
                                .foregroundStyle(practicedToday ? .white : .white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 13).frame(height: 44).darkPlate(corner: 22)
                }
                .buttonStyle(PopButtonStyle())
                .accessibilityLabel(practicedToday
                    ? "Streak \(p.streakDays) days, practiced today"
                    : "Not practiced yet today")
            }
            Button { showParent = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 19))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44).darkPlate(corner: 22)
            }
            .accessibilityLabel("Parent area")
        }
        .padding(.horizontal, Theme.Metric.pad).padding(.top, 10)
    }

    // MARK: Node

    @ViewBuilder
    private func nodeView(_ world: World) -> some View {
        let unlocked = world.index <= currentIndex
        let cleared = clearedSet.contains(world.index)
        let isCurrent = world.index == currentIndex
        let goal = profile?.starsPerWorldGoal ?? WorldCatalog.starsPerWorld
        let starsHere = isCurrent ? (profile?.starsInCurrentWorld ?? 0) : (cleared ? goal : 0)
        // All sockets filled but boss unbeaten → the node IS the boss fight.
        let bossReady = isCurrent && !cleared && starsHere == goal
        let badgeD: CGFloat = compact ? 82 : 104
        // Golden Guardians phase 3: only true once the transform is allowed
        // to be visible (never before/during the map-complete overlay).
        let golden = isGoldenEra && revealGoldenMap
        VStack(spacing: 5) {
            Button {
                if isGoldenEra { sessionWorld = WorldSelection(id: world.index, golden: true) }
                else if bossReady { sessionWorld = WorldSelection(id: world.index, boss: true) }
                else if unlocked { sessionWorld = WorldSelection(id: world.index) }
                else { nudgeLocked(world.index) }
            } label: {
                ZStack {
                    if golden {
                        GuardianBadge(index: world.index,
                                      gilded: profile?.isGilded(world.index) ?? false,
                                      diameter: badgeD, animate: playTransformAnimation)
                    } else if unlocked {
                        if world.index == revealWorld {
                            UnlockRevealNode(index: world.index, diameter: badgeD) { revealWorld = nil }
                        } else {
                            UnlockedBadge(index: world.index, diameter: badgeD)
                        }
                    } else {
                        LockedNodeView(diameter: badgeD)
                    }
                    // The pulsing "current world" ring is meaningless once the
                    // map is golden (every world is long since cleared), so
                    // it's suppressed here rather than parking forever on
                    // whichever world happened to be last.
                    if isCurrent, !golden { PulsingRing(diameter: badgeD * 1.19) }
                    // The green cleared-seal is the OLD map's language; on the
                    // golden map the node circle's color is the progress
                    // signal (grayscale = challenge waiting, restored color
                    // = conquered — see GuardianNodeBadge), so the seal would
                    // only dilute "countable at a glance".
                    if cleared, !golden {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: compact ? 21 : 26))
                            .foregroundStyle(Theme.Color.correct)
                            .background(Circle().fill(.white).frame(width: compact ? 19 : 24, height: compact ? 19 : 24))
                            .offset(x: badgeD * 0.37, y: -badgeD * 0.37)
                    }
                }
            }
            .buttonStyle(PopButtonStyle())
            .modifier(Shake(animatableData: world.index == shakeTarget ? shakePhase : 0))

            if golden {
                // Golden Guardians phase 3: the world's tables are true labels
                // only from here on (post-transform practice is world-scoped —
                // see docs/golden-guardians-spec.md Phase 3). A compact
                // two-line stack keeps this the same footprint as the star
                // row + name capsule it replaces, so it still fits both the
                // iPad layout and the tight iPhone-landscape trail.
                goldenLabel(world, conquered: profile?.isGilded(world.index) ?? false)
            } else if unlocked {
                // Star sockets — one star per completed quest; cleared worlds
                // always wear the full set.
                WorldStars(filled: starsHere, total: goal, size: compact ? 15 : 19, spacing: 4)
                    .padding(.horizontal, 9).padding(.vertical, compact ? 3 : 4)
                    .background(Capsule().fill(.black.opacity(0.45)))
                    .padding(.top, 2)
                Text(world.name)
                    .font(Theme.Font.label(compact ? 11 : 13)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(compact ? 0.7 : 1)
                    .padding(.horizontal, 10).padding(.vertical, compact ? 3 : 4)
                    .background(Capsule().fill(.black.opacity(0.5)))
            }
            if bossReady {
                Label("BOSS CHALLENGE!", systemImage: "flag.checkered")
                    .font(Theme.Font.label(10)).tracking(1)
                    .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(
                        LinearGradient(colors: [Color(red: 0.85, green: 0.25, blue: 0.2),
                                                Color(red: 0.6, green: 0.1, blue: 0.15)],
                                       startPoint: .top, endPoint: .bottom)))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            } else if isCurrent, !cleared {
                let remaining = goal - starsHere
                let resumable = (profile?.pausedQuestDate).map {
                    Calendar.current.isDateInToday($0)
                } ?? false
                Text(resumable ? "CONTINUE QUEST!"
                     : starsHere > 0 && remaining > 0
                     ? "\(remaining) STAR\(remaining == 1 ? "" : "S") TO THE BOSS!" : "TAP TO PLAY")
                    .font(Theme.Font.label(10)).tracking(1)
                    .foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.Color.primary))
            }
            if hintNode == world.index {
                Text("Clear \(WorldCatalog.worlds[safe: currentIndex]?.name ?? "the current world") first!")
                    .font(Theme.Font.label(11)).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.Color.primary))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .frame(width: compact ? 124 : 150)
        .animation(Theme.Motion.snappy, value: hintNode)
    }

    /// Golden Guardians node caption (visual redesign): the BOSS NAME over an
    /// explicit challenge/conquered line — "Storm Titan" / "×8 Challenge",
    /// flipping to "×8 Conquered!" once that world's guardian is gilded.
    /// Table numbers only, never a fact count or fraction (spec: no
    /// child-facing numbers on the map).
    @ViewBuilder
    private func goldenLabel(_ world: World, conquered: Bool) -> some View {
        VStack(spacing: 1) {
            Text(world.bossName)
                .font(Theme.Font.label(compact ? 11 : 13)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(Self.tableChallengeLabel(WorldCatalog.tables(inWorld: world.index), conquered: conquered))
                .font(Theme.Font.label(compact ? 9 : 11)).foregroundStyle(Color(red: 1, green: 0.86, blue: 0.55))
                .lineLimit(1).minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 10).padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(.black.opacity(0.55)))
    }

    /// "×8 Challenge" / "×3 & ×4 Challenge" / "×0–2 & ×10 Challenge" (Highland
    /// Trail's four tables compress a run of three-or-more consecutive
    /// numbers into a dash range; the spec's own examples never compress a
    /// run of two — "×3 & ×4", not "×3–4"). Conquered worlds get the same
    /// compression with the verb flipped: "×8 Conquered!". Real multiplication
    /// sign, word-form nowhere else needed since these are table numbers.
    private static func tableChallengeLabel(_ tables: [Int], conquered: Bool) -> String {
        let sorted = tables.sorted()
        guard !sorted.isEmpty else { return "" }
        var groups: [String] = []
        var i = 0
        while i < sorted.count {
            var j = i
            while j + 1 < sorted.count, sorted[j + 1] == sorted[j] + 1 { j += 1 }
            if j - i >= 2 {
                groups.append("×\(sorted[i])–\(sorted[j])")
            } else {
                for k in i...j { groups.append("×\(sorted[k])") }
            }
            i = j + 1
        }
        let joined = groups.count <= 1
            ? (groups.first ?? "")
            : groups.dropLast().joined(separator: ", ") + " & " + groups.last!
        return "\(joined) \(conquered ? "Conquered!" : "Challenge")"
    }

    /// Golden Guardians phase 4, beat 3: iPad/landscape-regular reading of the
    /// quiet completion caption (see the `isGoldenEra`/`allGilded` guard above).
    private var goldenCompletionCaption: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 16))
                .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.55))
            Text("Seven Worlds conquered · Adventure complete")
                .font(Theme.Font.label(14)).tracking(1)
                .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.55))
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .darkPlate()
        .padding(.bottom, 16)
        .accessibilityLabel("Seven Worlds conquered. Adventure complete.")
    }

    /// iPhone-landscape reading: the ~35pt strip below the node labels,
    /// single-row and compact to match the map's other iPhone chrome.
    private var goldenCompletionCaptionSlim: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 12))
                .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.55))
            Text("Seven Worlds conquered · Adventure complete")
                .font(Theme.Font.label(10)).tracking(0.5)
                .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.55))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .darkPlate(corner: 16)
        .padding(.bottom, 3)
        .accessibilityLabel("Seven Worlds conquered. Adventure complete.")
    }

    /// Visual redesign: the reveal sequence's opening beat — two quick white
    /// full-screen pulses (~0.12s each, a short gap between), each paired
    /// with the `phaseJolt` haptic/SFX (an existing "electric zap" effect —
    /// no new audio asset needed). Calls `completion` once both have
    /// finished, so the caller can chain the B&W desaturation + guardian
    /// slam-in that follow. Only ever called on the live, non-Reduced-Motion
    /// path (see the certificate's `onDismiss`).
    private func runRevealFlashes(completion: @escaping () -> Void) {
        func pulse(at delay: Double) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Feedback.fire(.phaseJolt)
                withAnimation(.easeOut(duration: 0.06)) { flashOpacity = 0.9 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(.easeIn(duration: 0.06)) { flashOpacity = 0 }
                }
            }
        }
        pulse(at: 0)
        pulse(at: 0.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { completion() }
    }

    /// A tap on a fogged node shouldn't feel broken: wiggle it and say what unlocks it.
    private func nudgeLocked(_ index: Int) {
        Feedback.fire(.keyTap)
        hintNode = index
        if !reduceMotion {
            shakeTarget = index
            withAnimation(.easeInOut(duration: 0.45)) { shakePhase += 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if hintNode == index { hintNode = nil }
        }
    }

    /// Called when a session cover closes: if the trail advanced, run the fog-lift
    /// reveal on the newly reachable world.
    private func checkUnlockReveal() {
        // Boss 7 just fell → the whole map is beaten: one-time takeover.
        if clearedSet.count == WorldCatalog.count,
           let p = profile, !p.mapCompleteCelebrated {
            p.mapCompleteCelebrated = true
            withAnimation(.easeOut(duration: 0.3)) { showMapComplete = true }
            return
        }
        let now = currentIndex
        if now > baselineCurrent, !clearedSet.contains(now) {
            revealWorld = now
        }
        baselineCurrent = now
        // Golden Guardians phase 4, beat 1: the seventh gild can only happen
        // inside a golden fight, so this is the real trigger path — the fight
        // just ended, the session overlay is already closing (sessionWorld is
        // nil by the time onClose calls this), and clearedSet/mapComplete are
        // already settled from the branch above.
        checkGuardiansAssemble()
    }

    /// Fires the one-time "guardians assemble" takeover the moment every
    /// world is gilded. Called from the real gameplay path
    /// (`checkUnlockReveal`, right after a golden fight closes) and from
    /// `.onAppear` as a recovery path — the app can be relaunched between the
    /// seventh gild and the celebration (or launched straight into it via
    /// `-demoGoldenEra -gildWorlds 127`, since `-gildWorlds` only sets the
    /// mask and never the celebrated flag). Guarded so it can never fire
    /// while the map-complete takeover is up or a session is open.
    private func checkGuardiansAssemble() {
        guard let p = profile, isGoldenEra, allGilded, !p.guardiansAssembleCelebrated,
              !showMapComplete, sessionWorld == nil else { return }
        p.guardiansAssembleCelebrated = true
        try? context.save()
        withAnimation(.easeOut(duration: 0.3)) { showGuardiansAssemble = true }
    }

    // MARK: Dev-only: Golden Guardians Preview sync
    //
    // Debug builds only. ParentAreaView's dev pane can rewrite the active
    // profile's golden-era flags (award/gild/finale/reset) while this map is
    // still on screen behind the Parent Area modal — none of that flows
    // through the normal gameplay triggers (a session closing, boss falling,
    // etc.), so without this the map would sit stale until relaunch. This
    // is purely a RESYNC: it follows whatever the profile now says, using
    // the exact same one-time-flag-guarded paths real gameplay uses
    // (`checkUnlockReveal`/`checkGuardiansAssemble`) so a takeover can only
    // fire once, and settles `revealGoldenMap`/`sceneColorRestored`
    // statically (no reveal animation) exactly like `.onAppear` already does
    // for "already in the golden era at launch" — never a new transform
    // replay. Safe to call after any of the five preview buttons, in any
    // order, since each of them already reseeds its own flags fully.
    #if DEBUG
    private func syncGoldenPreviewState() {
        if isGoldenEra {
            // Static settle, matching `.onAppear`'s "already golden at
            // launch" branch — not the animated reveal sequence, which only
            // ever plays from the certificate's onDismiss right after a
            // fresh map-complete award.
            revealGoldenMap = true
            sceneColorRestored = profile?.guardiansColorFloodPlayed ?? false
        } else {
            // Reset to mid-game (or any non-golden state): no golden
            // leftovers on the live map.
            revealGoldenMap = false
            sceneColorRestored = false
            playTransformAnimation = false
        }
        // Real-gameplay paths: fire the map-complete takeover if the profile
        // now reads "map beaten, not yet celebrated" (the award-ceremony
        // button), and the assemble takeover if it reads "all seven gilded,
        // not yet celebrated" (the finale button). Both are no-ops when
        // their guard flag is already true, so calling them after every
        // button press is harmless.
        checkUnlockReveal()
        checkGuardiansAssemble()
    }
    #endif
}

/// The standard unlocked world badge on the map.
private struct UnlockedBadge: View {
    let index: Int
    var diameter: CGFloat = 104
    var body: some View {
        WorldNodeBadge(theme: .forWorld(index))
            .frame(width: diameter, height: diameter).clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: diameter > 95 ? 4 : 3))
            .shadow(color: .black.opacity(0.4), radius: 7, y: 3)
    }
}

/// Golden Guardians map node (visual redesign). Wraps `GuardianNodeBadge`
/// (always gold; the conquered/challenge signal lives in its own circle
/// background) and, when `animate` is true, plays the one-time reveal:
/// the guardian slams in — scale ~1.5→1.0 + opacity, spring — staggered
/// per node (~0.12s apart) so the seven don't all land at once. `animate`
/// is false on every launch except the moment right after the reveal
/// sequence's flash+desaturate beats fire (see MapView's certificate
/// `onDismiss`), so a later launch in the golden era just renders the
/// guardian directly at rest.
private struct GuardianBadge: View {
    let index: Int
    let gilded: Bool
    var diameter: CGFloat = 104
    var animate: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        GuardianNodeBadge(theme: .forWorld(index), gilded: gilded, diameter: diameter)
            .scaleEffect(revealed ? 1 : 1.5)
            .opacity(revealed ? 1 : 0)
            .onAppear {
                guard animate, !reduceMotion else { revealed = true; return }
                let stagger = Double(index) * 0.12
                withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(stagger)) {
                    revealed = true
                }
            }
    }
}

/// The finale's "same map at golden hour" atmosphere: a low-opacity warm
/// gradient scrim over the whole map. Tasteful on purpose — this sits well
/// under the node art and trail, not a yellow filter over everything. Only
/// shown once the scene's color has returned (see `sceneColorRestored` in
/// MapView) — it fights the golden era's pre-finale grayscale, so it's
/// withheld until then.
private struct GoldenMapTint: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 1, green: 0.78, blue: 0.35).opacity(0.20),
                                Color(red: 0.85, green: 0.55, blue: 0.15).opacity(0.10),
                                .clear],
                       startPoint: .top, endPoint: .bottom)
            .blendMode(.overlay)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

/// Fogged, unknown world node. The smoke art deliberately billows beyond the
/// 104pt node footprint, so it renders larger without shifting the node's center.
private struct LockedNodeView: View {
    var diameter: CGFloat = 104
    var body: some View {
        ZStack {
            if Art.exists("node_locked") {
                Image("node_locked").resizable().scaledToFit()
                    .frame(width: diameter * 1.33, height: diameter * 1.33)
            } else {
                Circle().fill(Color.gray.opacity(0.5)).frame(width: diameter * 0.92, height: diameter * 0.92)
            }
            Image(systemName: "questionmark").font(.system(size: diameter * 0.31, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.6), radius: 3)
        }
        .frame(width: diameter, height: diameter)   // layout footprint stays the node size
    }
}

/// The fog-lift moment: the locked node swells and dissolves while the world badge
/// springs in underneath. Plays the unlock sound; respects Reduced Motion.
private struct UnlockRevealNode: View {
    let index: Int
    var diameter: CGFloat = 104
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            UnlockedBadge(index: index, diameter: diameter)
                .opacity(revealed ? 1 : 0)
                .scaleEffect(reduceMotion ? 1 : (revealed ? 1 : 0.35))
            LockedNodeView(diameter: diameter)
                .opacity(revealed ? 0 : 1)
                .scaleEffect(reduceMotion || !revealed ? 1 : 1.5)
                .blur(radius: reduceMotion || !revealed ? 0 : 14)
            // The fog physically billows away as the world appears underneath.
            ParticleBurst(kind: .smoke, colors: [.white, Color(white: 0.82)],
                          seed: UInt64(index) &* 7919 &+ 5)
                .frame(width: 260, height: 260)
        }
        .onAppear {
            Feedback.fire(.levelUp)
            withAnimation(reduceMotion ? Theme.Motion.quick
                          : .spring(response: 0.7, dampingFraction: 0.55).delay(0.45)) {
                revealed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { onDone() }
        }
    }
}


/// A dashed trail connecting the node positions.
private struct TrailPath: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for pt in points.dropFirst() { p.addLine(to: pt) }
        return p
    }
}

/// A pulsing ring marking the current world (respects Reduced Motion).
private struct PulsingRing: View {
    var diameter: CGFloat = 124
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    var body: some View {
        Circle()
            .strokeBorder(Theme.Color.accent, lineWidth: 5)
            .frame(width: diameter, height: diameter)
            .scaleEffect(animate && !reduceMotion ? 1.14 : 1.0)
            .opacity(animate && !reduceMotion ? 0.2 : 0.9)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { animate = true }
            }
    }
}

/// Wrapper so `fullScreenCover(item:)` can carry a world index + how to start it.
/// `boss` runs the world's boss challenge; `speed` a Speed Round; `lightning` a
/// True/False Lightning Round; `testFormat` forces a question format (dev/testing).
struct WorldSelection: Identifiable {
    let id: Int
    var speed: Bool = false
    var lightning: Bool = false
    var boss: Bool = false
    /// A Golden Guardian fight (Golden Guardians, phase 3) — entered directly,
    /// no menu, once the profile is in the golden era.
    var golden: Bool = false
    /// "Train the Ns first" — offered when a golden fight is lost.
    var training: Bool = false
    var testFormat: MasteryStage? = nil
}
