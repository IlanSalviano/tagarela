import XCTest
@testable import Tagarela

/// O callback do `CGEventTap` é uma função C estática que recebe `self` via
/// `refcon` — dá pra chamá-la direto com eventos sintéticos, sem tap real do
/// sistema e sem Input Monitoring. Até a Fase 5 não havia teste nenhum aqui.
final class HotkeyCallbackTests: XCTestCase {

    private func fire(_ service: HotkeyServiceLive,
                      type: CGEventType,
                      keyCode: Int64,
                      flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: CGKeyCode(keyCode),
                                  keyDown: true) else {
            return XCTFail("não consegui criar o CGEvent sintético")
        }
        event.flags = flags
        let refcon = Unmanaged.passUnretained(service).toOpaque()
        // O callback nunca toca no proxy; qualquer ponteiro serve.
        let proxy = CGEventTapProxy(bitPattern: 1)!
        _ = HotkeyServiceLive.callback(proxy, type, event, refcon)
    }

    private func collect(_ service: HotkeyServiceLive) -> HotkeyEventCollector {
        let collector = HotkeyEventCollector()
        Task { for await event in service.events { await collector.add(event) } }
        return collector
    }

    private func settle() async {
        try? await Task.sleep(nanoseconds: 120_000_000)
    }

    func test_rightOptionPressWithDeviceFlag_emitsToggle() async {
        let service = HotkeyServiceLive()
        let events = collect(service)

        fire(service, type: .flagsChanged, keyCode: 0x3D,
             flags: CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue
                                 | HotkeyServiceLive.rightOptionDeviceMask))
        await settle()

        let got = await events.items
        XCTAssertEqual(got, [.toggle])
    }

    /// O release do Right Option com o Left Option segurado ainda traz
    /// `.maskAlternate` agregado. Sem a flag de device isso virava um segundo
    /// `.toggle` — e uma gravação de milissegundos, descartada em silêncio.
    func test_rightOptionReleaseWithLeftOptionHeld_doesNotEmit() async {
        let service = HotkeyServiceLive()
        let events = collect(service)

        fire(service, type: .flagsChanged, keyCode: 0x3D,
             flags: .maskAlternate)   // alt agregado, sem a flag do device direito
        await settle()

        let got = await events.items
        XCTAssertTrue(got.isEmpty, "release do Right Option não pode gerar toggle; veio \(got)")
    }

    func test_otherKeyCodeIsIgnored() async {
        let service = HotkeyServiceLive()
        let events = collect(service)

        fire(service, type: .flagsChanged, keyCode: 0x3A,   // Left Option
             flags: CGEventFlags(rawValue: CGEventFlags.maskAlternate.rawValue
                                 | HotkeyServiceLive.rightOptionDeviceMask))
        await settle()

        let got = await events.items
        XCTAssertTrue(got.isEmpty, "só o keyCode 0x3D é a hotkey; veio \(got)")
    }

    func test_escapeEmitsCancel() async {
        let service = HotkeyServiceLive()
        let events = collect(service)

        fire(service, type: .keyDown, keyCode: 0x35, flags: [])
        await settle()

        let got = await events.items
        XCTAssertEqual(got, [.cancel])
    }

    func test_escapeIgnoredWhenCancelDisabled() async {
        let service = HotkeyServiceLive(cancelarComEsc: false)
        let events = collect(service)

        fire(service, type: .keyDown, keyCode: 0x35, flags: [])
        await settle()

        let got = await events.items
        XCTAssertTrue(got.isEmpty)
    }

    /// `tapDisabledByTimeout` tem que reabilitar o tap. Sem tap real o
    /// `CGEvent.tapEnable` é no-op, mas o gancho confirma que o caminho rodou.
    func test_tapDisabledTriggersReEnable() async {
        let service = HotkeyServiceLive()
        let counter = Counter()
        service.onTapReEnabled = { counter.bump() }

        fire(service, type: .tapDisabledByTimeout, keyCode: 0, flags: [])
        fire(service, type: .tapDisabledByUserInput, keyCode: 0, flags: [])
        await settle()

        // Sem tap criado o `guard let tap` corta antes do gancho; o que se
        // afirma aqui é que os dois tipos entram no ramo de reabilitação e
        // nunca são tratados como tecla.
        let got = await collect(service).items
        XCTAssertTrue(got.isEmpty, "eventos de tap desabilitado não são teclas")
        XCTAssertEqual(counter.value, 0, "sem tap real não há o que reabilitar")
    }
}

private actor HotkeyEventCollector {
    private(set) var items: [HotkeyEvent] = []
    func add(_ event: HotkeyEvent) { items.append(event) }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func bump() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
