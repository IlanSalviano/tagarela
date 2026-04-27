import SwiftUI

struct Glyph: View {
    var size: CGFloat = 18
    var color: Color = DS.Color.ink
    var recording: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let s = size.width
            let path = Path { p in
                p.move(to: CGPoint(x: s * 4/24, y: s * 5/24))
                p.addLine(to: CGPoint(x: s * 20/24, y: s * 5/24))
                p.addLine(to: CGPoint(x: s * 20/24, y: s * 16/24))
                p.addLine(to: CGPoint(x: s * 11/24, y: s * 16/24))
                p.addLine(to: CGPoint(x: s * 6/24, y: s * 20/24))
                p.addLine(to: CGPoint(x: s * 6/24, y: s * 16/24))
                p.addLine(to: CGPoint(x: s * 4/24, y: s * 16/24))
                p.closeSubpath()
            }
            if recording {
                ctx.fill(path, with: .color(DS.Color.carmine))
            }
            ctx.stroke(path, with: .color(color), lineWidth: 1.6)

            let dotColor: GraphicsContext.Shading = recording ? .color(.white) : .color(color)
            for x in [9.0, 12.0, 15.0] {
                let dot = Path(ellipseIn: CGRect(x: s * (x - 1) / 24,
                                                  y: s * 9.5 / 24,
                                                  width: s * 2/24,
                                                  height: s * 2/24))
                ctx.fill(dot, with: dotColor)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        Glyph(size: 18)
        Glyph(size: 14)
        Glyph(size: 18, recording: true)
    }
    .padding()
    .background(DS.Color.paper)
}
