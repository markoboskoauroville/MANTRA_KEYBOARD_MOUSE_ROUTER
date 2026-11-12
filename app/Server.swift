// A very small HTTP server on 127.0.0.1 so a session can borrow the mouse and keyboard and give them back.
//   POST /borrow  {"reason":"typing the plan into Keep","seconds":20}  -> {"ok":true,"token":"..."}
//   POST /return  {"token":"..."}                                      -> {"ok":true}
//   GET  /status                                                       -> what it is doing
//   POST /enabled {"on":false}                                         -> Marko's own switch
import Foundation
import Network

final class Server {
    private let router: Router
    private let port: NWEndpoint.Port
    private var listener: NWListener?

    init(router: Router, port: UInt16) {
        self.router = router
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: port)
            let l = try NWListener(using: params)
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            l.start(queue: .main)
            listener = l
            NSLog("[router] listening on 127.0.0.1:\(port.rawValue)")
        } catch {
            NSLog("[router] could not listen: \(error)")
        }
    }

    private func accept(_ c: NWConnection) {
        c.start(queue: .main)
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, let text = String(data: data, encoding: .utf8) else { c.cancel(); return }
            let body = self.handle(request: text)
            let payload = try! JSONSerialization.data(withJSONObject: body)
            var head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
            head += "Content-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
            c.send(content: head.data(using: .utf8)! + payload,
                   completion: .contentProcessed { _ in c.cancel() })
        }
    }

    private func handle(request: String) -> [String: Any] {
        let line = request.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = line.split(separator: " ")
        guard parts.count >= 2 else { return ["ok": false, "error": "bad request"] }
        let path = String(parts[1])
        var json: [String: Any] = [:]
        if let r = request.range(of: "\r\n\r\n") {
            let bodyText = String(request[r.upperBound...])
            if let d = bodyText.data(using: .utf8),
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { json = o }
        }
        switch path {
        case "/borrow":
            return router.borrow(reason: json["reason"] as? String ?? "working",
                                 seconds: (json["seconds"] as? NSNumber)?.doubleValue ?? 20)
        case "/return":
            router.giveBack(reason: "the session gave them back")
            return ["ok": true]
        case "/enabled":
            router.enabled = (json["on"] as? NSNumber)?.boolValue ?? true
            return ["ok": true, "enabled": router.enabled]
        case "/status":
            return router.status()
        default:
            return ["ok": false, "error": "try /borrow /return /status /enabled"]
        }
    }
}
