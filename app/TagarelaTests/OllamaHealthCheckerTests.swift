import XCTest
@testable import Tagarela

final class OllamaHealthCheckerTests: XCTestCase {
    override func setUp() async throws { MockURLProtocol.responder = nil }
    override func tearDown() async throws { MockURLProtocol.responder = nil }

    private let localhost = URL(string: "http://localhost:11434")!
    private let remote = URL(string: "http://192.168.1.50:11434")!

    private func ok(_ req: URLRequest) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
    }

    /// A `baseURL` era fixada no init e nunca atualizada: apontar o Ollama pra
    /// outra máquina em Preferências deixava o ping no localhost antigo, e todo
    /// refine virava "Sem rede — usando texto cru" até relançar (auditoria §5.4).
    func test_cacheIsPerURL() async {
        nonisolated(unsafe) var pinged: [String] = []
        MockURLProtocol.responder = { [self] req in
            pinged.append(req.url!.host ?? "?")
            guard req.url!.host == "localhost" else { throw URLError(.cannotConnectToHost) }
            return ok(req)
        }
        let checker = OllamaHealthChecker(session: MockURLProtocol.session(), baseURL: localhost)

        let localOK = await checker.isAvailable(baseURL: localhost)
        let remoteOK = await checker.isAvailable(baseURL: remote)

        XCTAssertTrue(localOK)
        XCTAssertFalse(remoteOK, "URL nova não pode herdar o cache da anterior")
        XCTAssertEqual(pinged, ["localhost", "192.168.1.50"], "as duas URLs têm que ser sondadas")
    }

    func test_positiveResultIsCached() async {
        nonisolated(unsafe) var pings = 0
        MockURLProtocol.responder = { [self] req in
            pings += 1
            return ok(req)
        }
        let checker = OllamaHealthChecker(session: MockURLProtocol.session(), baseURL: localhost)

        _ = await checker.isAvailable(baseURL: localhost)
        _ = await checker.isAvailable(baseURL: localhost)

        XCTAssertEqual(pings, 1, "resultado positivo fica em cache")
    }

    func test_invalidateClearsCache() async {
        nonisolated(unsafe) var pings = 0
        MockURLProtocol.responder = { [self] req in
            pings += 1
            return ok(req)
        }
        let checker = OllamaHealthChecker(session: MockURLProtocol.session(), baseURL: localhost)

        _ = await checker.isAvailable(baseURL: localhost)
        await checker.invalidate()
        _ = await checker.isAvailable(baseURL: localhost)

        XCTAssertEqual(pings, 2)
    }

    /// Esc durante `.refining` com ping em vôo cacheava `false` por 30 s: os
    /// ditados seguintes caíam em texto cru com "Sem rede" mesmo com o Ollama
    /// no ar o tempo todo.
    func test_cancellationIsNotCachedAsUnavailable() async {
        nonisolated(unsafe) var pings = 0
        MockURLProtocol.responder = { [self] req in
            pings += 1
            if pings == 1 { throw URLError(.cancelled) }
            return ok(req)
        }
        let checker = OllamaHealthChecker(session: MockURLProtocol.session(), baseURL: localhost)

        let cancelled = await checker.isAvailable(baseURL: localhost)
        let afterwards = await checker.isAvailable(baseURL: localhost)

        XCTAssertFalse(cancelled, "cancelamento devolve false para esta chamada")
        XCTAssertTrue(afterwards, "mas não pode envenenar as chamadas seguintes")
        XCTAssertEqual(pings, 2, "a segunda chamada tem que sondar de novo")
    }
}
