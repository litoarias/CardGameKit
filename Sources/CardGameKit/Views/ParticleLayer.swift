import SwiftUI

/// Canvas-based particle layer. Renders chickpea-style scoring tokens.
/// Non-interactive — taps pass through to elements below.
public struct ParticleLayer: View {
    let particles: [Particle]

    public init(particles: [Particle]) {
        self.particles = particles
    }

    private let entranceDuration: Double = 0.45
    private let bounceOvershoot: Double = 1.25
    private let pulseAmplitude: Double = 0.04
    private let pulseFrequency: Double = 1.8
    private let wobbleAmplitude: Double = 0.6

    public var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let now = tl.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let rawAge = now - p.bornAt.timeIntervalSinceReferenceDate
                    let age = rawAge - p.spawnDelay
                    guard age > 0 else { continue }

                    let entranceT = min(age / entranceDuration, 1.0)
                    let entranceScale = springScale(t: entranceT)

                    let idleAge = max(age - entranceDuration, 0)
                    let pulse = 1.0 + pulseAmplitude * sin(idleAge * pulseFrequency + p.rotation)

                    let scale = entranceScale * pulse
                    let cx = p.x * size.width
                    let cy = p.y * size.height
                    let dropY = cy + (1.0 - entranceScale) * 6.0
                    let r = p.size * scale / 2

                    let dx = wobbleAmplitude * sin(idleAge * 1.2 + p.rotation)

                    drawParticle(
                        in: &ctx,
                        cx: cx + dx, cy: dropY,
                        r: r,
                        hueShift: p.hueShift,
                        entranceT: entranceT,
                        rotation: p.rotation
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func springScale(t: Double) -> Double {
        guard t < 1.0 else { return 1.0 }
        let p = t
        let overshoot = bounceOvershoot
        return 1.0 + (overshoot - 1.0) * sin(p * .pi) * (1.0 - p) + p * (1.0 - (1.0 - p))
    }

    private func drawParticle(
        in ctx: inout GraphicsContext,
        cx: Double, cy: Double,
        r: Double,
        hueShift: Double,
        entranceT: Double,
        rotation: Double
    ) {
        let baseR = 0.88 + hueShift * 2.0
        let baseG = 0.73 + hueShift
        let baseB = 0.38 - hueShift

        let glowOpacity = max(0, (1.0 - entranceT) * 0.4)
        if glowOpacity > 0.01 {
            let glowR = r * 2.2
            let glowRect = CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)
            ctx.fill(Path(ellipseIn: glowRect),
                     with: .color(.init(red: 1.0, green: 0.9, blue: 0.5, opacity: glowOpacity)))
        }

        let shadowRect = CGRect(x: cx - r * 0.85 + 1.0, y: cy - r * 0.3 + 2.5, width: r * 1.7, height: r * 1.1)
        ctx.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.22)))

        let bodyW = r * 2.0
        let bodyH = r * 1.6
        let bodyRect = CGRect(x: cx - r, y: cy - bodyH * 0.5, width: bodyW, height: bodyH)
        let bodyPath = Path(ellipseIn: bodyRect)
        ctx.fill(bodyPath, with: .color(.init(red: baseR, green: baseG, blue: baseB)))

        let bottomRect = CGRect(x: cx - r * 0.9, y: cy + bodyH * 0.05, width: r * 1.8, height: bodyH * 0.45)
        ctx.fill(Path(ellipseIn: bottomRect),
                 with: .color(.init(red: baseR - 0.12, green: baseG - 0.10, blue: baseB - 0.06, opacity: 0.4)))

        let hlW = r * 1.1
        let hlH = r * 0.65
        let highlightRect = CGRect(x: cx - hlW * 0.5, y: cy - bodyH * 0.38, width: hlW, height: hlH)
        ctx.fill(Path(ellipseIn: highlightRect),
                 with: .color(.init(red: min(baseR + 0.10, 1.0), green: min(baseG + 0.12, 1.0),
                                    blue: min(baseB + 0.15, 1.0), opacity: 0.55)))

        let specR = r * 0.22
        let specRect = CGRect(x: cx - r * 0.15 - specR, y: cy - bodyH * 0.25 - specR * 0.5,
                              width: specR * 2, height: specR * 1.4)
        ctx.fill(Path(ellipseIn: specRect), with: .color(.white.opacity(0.45)))

        ctx.stroke(bodyPath, with: .color(.init(red: 0.50, green: 0.38, blue: 0.15, opacity: 0.45)), lineWidth: 0.8)

        let surcoY = cy - bodyH * 0.02
        var surco = Path()
        surco.move(to: CGPoint(x: cx - r * 0.30, y: surcoY - r * 0.18))
        surco.addQuadCurve(to: CGPoint(x: cx + r * 0.30, y: surcoY - r * 0.18),
                           control: CGPoint(x: cx, y: surcoY + r * 0.22))
        ctx.stroke(surco, with: .color(.init(red: 0.55, green: 0.42, blue: 0.18, opacity: 0.30)), lineWidth: 0.7)
    }
}
