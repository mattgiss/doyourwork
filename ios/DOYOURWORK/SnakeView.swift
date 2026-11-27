import SwiftUI
import DoYourWorkCore

/// The second reward game, "EAT THE DOTS": a snake-style game. Swipe anywhere to steer the line,
/// eat the dots to grow, and don't hit a wall or your own tail. It gets faster as it grows. It
/// shares the puzzle's 30 minutes a day, and each player's best score is kept on this phone.
struct SnakeView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var fb: Feedback
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var calm
    @Environment(\.scenePhase) private var scenePhase
    let player: Player

    @State private var game = SnakeGame(seed: UInt64.random(in: 1...UInt64.max))
    /// Set when the app goes to the background mid-game; the next swipe carries on.
    @State private var paused = false
    @State private var best = 0
    @State private var newBest = false
    @State private var showOver = false
    @State private var timeUp = false
    @State private var flash = 0.0
    @State private var shakeTrigger = 0
    /// Where the current swipe was last turned, so one long drag can steer more than once.
    @State private var dragFrom: CGPoint?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Text(hint)
                    .font(.app(.footnote)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.bottom, 4)
                GeometryReader { geo in
                    let cell = min(geo.size.width / CGFloat(game.width), geo.size.height / CGFloat(game.height))
                    boardView(cell)
                        .frame(width: cell * CGFloat(game.width), height: cell * CGFloat(game.height))
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .padding(20)
                Spacer().frame(height: 12)
            }
            .keyframeAnimator(initialValue: 0.0, trigger: shakeTrigger) { content, k in
                content.offset(x: CGFloat(k) * 10, y: CGFloat(-k) * 6)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1.0, duration: 0.035); LinearKeyframe(-0.8, duration: 0.035)
                    LinearKeyframe(0.55, duration: 0.035); LinearKeyframe(-0.3, duration: 0.035)
                    LinearKeyframe(0.0, duration: 0.035)
                }
            }
            // Swipe anywhere on the screen, not just the board: easier on a big tablet or an open fold.
            .contentShape(Rectangle())
            .gesture(swipe)
            .onTapGesture { carryOn() }
            Theme.accent.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
            if showOver {
                GameOverCard(won: game.status == .won, score: game.score, best: best, newBest: newBest,
                             onAgain: playAgain, onBack: { fb.tap(); dismiss() })
                    .transition(.opacity)
            }
            if timeUp { SnakeTimeUpCard(onBack: { fb.tap(); dismiss() }).transition(.opacity) }
        }
        // A hardware keyboard (iPad) steers with the arrow keys.
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            switch press.key {
            case .upArrow: steer(.up)
            case .downArrow: steer(.down)
            case .leftArrow: steer(.left)
            default: steer(.right)
            }
            return .handled
        }
        .onAppear { best = store.snakeBest(player.id); focused = true }
        .onChange(of: scenePhase) { _, phase in if phase != .active, game.status == .playing { paused = true } }
        // The game clock: one step every `stepMilliseconds`, only while the app is in front.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(game.stepMilliseconds))
                guard !paused, !timeUp, !showOver else { continue }
                if let event = game.step() { handle(event) }
            }
        }
        // The shared 30 minutes a day, counted the same way as the puzzle's.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            var last = Date()
            while !Task.isCancelled {
                if store.puzzleSecondsLeft(player.id) <= 0 { withAnimation { timeUp = true }; return }
                try? await Task.sleep(for: .seconds(1))
                let now = Date()
                store.playedPuzzle(player.id, seconds: min(now.timeIntervalSince(last), 2), now: now)
                last = now
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("Back") { fb.tap(); dismiss() }.fixedSize().accessibilityIdentifier("snake-back")
            Text("Eat the dots · best \(max(best, game.score))").font(.app(.caption)).kerning(3).foregroundStyle(.secondary).lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            Text("Score \(game.score)").font(.app(.headline)).foregroundStyle(Theme.accent).fixedSize()
                .accessibilityIdentifier("snake-score")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private var hint: String {
        if paused { return "Paused. Swipe to keep going." }
        if game.status == .ready { return "Swipe to steer. Eat the dots; don't hit the walls or your tail." }
        return "Swipe to steer."
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                let from = dragFrom ?? v.startLocation
                let dx = v.location.x - from.x, dy = v.location.y - from.y
                guard max(abs(dx), abs(dy)) >= 22 else { if dragFrom == nil { dragFrom = from }; return }
                steer(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up))
                dragFrom = v.location
            }
            .onEnded { _ in dragFrom = nil }
    }

    private func steer(_ d: SnakeGame.Direction) {
        guard !showOver, !timeUp else { return }
        paused = false
        if game.turn(d) { fb.tap() }
    }

    /// A tap starts a game that's waiting, or carries on after a pause.
    private func carryOn() {
        guard !showOver, !timeUp else { return }
        paused = false
        game.start()
    }

    private func handle(_ event: SnakeGame.Event) {
        switch event {
        case .moved: break
        case .ate: fb.puzzleSelect()
        case .died, .won:
            if event == .won { fb.levelUp() } else { fb.reject() }
            newBest = store.snakeFinished(player.id, score: game.score)
            best = store.snakeBest(player.id)
            if !calm { shakeTrigger += 1 }
            flash = calm ? 0.3 : 0.7
            withAnimation(.easeOut(duration: 0.45)) { flash = 0 }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                if newBest { fb.unlock() }
                withAnimation(.easeOut(duration: 0.2)) { showOver = true }
            }
        }
    }

    private func playAgain() {
        fb.tap()
        game = SnakeGame(seed: UInt64.random(in: 1...UInt64.max))
        paused = false
        newBest = false
        withAnimation(.easeOut(duration: 0.2)) { showOver = false }
    }

    // MARK: Board

    private func boardView(_ cell: CGFloat) -> some View {
        TimelineView(.animation(paused: game.food == nil || calm)) { tl in
            Canvas { ctx, size in
                draw(ctx, size: size, cell: cell, now: tl.date.timeIntervalSinceReferenceDate)
            }
        }
        .background(Color.primary.opacity(0.04))
        .overlay(Rectangle().strokeBorder(Color(.separator), lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel("Snake board, length \(game.length)")
        .accessibilityIdentifier("snake-board")
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize, cell: CGFloat, now: Double) {
        // A faint dot in each empty cell, like the puzzle's board.
        let dot = cell * 0.08
        for y in 0..<game.height {
            for x in 0..<game.width {
                let c = CGPoint(x: (CGFloat(x) + 0.5) * cell, y: (CGFloat(y) + 0.5) * cell)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - dot / 2, y: c.y - dot / 2, width: dot, height: dot)),
                         with: .color(Color(.separator)))
            }
        }
        if let f = game.food {
            // The dot breathes, so it's easy to spot.
            let pulse = calm ? 0 : (sin(now * 6) * 0.5 + 0.5)
            let side = cell * (0.62 + 0.12 * pulse)
            let r = CGRect(x: (CGFloat(f.x) + 0.5) * cell - side / 2, y: (CGFloat(f.y) + 0.5) * cell - side / 2, width: side, height: side)
            // Round, so it never reads as part of the line, even in a theme where both are the same colour.
            ctx.fill(Path(ellipseIn: r.insetBy(dx: -cell * 0.1, dy: -cell * 0.1)), with: .color(Theme.blockA.opacity(0.25)))
            ctx.fill(Path(ellipseIn: r), with: .color(Theme.blockA))
        }
        let n = game.body.count
        let pad = cell * 0.08
        for (i, p) in game.body.enumerated().reversed() {
            let r = CGRect(x: CGFloat(p.x) * cell + pad, y: CGFloat(p.y) * cell + pad, width: cell - 2 * pad, height: cell - 2 * pad)
            let color = i == 0 ? Theme.accent : Theme.blockB.opacity(1 - 0.45 * Double(i) / Double(max(n - 1, 1)))
            ctx.fill(Path(roundedRect: r, cornerRadius: cell * 0.2), with: .color(color))
            // A highlight so each piece reads as a solid tile, the same as the puzzle's blocks.
            ctx.fill(Path(roundedRect: CGRect(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.1, width: r.width * 0.76, height: r.height * 0.14),
                          cornerRadius: cell * 0.06), with: .color(.white.opacity(0.18)))
        }
        // Two eyes on the head, looking the way it's going.
        let h = game.head, d = game.direction
        let c = CGPoint(x: (CGFloat(h.x) + 0.5) * cell, y: (CGFloat(h.y) + 0.5) * cell)
        let ahead = CGPoint(x: CGFloat(d.dx) * cell * 0.16, y: CGFloat(d.dy) * cell * 0.16)
        let side = CGPoint(x: CGFloat(-d.dy) * cell * 0.18, y: CGFloat(d.dx) * cell * 0.18)
        let eye = cell * 0.14
        for s in [-1.0, 1.0] {
            let e = CGPoint(x: c.x + ahead.x + side.x * s, y: c.y + ahead.y + side.y * s)
            ctx.fill(Path(ellipseIn: CGRect(x: e.x - eye / 2, y: e.y - eye / 2, width: eye, height: eye)), with: .color(Color.appBackground))
        }
    }
}

/// The end of a game: the score, the best, and the way on.
private struct GameOverCard: View {
    let won: Bool
    let score: Int
    let best: Int
    let newBest: Bool
    let onAgain: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.opacity(0.88).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(won ? "You filled the board!" : "Game over")
                    .font(.app(fixedSize: 40, weight: .black)).multilineTextAlignment(.center)
                    .accessibilityIdentifier("snake-over")
                Text("\(score)").font(.app(fixedSize: 64, weight: .black)).foregroundStyle(Theme.accent)
                    .accessibilityLabel("Score \(score)")
                Text(newBest ? "New best!" : "Best \(best)").foregroundStyle(newBest ? Theme.accent : .secondary)
                Spacer().frame(height: 16)
                TermButton(label: "Play again", action: onAgain)
                OutlineButton(label: "Back to my chores", action: onBack)
            }
            .padding(32)
        }
    }
}

private struct SnakeTimeUpCard: View {
    let onBack: () -> Void
    var body: some View {
        ZStack {
            Color.appBackground.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("That's your 30 minutes of games for today. See you tomorrow!")
                    .font(.app(.headline)).multilineTextAlignment(.center)
                Button("Back", action: onBack).font(.app(.headline)).foregroundStyle(Theme.accent)
                    .frame(minHeight: 44).accessibilityIdentifier("snake-timeup-back")
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("snake-timeup")
    }
}
