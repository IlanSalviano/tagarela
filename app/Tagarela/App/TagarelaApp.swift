import SwiftUI

@main
struct TagarelaApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(container.appState)
        } label: {
            Label {
                Text("tagarela")
            } icon: {
                Glyph(size: 16, color: .primary,
                      recording: container.appState.pipeline != .idle)
            }
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Wordmark(size: 18)
                Spacer()
                Text("v1.0.0-fase1")
                    .font(DS.Font.mono(9))
                    .tracking(0.5)
                    .foregroundStyle(DS.Color.ink3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(Divider().background(DS.Color.hairline), alignment: .bottom)

            StatePlaceholder(state: appState.pipeline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider().background(DS.Color.hairline)

            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Text("sair")
                        .font(DS.Font.mono(11))
                        .foregroundStyle(DS.Color.ink3)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 320)
        .background(DS.Color.paper)
    }
}

private struct StatePlaceholder: View {
    let state: PipelineState
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(state.dotColorName))
                .frame(width: 8, height: 8)
            Text(state.label)
                .font(DS.Font.mono(13))
            Spacer()
        }
    }
}
