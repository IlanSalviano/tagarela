import SwiftUI

enum DS {
    enum Color {
        static let paper = SwiftUI.Color("Paper")
        static let paper2 = SwiftUI.Color("Paper2")
        static let paper3 = SwiftUI.Color("Paper3")
        static let ink = SwiftUI.Color("Ink")
        static let ink2 = SwiftUI.Color("Ink2")
        static let ink3 = SwiftUI.Color("Ink3")
        static let ink4 = SwiftUI.Color("Ink4")
        static let carmine = SwiftUI.Color("Carmine")
        static let carmineDeep = SwiftUI.Color("CarmineDeep")
        static let amber = SwiftUI.Color("Amber")
        static let amberSoft = SwiftUI.Color("AmberSoft")
        static let moss = SwiftUI.Color("Moss")

        static let hairline = SwiftUI.Color.black.opacity(0.10)
        static let hairlineStrong = SwiftUI.Color.black.opacity(0.18)
    }

    enum Font {
        static func mono(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            let psName: String
            switch weight {
            case .medium: psName = "JetBrainsMono-Medium"
            case .semibold, .bold: psName = "JetBrainsMono-SemiBold"
            default: psName = "JetBrainsMono-Regular"
            }
            return .custom(psName, size: size)
        }

        static func ui(_ size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            let psName: String
            switch weight {
            case .medium: psName = "InterTight-Medium"
            case .semibold, .bold: psName = "InterTight-SemiBold"
            default: psName = "InterTight-Regular"
            }
            return .custom(psName, size: size)
        }

        static func display(_ size: CGFloat) -> SwiftUI.Font {
            .custom("InstrumentSerif-Italic", size: size)
        }
    }

    enum Radius {
        static let r1: CGFloat = 3
        static let r2: CGFloat = 6
        static let r3: CGFloat = 10
        static let pill: CGFloat = 999
    }

    enum Shadow {
        static let pop = (color: SwiftUI.Color.black.opacity(0.28), radius: CGFloat(24), x: CGFloat(0), y: CGFloat(8))
        static let lg = (color: SwiftUI.Color.black.opacity(0.18), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
        static let md = (color: SwiftUI.Color.black.opacity(0.10), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    }
}

extension View {
    func dsShadowPop() -> some View {
        shadow(color: DS.Shadow.pop.color,
               radius: DS.Shadow.pop.radius,
               x: DS.Shadow.pop.x,
               y: DS.Shadow.pop.y)
    }

    /// Eyebrow caption (small uppercase mono label).
    /// Note: ignora `self` — uso típico é `EmptyView().dsEyebrow("PASSO 1")`.
    func dsEyebrow(_ text: String) -> some View {
        Text(text.uppercased())
            .font(DS.Font.mono(10))
            .tracking(1.4)
            .foregroundStyle(DS.Color.ink3)
    }
}

#Preview("Fonts smoke") {
    VStack(alignment: .leading, spacing: 8) {
        Text("tagarela mono regular").font(DS.Font.mono(14))
        Text("tagarela mono medium").font(DS.Font.mono(14, weight: .medium))
        Text("tagarela mono semibold").font(DS.Font.mono(14, weight: .semibold))
        Text("tagarela ui body").font(DS.Font.ui(14))
        Text("tagarela ui medium").font(DS.Font.ui(14, weight: .medium))
        Text("tagarela display").font(DS.Font.display(28))
        EmptyView().dsEyebrow("passo 1 / 3")
    }
    .padding()
    .background(DS.Color.paper)
}
