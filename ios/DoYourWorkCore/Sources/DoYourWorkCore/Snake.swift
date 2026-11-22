import Foundation

/// The second game a submitted card unlocks: steer a line round the board, eat the dots to grow,
/// and don't run into a wall or your own tail. It shares the puzzle's hour a day.
///
/// The rules live here, with no UI, so they can be tested; the Android `SnakeGame` follows the same
/// rules and the same random numbers, and both are tested against the same sequences.
public struct SnakeGame: Equatable, Sendable {
    public struct Point: Hashable, Sendable {
        public let x: Int
        public let y: Int
        public init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
    }

    public enum Direction: Sendable, CaseIterable {
        case up, down, left, right
        public var dx: Int { self == .left ? -1 : self == .right ? 1 : 0 }
        public var dy: Int { self == .up ? -1 : self == .down ? 1 : 0 }
        public var opposite: Direction {
            switch self { case .up: .down; case .down: .up; case .left: .right; case .right: .left }
        }
    }

    public enum Status: Sendable { case ready, playing, over, won }

    /// What a step did.
    public enum Event: Sendable { case moved, ate, died, won }

    /// The board is square so it fits phones, tablets and foldables alike.
    public static let defaultSize = 15
    /// Turns waiting to be used: two, so a quick swipe-swipe (a U-turn) isn't lost between steps.
    public static let maxQueuedTurns = 2

    public let width: Int
    public let height: Int
    /// The line, head first.
    public private(set) var body: [Point]
    /// The way the head moved last (or will move first).
    public private(set) var direction: Direction
    public private(set) var turns: [Direction] = []
    /// Nil only once the line fills the board.
    public private(set) var food: Point?
    public private(set) var score = 0
    public private(set) var status: Status = .ready
    private var random: SnakeRandom

    /// A line three long in the middle, heading right, and the first dot.
    public init(width: Int = defaultSize, height: Int = defaultSize, seed: UInt64) {
        precondition(width >= 5 && height >= 3, "snake board too small")
        self.width = width
        self.height = height
        let (x, y) = (width / 2, height / 2)
        body = [Point(x, y), Point(x - 1, y), Point(x - 2, y)]
        direction = .right
        random = SnakeRandom(seed: seed)
        food = placeFood()
    }

    /// A game set up mid-play, for tests. The line runs from `body[0]`, the head.
    init(width: Int, height: Int, body: [Point], direction: Direction, food: Point?, score: Int = 0, seed: UInt64 = 1) {
        self.width = width
        self.height = height
        self.body = body
        self.direction = direction
        self.food = food
        self.score = score
        random = SnakeRandom(seed: seed)
        status = .playing
    }

    public var head: Point { body[0] }
    public var length: Int { body.count }
    public var isFinished: Bool { status == .over || status == .won }

    /// How long each step takes: it speeds up as the line grows, down to a floor.
    public var stepMilliseconds: Int { max(70, 160 - score * 4) }

    /// Steer. A ready game starts on the first swipe. A turn back on itself, or the way it's already
    /// going, is ignored. Returns whether the turn was queued.
    @discardableResult
    public mutating func turn(_ d: Direction) -> Bool {
        guard !isFinished else { return false }
        if status == .ready { status = .playing }
        let heading = turns.last ?? direction
        guard d != heading, d != heading.opposite, turns.count < Self.maxQueuedTurns else { return false }
        turns.append(d)
        return true
    }

    /// Starts a ready game going the way it faces.
    public mutating func start() { if status == .ready { status = .playing } }

    /// One tick: take the next queued turn and move the head a cell. Nil when the game isn't running.
    @discardableResult
    public mutating func step() -> Event? {
        guard status == .playing else { return nil }
        if !turns.isEmpty { direction = turns.removeFirst() }
        let next = Point(head.x + direction.dx, head.y + direction.dy)
        guard (0..<width).contains(next.x), (0..<height).contains(next.y) else { status = .over; return .died }
        let eats = next == food
        // The tail moves out of the way this step, unless the line is growing.
        if (eats ? body[...] : body.dropLast()).contains(next) { status = .over; return .died }
        body.insert(next, at: 0)
        guard eats else { body.removeLast(); return .moved }
        score += 1
        food = placeFood()
        if food == nil { status = .won; return .won }
        return .ate
    }

    /// A free cell, picked at random from the free cells in row order.
    private mutating func placeFood() -> Point? {
        let taken = Set(body)
        var free: [Point] = []
        for y in 0..<height { for x in 0..<width where !taken.contains(Point(x, y)) { free.append(Point(x, y)) } }
        guard !free.isEmpty else { return nil }
        return free[random.next(below: free.count)]
    }
}

/// A small repeatable random number generator (a 64-bit LCG), so a seed gives the same dots on
/// iOS and Android.
public struct SnakeRandom: Equatable, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }

    /// 0 ..< n.
    public mutating func next(below n: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(n))
    }
}
