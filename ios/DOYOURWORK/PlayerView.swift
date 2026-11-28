import SwiftUI
import DoYourWorkCore

/// Someone's profile, opened from their family tile: their day (pick a card, check it off, submit,
/// then optionally a bonus round), with a way to dare them, and on your own, to change your look.
struct PlayerView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let player: Player
    /// Back to the family. Nil where there's nothing to go back to.
    var onBack: (() -> Void)?
    /// Dare this person. Nil when you can't (an unlinked phone, or your own profile).
    var onDare: (() -> Void)?
    /// Change this person's photo and border, in settings. Nil on someone else's profile.
    var onEditLook: (() -> Void)?
    @State private var bonusPicking = false
    @State private var editingDisplayName = false
    @State private var displayNameDraft = ""

    var body: some View {
        let card = store.card(for: player.id)
        let todays = store.todaysLogs(player.id)
        let statusToday = Engine.statusToday(todays)
        // Used up for today: awaiting an admin, approved, or on the card and not yet submitted.
        // A rejected chore isn't — it can be done again.
        // One chore, one person, per day: what the other players have in today.
        let others = store.takenByOthers(player.id)
        let taken = Engine.standingToday(statusToday).union((card?.choreIds ?? []).filter { statusToday[$0] == nil }).union(others.keys)
        VStack(spacing: 0) {
            // Who this is: their face, name and this week's points, then their version and streak,
            // on a rounded card of the theme's main colour.
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    // Leaving the bonus picker always needs a way back.
                    if bonusPicking || onBack != nil {
                        Button { fb.tap(); if bonusPicking { bonusPicking = false } else { onBack?() } } label: {
                            Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).frame(width: 32, height: 44)
                        }
                        .accessibilityLabel("Back").accessibilityIdentifier("back")
                    }
                    AvatarView(player: player, size: 64).frame(width: 52, height: 56).offset(y: -4)
                    VStack(alignment: .leading, spacing: 0) {
                        // Their own nickname, their own call: no admin needed, and it can't change the
                        // username their points are kept under.
                        Button {
                            fb.tap(); displayNameDraft = player.displayName ?? ""; editingDisplayName = true
                        } label: {
                            Text(bonusPicking ? "\(store.shownName(player)) · bonus" : store.shownName(player))
                                .font(.app(.title3)).fontWeight(.black).lineLimit(1).minimumScaleFactor(0.6)
                        }
                        .buttonStyle(.plain).disabled(bonusPicking)
                        .accessibilityHint("Changes your display name")
                        Text("\(store.rank(player.id).version) · \(Phrase.count(store.weekPoints(player.id), "point")) this week").font(.app(.caption)).fontWeight(.semibold).opacity(0.85)
                    }
                    Spacer(minLength: 8)
                    if !bonusPicking {
                        if let onEditLook {
                            Button { fb.tap(); onEditLook() } label: {
                                Image(systemName: "camera.fill").font(.system(size: 15, weight: .bold)).frame(width: 40, height: 40)
                                    .background(Palette.heat.ink.opacity(0.18), in: Circle())
                            }
                            .accessibilityLabel("Photo and border").accessibilityIdentifier("edit-look")
                        }
                        if let onDare {
                            Button { fb.tap(); onDare() } label: {
                                Label("Dare", systemImage: "bolt.fill").font(.app(.footnote)).fontWeight(.bold)
                                    .padding(.horizontal, 12).frame(height: 40)
                                    .background(Palette.heat.ink.opacity(0.18), in: Capsule())
                            }
                            .accessibilityLabel("Dare \(store.shownName(player))").accessibilityIdentifier("dare-person")
                        }
                    }
                }
                CompactStats(rank: store.rank(player.id), streak: store.streak(player.id))
            }
            .foregroundStyle(Palette.heat.ink).tint(Palette.heat.ink)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Palette.heat.stops[0], in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16).padding(.bottom, 4)

            if let card {
                if bonusPicking {
                    PickerView(pool: store.pickable(player.id).filter { !taken.contains($0.id) }, bonus: true) { chosen in
                        store.logBonus(player, chosen); fb.submit(); bonusPicking = false
                    }
                } else {
                    CardRunView(player: player, card: card, todays: todays, others: others,
                                bonusLeft: store.pool.filter { !taken.contains($0.id) }.count) { bonusPicking = true }
                }
            } else {
                PickerView(pool: store.pickable(player.id).filter { others[$0.id] == nil }, bonus: false,
                           notes: (store.rejectedToday(player.id) ? ["Today's earlier chores were turned down, so let's build a new card."] : [])
                               + (others.isEmpty ? [] : ["Someone else already has \(others.count == 1 ? "one" : "\(others.count)") of today's chores."])) { chosen in
                    store.lockIn(player, chosen); fb.lockIn()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Display name", isPresented: $editingDisplayName) {
            TextField("Anything you like", text: $displayNameDraft)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save") { store.setDisplayName(player.id, displayNameDraft) }
            Button("Use my username", role: .destructive) { store.setDisplayName(player.id, "") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Shown in place of your username, \(player.name). Your chores and points stay exactly as they are. Up to \(DisplayName.maxLength) characters.")
        }
    }
}

private struct PickerView: View {
    @EnvironmentObject var fb: Feedback
    let pool: [EnrichedChore]
    let bonus: Bool
    /// Shown above the list when there's something the player should know before picking.
    var notes: [String] = []
    let onConfirm: ([EnrichedChore]) -> Void
    @State private var picked: [String] = []
    @State private var suggested: Set<String> = []

    var body: some View {
        let chosen = pool.filter { picked.contains($0.id) }
        let total = chosen.reduce(0) { $0 + $1.currentMinutes }
        let remaining = bonus ? Int.max : Engine.dailyMinutes - total
        let ready = Engine.cardReady(chosen: chosen, pool: pool, bonus: bonus)
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    Text(bonus ? "Did a bit extra today? Pick what you did. Every chore still earns its points." : "Pick what you'd like to do today, then fill it up to \(Engine.dailyMinutes) minutes.")
                        .font(.app(.callout)).foregroundStyle(Color.done).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.vertical, 14)
                    ForEach(notes, id: \.self) { note in
                        Text(note).font(.app(.footnote)).foregroundStyle(Theme.warn).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 10)
                    }
                    LazyVGrid(columns: ChoreTile.columns, spacing: 10) {
                    ForEach(Array(pool.enumerated()), id: \.element.id) { i, c in
                        let isPicked = picked.contains(c.id)
                        ChoreTile(name: c.name, minutes: c.currentMinutes, escalLevel: c.escalLevel, checked: isPicked,
                                 index: i, count: pool.count, picking: true) {
                            if isPicked { fb.tick(false); picked.removeAll { $0 == c.id }; suggested.remove(c.id) }
                            else if c.currentMinutes <= remaining { fb.tick(true); picked.append(c.id); suggested.remove(c.id) }
                            else { fb.error() }
                        }
                    }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(bonus ? Phrase.count(total, "minute") : "\(total) of \(Engine.dailyMinutes) minutes").font(.app(.title3)).fontWeight(.black)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                if !bonus {
                    // How full the card is, as a strip of the gradient across the screen.
                    GeometryReader { g in
                        Rectangle().fill(LinearGradient(colors: Palette.heat.stops, startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * min(1, CGFloat(total) / CGFloat(Engine.dailyMinutes)))
                    }
                    .frame(height: 4).background(Color.surface)
                    .animation(.easeOut(duration: 0.2), value: total)
                    OutlineButton(label: chosen.isEmpty ? "Suggest a \(Engine.dailyMinutes)-minute card" : "Fill it up to \(Engine.dailyMinutes) minutes") {
                        fb.fill()
                        let next = Engine.suggestFill(pickedIds: picked, pool: pool)
                        suggested = suggested.intersection(next).union(next.filter { !picked.contains($0) })
                        picked = next
                    }
                }
                TermButton(label: ready ? (bonus ? "Log \(chosen.count == 1 ? "this chore" : "these \(chosen.count) chores")" : "Lock in my card")
                           : !chosen.isEmpty ? "Add a few more to reach \(Engine.dailyMinutes) minutes" : bonus ? "Pick the chores you did" : "Pick some chores, or let me suggest some",
                           enabled: ready) { onConfirm(chosen) }
            }
        }
        // Chime once when the card first becomes a full day.
        .onChange(of: ready) { _, now in if now && !bonus { fb.ready() } }
    }
}

private struct CardRunView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    let player: Player
    let card: Card
    let todays: [ChoreLog]
    /// Chores another player has in today: chore id → their name.
    let others: [String: String]
    let bonusLeft: Int
    let onBonus: () -> Void
    @State private var puzzleOpen = false
    @State private var snakeOpen = false

    var body: some View {
        let rank = store.rank(player.id)
        // Approved wins; otherwise the latest log for a chore decides, so one redone after a rejection is awaiting again.
        let statusByChore = Engine.statusToday(todays)
        // Chores logged today that aren't on the card: bonus-round ones still standing, and ones a
        // parent rejected (from the bonus round, or from an earlier card that was rejected outright).
        var seen = Set(card.choreIds)
        let extras = todays.filter { seen.insert($0.choreId).inserted }
        let bonusLogs = extras.filter { statusByChore[$0.choreId] != Status.rejected }
        let rejectedExtras = extras.filter { statusByChore[$0.choreId] == Status.rejected }
        // On a card that isn't submitted yet, a chore someone else got in first stays visible, marked
        // taken, and is left out when the card is submitted.
        let lost = card.submitted ? [] : card.choreIds.filter { others[$0] != nil }
        let keep = card.choreIds.indices.filter { !lost.contains(card.choreIds[$0]) }
        let allChecked = !keep.isEmpty && keep.allSatisfy { card.checked[$0] }

        // One gradient down the whole day: the card, then the bonus round, then anything rejected.
        let rows = card.choreIds.count + bonusLogs.count + (card.submitted ? rejectedExtras.count : 0)
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    SectionLabel("Today's card · \(Phrase.count(card.minutes.reduce(0, +), "minute"))")
                    LazyVGrid(columns: ChoreTile.columns, spacing: 10) {
                    ForEach(Array(card.choreIds.enumerated()), id: \.element) { i, id in
                        ChoreTile(name: store.choreName(id), minutes: card.minutes[i],
                                 escalLevel: i < card.escal.count ? card.escal[i] : 0, checked: card.checked[i],
                                 status: card.submitted ? (statusByChore[id] ?? Status.pending) : (lost.contains(id) ? ChoreTile.taken : nil),
                                 index: i, count: rows) {
                            fb.tick(!card.checked[i]); store.toggle(player, card, i)
                        }
                    }
                    }
                    .padding(.horizontal, 16)
                    if !bonusLogs.isEmpty {
                        SectionLabel("Bonus round")
                        LazyVGrid(columns: ChoreTile.columns, spacing: 10) {
                        ForEach(Array(bonusLogs.enumerated()), id: \.element.id) { i, l in
                            ChoreTile(name: l.choreName, minutes: Engine.choreMinutes(l, pool: store.poolById), checked: true, status: statusByChore[l.choreId],
                                     index: card.choreIds.count + i, count: rows)
                        }
                        }
                        .padding(.horizontal, 16)
                    }
                    // Kept off a card that's still being checked off, where it would only be in the way.
                    if card.submitted && !rejectedExtras.isEmpty {
                        SectionLabel("Turned down today")
                        LazyVGrid(columns: ChoreTile.columns, spacing: 10) {
                        ForEach(rejectedExtras) { l in
                            ChoreTile(name: l.choreName, minutes: Engine.choreMinutes(l, pool: store.poolById), checked: true, status: Status.rejected)
                        }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            VStack(alignment: .leading, spacing: 0) {
                if !card.submitted {
                    if !lost.isEmpty {
                        Text("Someone else got to the ones marked taken first, so they won't be sent.").font(.app(.footnote)).foregroundStyle(Color.done).padding(.horizontal, 20).padding(.bottom, 8)
                    }
                    TermButton(label: allChecked ? "Send it off for approval" : keep.isEmpty ? "Everything's been taken today. Change your picks" : "Check everything off first",
                               enabled: allChecked) {
                        store.submit(player, card); fb.submit()
                    }
                    HStack {
                        Text("The puzzle opens once you send your card.").font(.app(.footnote)).foregroundStyle(Color.done)
                        Spacer()
                        Button("Change my picks") { fb.tap(); store.clearCard(player) }.font(.app(.footnote)).fontWeight(.bold).foregroundStyle(Color.appText).frame(minHeight: 44)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // Say what's actually left: every chore logged today is pending, approved or rejected.
                    let verdicts = (card.choreIds + extras.map(\.choreId)).map { statusByChore[$0] ?? Status.pending }
                    let waiting = verdicts.filter { $0 == Status.pending }.count
                    let rejected = verdicts.filter { $0 == Status.rejected }.count
                    Group {
                        if waiting == verdicts.count { Text("Sent! Now it's waiting for an admin to look at it.").foregroundStyle(Color.done) }
                        else if waiting > 0 { Text("\(waiting) of \(verdicts.count) are still waiting for an admin.").foregroundStyle(Color.done) }
                        else if rejected == 0 { Text("Everything's approved. Nice work!").foregroundStyle(Theme.good) }
                        else if rejected == verdicts.count { Text("None of today's chores were approved.").foregroundStyle(Theme.bad) }
                        else { Text("\(verdicts.count - rejected) approved and \(rejected) turned down.").foregroundStyle(Color.done) }
                        if rejected > 0 {
                            Text("You can redo the turned-down ones in a bonus round.").font(.app(.footnote)).foregroundStyle(Color.done)
                        }
                    }
                    .font(.app(.callout)).fontWeight(.semibold).padding(.horizontal, 20).padding(.vertical, 10)
                    let minutesLeft = store.puzzleMinutesLeft(player.id)
                    if minutesLeft > 0 {
                        let level = store.puzzleLevel(player.id)
                        let best = store.snakeBest(player.id)
                        // The time left gets its own line, so each button is just its game.
                        Text("\(Phrase.count(minutesLeft, "minute")) of games left today").font(.app(.callout)).fontWeight(.semibold)
                            .foregroundStyle(Color.done).padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
                            .accessibilityIdentifier("games-time-left")
                        TermButton(label: "Clear the grid · level \(level)") { fb.unlock(); puzzleOpen = true }
                        // The second game, sharing the same 30 minutes.
                        OutlineButton(label: best > 0 ? "Eat the dots · best \(best)" : "Eat the dots") { fb.unlock(); snakeOpen = true }
                            .accessibilityIdentifier("play-snake")
                    } else {
                        Text("That's your 30 minutes of games for today. See you tomorrow!").foregroundStyle(Color.done).padding(.horizontal, 20).padding(.vertical, 18)
                    }
                    if bonusLeft > 0 { OutlineButton(label: "Do a bonus round") { fb.tap(); onBonus() } }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Celebrate the first time this screen shows a new version (approval may have happened elsewhere).
        .task(id: rank.level) { if store.isNewLevel(player.id, rank.level) { fb.levelUp() } }
        .fullScreenCover(isPresented: $puzzleOpen, onDismiss: { store.puzzleTimeShown() }) {
            PuzzleView(player: player).environmentObject(store).environmentObject(fb).font(.app(.body)).tint(Theme.accent)
        }
        .fullScreenCover(isPresented: $snakeOpen, onDismiss: { store.puzzleTimeShown() }) {
            SnakeView(player: player).environmentObject(store).environmentObject(fb).font(.app(.body)).tint(Theme.accent)
        }
    }
}

/// The xp bar with the streak and what's left to the next version, small enough that the chores
/// below get most of the screen.
private struct CompactStats: View {
    let rank: Rank
    let streak: Int
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.heat.ink.opacity(0.25))
                    Capsule().fill(Palette.heat.ink).frame(width: g.size.width * CGFloat(rank.pct) / 100)
                }
            }
            .frame(height: 5)
            .animation(.easeOut(duration: 0.7), value: rank.pct)
            HStack {
                Text(streak == 0 ? "No streak yet" : "\(streak)-day streak · \(String(format: "%.1f", Engine.momentumMult(streak)))x points")
                Spacer()
                Text("\(rank.into) of \(rank.need) xp to \(rank.nextVersion)")
            }
            .font(.app(.caption2)).fontWeight(.semibold).opacity(0.85)
        }
        .foregroundStyle(Palette.heat.ink)
    }
}
