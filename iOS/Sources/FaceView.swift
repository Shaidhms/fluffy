import SwiftUI

/// A tiny damped spring, so every part of the face moves with a little life.
private struct Spring {
    var value: Double
    var velocity = 0.0
    let stiffness: Double
    let damping: Double  // 1 = no overshoot, lower = bouncier

    init(_ value: Double, stiffness: Double = 200, damping: Double = 0.7) {
        self.value = value
        self.stiffness = stiffness
        self.damping = damping
    }

    mutating func step(to target: Double, dt: Double) {
        let c = 2 * sqrt(stiffness) * damping
        velocity += (stiffness * (target - value) - c * velocity) * dt
        value += velocity * dt
    }
}

/// Smooths what the Mac asks for into lifelike motion: darting eyes, brows, blinks, leaning, hops.
final class FaceAnimator {
    struct Frame {
        var gaze: CGPoint
        var mood: Mood
        var talk: Double
        var closed: Double      // 0 open … 1 shut (blink)
        var breathe: Double
        var time: Double
        var pupil: Double       // pupil size multiplier
        var browLift: Double    // + raises the brows (in design px)
        var browTilt: Double    // + worried/curious, - focused (radians)
        var lean: Double        // head tilt toward where he's looking (radians)
        var hop: Double         // little idle hop (design px, up is +)
        var blush: Double       // 0…1
        var squint: Double      // 0…1 happy squint from below
    }

    private var target = FaceState()
    private var lastPacket = -100.0
    private var gazeX = Spring(0, stiffness: 260, damping: 0.82)
    private var gazeY = Spring(0, stiffness: 260, damping: 0.82)
    private var pupil = Spring(1, stiffness: 160, damping: 0.5)
    private var browLift = Spring(0, stiffness: 180, damping: 0.55)
    private var browTilt = Spring(0, stiffness: 150, damping: 0.6)
    private var lean = Spring(0, stiffness: 60, damping: 0.8)
    private var hop = Spring(0, stiffness: 260, damping: 0.35)
    private var blush = Spring(0.25, stiffness: 40, damping: 1)
    private var squint = Spring(0, stiffness: 150, damping: 0.7)
    private var talk = 0.0
    private var mood: Mood = .listening
    private var moodChanged = 0.0
    private var blinkStart = -1.0
    private var doubleBlink = false
    private var nextBlink = 2.0
    private var lastTime: Double?
    private var nextSaccade = 0.0
    private var wanderTarget = CGPoint(x: 0, y: -0.3)
    private var jitter = CGPoint.zero
    private var nextJitter = 0.0
    private var nextHop = 6.0

    /// Set while a finger is on the screen, in -1…1 gaze units.
    var touchGaze: CGPoint?
    /// Mood set on the phone itself (waking up, talking).
    var localMood: Mood?
    /// Loudness of the voice playing on this phone, 0…1.
    var localTalk: () -> Double = { 0 }
    /// True while he's awake and talking with you. In follow mode his eyes stay locked on your mouse.
    var awake = false

    func receive(_ face: FaceState, at time: Double) {
        target = face
        lastPacket = time
    }

    func step(_ now: Double) -> Frame {
        let dt = min(now - (lastTime ?? now), 1.0 / 20)
        lastTime = now

        let live = now - lastPacket < 2.5
        let wantedMood = localMood ?? (live ? target.mood : .listening)
        if wantedMood != mood {
            mood = wantedMood
            moodChanged = now
            blinkStart = now          // blink through every mood change
            if mood != .sleepy && mood != .resting {
                hop.velocity += 260   // and a little bounce of surprise
                pupil.velocity += 3
            }
        }

        // Where to look, plus tiny darting movements so the eyes never sit dead still.
        var want: CGPoint
        if let touchGaze {
            want = touchGaze
        } else if live {
            want = CGPoint(x: target.gazeX, y: target.gazeY)
        } else {
            if now > nextSaccade {
                wanderTarget = CGPoint(x: .random(in: -0.9...0.9), y: .random(in: -0.9...0.4))
                nextSaccade = now + .random(in: 0.6...2.2)
            }
            want = wanderTarget
        }
        if mood == .thinking { want = CGPoint(x: 0.6 + 0.08 * sin(now * 1.3), y: -0.85) }
        if now > nextJitter {
            // While he's listening his eyes stay on your mouse; the livelier darting is for replying.
            let amount = !awake ? 0.015 : (mood == .talking ? 0.07 : mood == .thinking ? 0.05 : 0.02)
            jitter = CGPoint(x: .random(in: -amount...amount), y: .random(in: -amount...amount))
            nextJitter = now + .random(in: 0.5...1.4)
        }
        gazeX.step(to: want.x + jitter.x, dt: dt)
        gazeY.step(to: want.y + jitter.y, dt: dt)

        var wantTalk = live ? target.talk : (localMood == .talking ? 0.5 + 0.5 * sin(now * 19) * sin(now * 7.3) : 0)
        wantTalk = max(wantTalk, localTalk())
        talk += (wantTalk - talk) * min(1, dt * 25)

        // Expression targets per mood.
        var wantPupil = 1.0, wantLift = 0.0, wantTilt = 0.0, wantBlush = 0.25, wantSquint = 0.0
        switch mood {
        case .listening:
            wantPupil = 1.12; wantLift = 10
        case .talking:
            wantPupil = 1.05; wantLift = 6 + talk * 18; wantTilt = 0.05 * sin(now * 2.3)
        case .pointing:
            wantPupil = 0.95; wantLift = -4; wantTilt = -0.14
        case .thinking:
            wantPupil = 0.9; wantLift = 4; wantTilt = 0.22
        case .happy:
            wantPupil = 1.2; wantLift = 16; wantBlush = 0.85; wantSquint = 1
        case .resting:
            wantPupil = 0.9; wantLift = -8; wantBlush = 0.15
        case .sleepy:
            wantPupil = 0.88; wantLift = -10; wantTilt = 0.12; wantBlush = 0.15
        }
        pupil.step(to: wantPupil, dt: dt)
        browLift.step(to: wantLift, dt: dt)
        browTilt.step(to: wantTilt, dt: dt)
        blush.step(to: wantBlush, dt: dt)
        squint.step(to: wantSquint, dt: dt)
        lean.step(to: -gazeX.value * 0.045, dt: dt)

        // An occasional happy little hop when nothing much is going on.
        if now > nextHop {
            if talk < 0.05, mood != .sleepy, mood != .resting { hop.velocity += .random(in: 180...320) }
            nextHop = now + .random(in: 7...14)
        }
        hop.step(to: 0, dt: dt)

        // Blinks, sometimes doubled.
        // Blinks, sometimes doubled. When he's drowsy they're slow and heavy.
        let drowsy = mood == .sleepy
        if now > nextBlink {
            blinkStart = now
            doubleBlink = !drowsy && Double.random(in: 0...1) < 0.25
            nextBlink = now + (drowsy ? .random(in: 1.6...3.0) : .random(in: 2.0...5.0))
        }
        let p = (now - blinkStart) / (drowsy ? 0.7 : 0.15)
        var closed = (0...1).contains(p) ? sin(.pi * p) : 0
        if doubleBlink, (1.3...2.3).contains(p) { closed = sin(.pi * (p - 1.3)) }

        let breathe = sin(now * (mood == .resting ? 1.1 : 1.8))
        return Frame(gaze: CGPoint(x: gazeX.value, y: gazeY.value), mood: mood, talk: talk, closed: closed,
                     breathe: breathe, time: now, pupil: pupil.value, browLift: browLift.value,
                     browTilt: browTilt.value, lean: lean.value, hop: hop.value, blush: blush.value,
                     squint: max(0, min(1, squint.value)))
    }
}

/// The landscape face on pure black: he fills the screen and peeks up from the bottom edge.
struct FaceView: View {
    let animator: FaceAnimator

    // The design is drawn on an 844 × 390 landscape phone.
    static let design = CGSize(width: 844, height: 390)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let frame = animator.step(timeline.date.timeIntervalSinceReferenceDate)
                FaceView.draw(frame, in: &ctx, size: size)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    // MARK: Fluffy, the fluffy ginger cat

    static let headCenter = CGPoint(x: 422, y: 400)
    static let headRadius = CGSize(width: 345, height: 300)

    /// His ginger fur: lighter on the forehead, deeper toward the edges.
    static func fur(in head: CGRect) -> GraphicsContext.Shading {
        .radialGradient(BlobShape.gradient, center: CGPoint(x: head.midX - 40, y: head.minY + 90),
                        startRadius: 10, endRadius: head.width * 0.62)
    }

    /// A round head with a tufted, fluffy outline and extra fluff on the cheeks.
    static func headPath(center c: CGPoint, radius r: CGSize) -> Path {
        var p = Path()
        let steps = 240
        func point(_ i: Int) -> CGPoint {
            let t = Double(i) / Double(steps) * 2 * .pi
            // Soft scallops all round, and pointy fur tufts on the cheeks (the lower sides).
            let side = pow(abs(cos(t)), 3) * max(0, sin(t) + 0.45)
            let scallop = pow(abs(sin(t * 16)), 0.6) * 0.018
            let saw = 1 - abs((t * 26 / (2 * .pi)).truncatingRemainder(dividingBy: 1) * 2 - 1)  // 0…1 triangle wave
            let tuft = pow(saw, 2.2) * 0.085 * side
            let k = 1 + scallop + tuft
            return CGPoint(x: c.x + cos(t) * r.width * k, y: c.y + sin(t) * r.height * k)
        }
        p.move(to: point(0))
        for i in stride(from: 1, through: steps, by: 1) { p.addLine(to: point(i)) }
        p.closeSubpath()
        return p
    }

    /// A rounded triangle ear. `side` is -1 for his left ear (on screen) and 1 for the right.
    static func ear(side: CGFloat, inner: Bool) -> Path {
        let shrink: CGFloat = inner ? 0.62 : 1
        let baseA = CGPoint(x: 422 + side * 272, y: 250)
        let baseB = CGPoint(x: 422 + side * 92, y: 132)
        let tip = CGPoint(x: 422 + side * 252, y: 4)
        let mid = CGPoint(x: (baseA.x + baseB.x) / 2, y: (baseA.y + baseB.y) / 2)
        func s(_ p: CGPoint) -> CGPoint { CGPoint(x: mid.x + (p.x - mid.x) * shrink, y: mid.y + (p.y - mid.y) * shrink - (inner ? 6 : 0)) }
        let a = s(baseA), b = s(baseB), t = s(tip)
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: CGPoint(x: t.x - side * 10, y: t.y + 18), control: CGPoint(x: a.x + side * 10, y: (a.y + t.y) / 2 - 10))
        p.addQuadCurve(to: CGPoint(x: t.x - side * 26, y: t.y + 22), control: t)
        p.addQuadCurve(to: b, control: CGPoint(x: (b.x + t.x) / 2 + side * 14, y: (b.y + t.y) / 2))
        p.closeSubpath()
        return p
    }

    /// Fills a shape with his fur and its sheen, so eyelids match the rest of his head.
    private static func fillFur(_ path: Path, in ctx: inout GraphicsContext, head: CGRect) {
        ctx.fill(path, with: fur(in: head))
        ctx.fill(path, with: sheen(in: head))
    }

    static func sheen(in head: CGRect) -> GraphicsContext.Shading {
        .radialGradient(Gradient(colors: [.white.opacity(0.28), .white.opacity(0)]),
                        center: CGPoint(x: head.midX - 120, y: head.minY + 70), startRadius: 0, endRadius: 220)
    }

    static func draw(_ f: FaceAnimator.Frame, in ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))

        let scale = max(size.width / design.width, size.height / design.height)
        ctx.translateBy(x: (size.width - design.width * scale) / 2, y: size.height - design.height * scale)
        ctx.scaleBy(x: scale, y: scale)

        drawCat(f, in: &ctx, tail: true)
    }

    /// Just his head, scaled to fit a small square on a clear background (app screen icon).
    static func drawIcon(_ f: FaceAnimator.Frame, in ctx: inout GraphicsContext, size: CGSize) {
        let region = CGRect(x: 60, y: 0, width: 724, height: 640)
        let scale = min(size.width / region.width, size.height / region.height)
        ctx.translateBy(x: (size.width - region.width * scale) / 2, y: (size.height - region.height * scale) / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -region.minX, y: -region.minY)
        var clipped = ctx
        clipped.clip(to: Path(region))
        drawCat(f, in: &clipped, tail: false)
    }

    private static func drawCat(_ f: FaceAnimator.Frame, in ctx: inout GraphicsContext, tail showTail: Bool) {
        let brown = Color(hex: Palette.nose)
        let ink = Color(hex: Palette.ink)
        let cream = Color(hex: Palette.cream)
        let pink = Color(hex: Palette.pink)

        // His striped tail flicks lazily at the side, curled at the tip: very cat, very unbothered.
        if showTail {
            let swish = CGFloat(sin(f.time * 0.9) * 0.6 + sin(f.time * 2.3) * 0.15)
            var tail = Path()
            tail.move(to: CGPoint(x: 806, y: 440))
            tail.addCurve(to: CGPoint(x: 800 + swish * 16, y: 150),
                          control1: CGPoint(x: 846, y: 330),
                          control2: CGPoint(x: 770 + swish * 40, y: 240))
            tail.addQuadCurve(to: CGPoint(x: 752 + swish * 22, y: 120), control: CGPoint(x: 800 + swish * 10, y: 96))
            ctx.stroke(tail, with: .color(Color(hex: Palette.berry3)), style: StrokeStyle(lineWidth: 54, lineCap: .round))
            ctx.stroke(tail, with: .color(Color(hex: Palette.berry4, opacity: 0.6)),
                       style: StrokeStyle(lineWidth: 54, lineCap: .butt, dash: [14, 30], dashPhase: 6))
        }

        // Whole-body motion: breathing, talking bounce, a small hop now and then, leaning toward what he looks at.
        let bounce = -f.talk * 12 + f.breathe * 3 - f.hop * 0.5
        let center = CGPoint(x: headCenter.x, y: headCenter.y + bounce)
        let head = CGRect(x: center.x - headRadius.width, y: center.y - headRadius.height,
                          width: headRadius.width * 2, height: headRadius.height * 2)
        let pivot = CGPoint(x: center.x, y: head.maxY)
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: .radians(f.lean))
        let stretch = 1 + min(0.025, max(-0.025, f.hop / 1000))
        ctx.scaleBy(x: 2 - stretch, y: stretch)
        ctx.translateBy(x: -pivot.x, y: -pivot.y)

        // Ears do the acting a cat's brows would: perked when he's interested, flattened when sleepy,
        // one twitching now and then.
        let perk = min(18, max(-10, f.browLift))
        let twitch = pow(max(0, sin(f.time * 1.3) * sin(f.time * 0.37)), 8) * 0.3
        for side in [CGFloat(-1), 1] {
            var e = ctx
            let base = CGPoint(x: 422 + side * 182, y: 191)
            e.translateBy(x: base.x, y: base.y)
            var angle = side * (0.1 - perk * 0.008) + f.browTilt * side * 0.5
            if side > 0 { angle += twitch }
            e.rotate(by: .radians(angle))
            e.translateBy(x: -base.x, y: -base.y)
            e.fill(ear(side: side, inner: false), with: .color(Color(hex: Palette.berry3)))
            e.fill(ear(side: side, inner: true), with: .linearGradient(Gradient(colors: [pink, cream]),
                                                                       startPoint: CGPoint(x: base.x, y: 40),
                                                                       endPoint: CGPoint(x: base.x, y: 230)))
        }

        let outline = headPath(center: center, radius: headRadius)

        var glow = ctx
        glow.addFilter(.shadow(color: Color(hex: Palette.berry2, opacity: 0.45), radius: 40, x: 0, y: -8))
        glow.fill(outline, with: .color(Color(hex: Palette.berry3)))
        ctx.fill(outline, with: fur(in: head))

        var furry = ctx
        furry.clip(to: outline)
        // Tabby stripes on his forehead.
        for (i, dx) in [-48.0, 0, 48].enumerated() {
            var stripe = Path()
            let x = center.x + dx
            stripe.move(to: CGPoint(x: x + dx * 0.25, y: head.minY - 10))
            stripe.addQuadCurve(to: CGPoint(x: x, y: head.minY + (i == 1 ? 78 : 58)), control: CGPoint(x: x + dx * 0.2, y: head.minY + 30))
            furry.stroke(stripe, with: .color(Color(hex: Palette.berry4, opacity: 0.55)),
                         style: StrokeStyle(lineWidth: i == 1 ? 20 : 16, lineCap: .round))
        }
        // Side stripes on his cheeks.
        for side in [CGFloat(-1), 1] {
            for j in 0..<2 {
                var s = Path()
                let y = center.y - 60 + CGFloat(j) * 34
                s.move(to: CGPoint(x: center.x + side * 350, y: y))
                s.addQuadCurve(to: CGPoint(x: center.x + side * 280, y: y + 6), control: CGPoint(x: center.x + side * 315, y: y - 10))
                furry.stroke(s, with: .color(Color(hex: Palette.berry4, opacity: 0.5)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
            }
        }
        // Soft fluffy sheen.
        furry.fill(outline, with: sheen(in: head))

        // Cream muzzle and chin.
        var muzzle = furry
        muzzle.addFilter(.blur(radius: 6))
        let muzzleY = center.y - 92
        for side in [CGFloat(-1), 1] {
            muzzle.fill(Path(ellipseIn: CGRect(x: center.x + side * 50 - 72, y: muzzleY - 30, width: 144, height: 104)), with: .color(cream))
        }
        muzzle.fill(Path(ellipseIn: CGRect(x: center.x - 90, y: muzzleY + 30, width: 180, height: 120)), with: .color(cream))

        let eyeY = center.y - 172
        let eyes = [CGPoint(x: center.x - 122, y: eyeY), CGPoint(x: center.x + 122, y: eyeY)]
        let squash = 1 - f.talk * 0.1

        // Rosy cheeks, a little pinker when he's (grudgingly) pleased.
        for (i, c) in eyes.enumerated() {
            let side: CGFloat = i == 0 ? -1 : 1
            var soft = furry
            soft.addFilter(.blur(radius: 12))
            soft.fill(Path(ellipseIn: CGRect(x: c.x - 48 + side * 40, y: c.y + 74, width: 96, height: 40)),
                      with: .color(pink.opacity(0.15 + 0.4 * f.blush)))
        }

        // How far his upper lids sit down: aloof by default, wide when he's curious.
        let lidBase: Double
        switch f.mood {
        case .listening: lidBase = 0.18
        case .talking: lidBase = 0.34
        case .pointing: lidBase = 0.4
        case .thinking: lidBase = 0.36
        case .happy: lidBase = 0.12
        case .resting: lidBase = 0
        case .sleepy: lidBase = 0.56 + 0.05 * sin(f.time * 1.3)
        }

        for (i, c) in eyes.enumerated() {
            let side: CGFloat = i == 0 ? -1 : 1
            let w: CGFloat = 158, h: CGFloat = 116

            switch f.mood {
            case .resting:
                // Snoozing: content closed curves.
                var shut = Path()
                shut.move(to: CGPoint(x: c.x - 62, y: c.y + 4))
                shut.addQuadCurve(to: CGPoint(x: c.x + 62, y: c.y + 4), control: CGPoint(x: c.x, y: c.y + 44))
                ctx.stroke(shut, with: .color(ink), style: StrokeStyle(lineWidth: 14, lineCap: .round))

            case .happy where f.squint > 0.6:
                // The smug, squinty cat smile: ^ ^
                var arc = Path()
                arc.move(to: CGPoint(x: c.x - 60, y: c.y + 26))
                arc.addQuadCurve(to: CGPoint(x: c.x + 60, y: c.y + 26), control: CGPoint(x: c.x, y: c.y - 46))
                ctx.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 16, lineCap: .round))

            default:
                let open = max(0.06, 1 - f.closed) * squash
                // An almond eye, tilted up at the outer corner.
                let lift: CGFloat = 10
                let inner = CGPoint(x: c.x - side * w / 2, y: c.y + lift * 0.4)
                let outer = CGPoint(x: c.x + side * w / 2, y: c.y - lift)
                var almond = Path()
                almond.move(to: inner)
                almond.addQuadCurve(to: outer, control: CGPoint(x: c.x, y: c.y - h * open))
                almond.addQuadCurve(to: inner, control: CGPoint(x: c.x, y: c.y + h * 0.95 * open))
                almond.closeSubpath()
                ctx.fill(almond, with: .radialGradient(Gradient(colors: [Color(hex: 0xE4F08A), Color(hex: Palette.iris), Color(hex: Palette.irisDeep)]),
                                                       center: CGPoint(x: c.x, y: c.y), startRadius: 4, endRadius: w * 0.5))
                // The almond runs from c.y - h/2 (top) to about c.y + h/2 (bottom), scaled by how open it is.
                let lidBottom = c.y - h * 0.5 * open + h * 0.97 * open * lidBase
                // Only outline the part of the eye below the lid, so the lid reads as covering it.
                var rim = ctx
                if lidBase > 0.01 {
                    rim.clip(to: Path(CGRect(x: c.x - w, y: lidBottom - 3, width: w * 2, height: h * 2)))
                }
                guard open > 0.2 else {
                    rim.stroke(almond, with: .color(ink), style: StrokeStyle(lineWidth: 8, lineJoin: .round))
                    continue
                }

                var inside = ctx
                inside.clip(to: almond)
                var g = f.gaze
                let len = hypot(g.x, g.y)
                if len > 1 { g = CGPoint(x: g.x / len, y: g.y / len) }
                // Slit pupils that widen when he's interested.
                let pw = max(14, 16 + (f.pupil - 0.85) * 120)
                let ph = h * 0.84 * open
                let pupil = CGPoint(x: c.x + g.x * 34 - side * 2, y: c.y + g.y * 14 * open)
                inside.fill(Path(ellipseIn: CGRect(x: pupil.x - pw / 2, y: pupil.y - ph / 2, width: pw, height: ph)), with: .color(ink))
                inside.fill(Path(ellipseIn: CGRect(x: pupil.x - pw / 2 - 18, y: pupil.y - ph * 0.32, width: 22, height: 22)), with: .color(.white))
                inside.fill(Path(ellipseIn: CGRect(x: pupil.x + pw / 2 + 2, y: pupil.y + ph * 0.12, width: 10, height: 10)), with: .color(.white.opacity(0.8)))

                // The aloof half-lid, plus happy cheeks pushing up from below.
                if lidBase > 0.01 {
                    fillFur(Path(CGRect(x: c.x - w, y: c.y - h - 20, width: w * 2, height: lidBottom - (c.y - h - 20))), in: &inside, head: head)
                    var edge = Path()
                    edge.move(to: CGPoint(x: c.x - w / 2, y: lidBottom + side * 4))
                    edge.addQuadCurve(to: CGPoint(x: c.x + w / 2, y: lidBottom - side * 4), control: CGPoint(x: c.x, y: lidBottom + 6))
                    inside.stroke(edge, with: .color(ink.opacity(0.8)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                }
                if f.squint > 0.02 {
                    fillFur(Path(ellipseIn: CGRect(x: c.x - 110, y: c.y + h * open - 70 * f.squint, width: 220, height: 160)), in: &inside, head: head)
                }
                rim.stroke(almond, with: .color(ink), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
            }
        }

        // Pink nose.
        let noseTop = center.y - 112
        var nose = Path()
        nose.move(to: CGPoint(x: center.x - 26, y: noseTop))
        nose.addQuadCurve(to: CGPoint(x: center.x + 26, y: noseTop), control: CGPoint(x: center.x, y: noseTop - 8))
        nose.addQuadCurve(to: CGPoint(x: center.x, y: noseTop + 28), control: CGPoint(x: center.x + 20, y: noseTop + 16))
        nose.addQuadCurve(to: CGPoint(x: center.x - 26, y: noseTop), control: CGPoint(x: center.x - 20, y: noseTop + 16))
        ctx.fill(nose, with: .color(pink))
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - 12, y: noseTop + 1, width: 12, height: 6)), with: .color(.white.opacity(0.6)))

        // The "w" mouth, with a sassy little smirk on one side. It opens as he talks.
        let mouthY = noseTop + 28
        let smile: CGFloat = f.mood == .happy ? 14 : 0
        let smirk: CGFloat = (f.mood == .listening || f.mood == .pointing || f.mood == .thinking) ? 8 : 3
        if f.talk > 0.12 {
            let open = CGFloat(f.talk)
            let mouth = CGRect(x: center.x - 24 - open * 8, y: mouthY + 8, width: 48 + open * 16, height: 18 + open * 34)
            ctx.fill(Path(ellipseIn: mouth), with: .color(Color(hex: 0x4A1E16)))
            ctx.fill(Path(ellipseIn: CGRect(x: mouth.midX - mouth.width * 0.3, y: mouth.maxY - mouth.height * 0.42,
                                            width: mouth.width * 0.6, height: mouth.height * 0.36)), with: .color(pink))
        }
        var w = Path()
        w.move(to: CGPoint(x: center.x, y: noseTop + 26))
        w.addLine(to: CGPoint(x: center.x, y: mouthY + 8))
        w.move(to: CGPoint(x: center.x - 44, y: mouthY + 2 - smile))
        w.addQuadCurve(to: CGPoint(x: center.x, y: mouthY + 8), control: CGPoint(x: center.x - 22, y: mouthY + 30))
        w.addQuadCurve(to: CGPoint(x: center.x + 44, y: mouthY - smirk - smile), control: CGPoint(x: center.x + 22, y: mouthY + 30))
        ctx.stroke(w, with: .color(brown), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))

        // Whiskers, swaying a little (and more when he talks).
        for side in [CGFloat(-1), 1] {
            for j in 0..<3 {
                let sway = sin(f.time * 1.7 + Double(j)) * 0.03 + f.talk * 0.05
                let angle = (CGFloat(j) - 1) * 0.16 + CGFloat(sway) * side
                let start = CGPoint(x: center.x + side * 96, y: mouthY - 6 + CGFloat(j) * 14)
                let length: CGFloat = 200
                let end = CGPoint(x: start.x + side * length * cos(angle), y: start.y + length * sin(angle) * side * side)
                var whisker = Path()
                whisker.move(to: start)
                whisker.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 12))
                ctx.stroke(whisker, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }

        if f.mood == .resting {
            // Little z's floating up while he naps.
            for i in 0..<3 {
                let phase = (f.time * 0.35 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let size = 26 + CGFloat(i) * 8
                let point = CGPoint(x: 700 + CGFloat(phase) * 60 + CGFloat(sin(phase * 6)) * 8,
                                    y: 150 - CGFloat(phase) * 110)
                ctx.draw(Text("z").font(.fredoka(size)).foregroundColor(.white.opacity(0.9 * sin(.pi * phase))), at: point)
            }
        }

        if f.mood == .thinking {
            for i in 0..<3 {
                let wobble = sin(f.time * 3 + Double(i)) * 4
                let dot = CGRect(x: 120 - CGFloat(i) * 26, y: 70 - CGFloat(i) * 12 + wobble, width: 16, height: 16)
                ctx.fill(Path(ellipseIn: dot), with: .color(.white.opacity(1 - Double(i) * 0.3)))
            }
        }
    }
}
