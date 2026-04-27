import SwiftUI

struct WaveBars: View {
    var level: Double
    var color: Color
    var count: Int = 16
    var height: CGFloat = 22
    var width: CGFloat = 84
    var gap: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * 12
            HStack(alignment: .center, spacing: gap) {
                let barW = (width - gap * CGFloat(count - 1)) / CGFloat(count)
                ForEach(0..<count, id: \.self) { i in
                    let seed1 = (sin(Double(i) * 1.7 + t * 0.4) + 1) / 2
                    let seed2 = (sin(Double(i) * 0.9 + t * 0.7 + 2) + 1) / 2
                    let env = sin(Double(i) / Double(count) * .pi)
                    let h = max(2, (0.18 + level * 0.7 * (seed1 * 0.6 + seed2 * 0.4))
                        * Double(height) * (0.5 + env * 0.6))
                    Rectangle()
                        .fill(color)
                        .opacity(0.85 + 0.15 * env)
                        .frame(width: barW, height: CGFloat(h))
                }
            }
            .frame(width: width, height: height)
        }
    }
}
