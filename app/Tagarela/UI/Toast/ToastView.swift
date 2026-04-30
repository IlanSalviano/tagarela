import SwiftUI

/// Render de um Toast acima do indicator pill. Click = dismiss antecipado.
struct ToastView: View {
    let kind: ToastKind
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.iconSystemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(kind.tintColor)
                .frame(width: 18)
            Text(kind.displayMessage)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 380, alignment: .leading)
        .background(DS.Color.paper, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(kind.tintColor.opacity(0.6), lineWidth: 0.8)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(kind.tintColor)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                .padding(.vertical, 6)
                .padding(.leading, 4)
        }
        .dsShadowPop()
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }
}

#Preview {
    VStack(spacing: 12) {
        ToastView(kind: .refinerFellBack(reason: .networkOffline))
        ToastView(kind: .injectionFailed)
        ToastView(kind: .historySaveFailed)
        ToastView(kind: .permissionDenied(kind: .microphone))
        ToastView(kind: .refinerFellBack(reason: .serverError(503)))
    }
    .padding(40)
    .background(DS.Color.paper2)
}
