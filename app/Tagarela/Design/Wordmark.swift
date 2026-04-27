import SwiftUI

struct Wordmark: View {
    var size: CGFloat = 32
    var color: Color = DS.Color.ink
    var accent: Color = DS.Color.carmine
    var showGlyph: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("tag")
                .font(DS.Font.mono(size, weight: .medium))
                .tracking(-size * 0.02)
                .foregroundStyle(color)
            Text("a")
                .font(DS.Font.display(size * 1.18))
                .foregroundStyle(accent)
                .padding(.trailing, -size * 0.04)
            Text("rel")
                .font(DS.Font.mono(size, weight: .medium))
                .tracking(-size * 0.02)
                .foregroundStyle(color)
            ZStack(alignment: .topTrailing) {
                Text("a")
                    .font(DS.Font.mono(size, weight: .medium))
                    .tracking(-size * 0.02)
                    .foregroundStyle(color)
                if showGlyph {
                    Circle()
                        .fill(accent)
                        .frame(width: size * 0.16, height: size * 0.16)
                        .offset(x: size * 0.24, y: -size * 0.18)
                }
            }
        }
        .lineLimit(1)
    }
}

#Preview {
    VStack(spacing: 24) {
        Wordmark(size: 88)
        Wordmark(size: 48)
        Wordmark(size: 32)
        Wordmark(size: 20)
        Wordmark(size: 14, showGlyph: false)
    }
    .padding(40)
    .background(DS.Color.paper)
}
