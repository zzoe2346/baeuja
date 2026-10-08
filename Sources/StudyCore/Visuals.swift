import AppKit
import WebKit
import ImageIO

public enum VisualSafety {
    public static func png(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
        guard values.isSymbolicLink != true, let size = values.fileSize, size <= 20 * 1024 * 1024 else { throw StudyError.invalid("그림 파일이 허용 범위를 벗어났습니다.") }
        let data = try Data(contentsOf: url)
        guard data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width >= 128, height >= 128, width <= 20_000, height <= 20_000, width * height <= 40_000_000,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw StudyError.invalid("유효한 PNG 그림이 아닙니다.") }
        return data
    }
    public static func svg(_ value: String) throws {
        guard value.utf8.count <= 2 * 1024 * 1024, !value.lowercased().contains("<!doctype"), !value.lowercased().contains("<!entity") else {
            throw StudyError.invalid("SVG의 문서 선언이나 크기가 허용 범위를 벗어났습니다.")
        }
        let delegate = SVGValidator(); let parser = XMLParser(data: Data(value.utf8))
        parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse(), delegate.valid, delegate.root == "svg" else { throw StudyError.invalid("SVG 검사에서 허용되지 않은 구성을 찾았습니다: " + delegate.issues.sorted().joined(separator: ", ")) }
    }
}
private final class SVGValidator: NSObject, XMLParserDelegate {
    var valid = true; var root: String?; var issues: Set<String> = []
    private var inStyle = false
    private var styleText = ""
    let allowed: Set<String> = ["svg", "g", "defs", "style", "rect", "circle", "ellipse", "line", "polyline", "polygon", "path", "text", "tspan", "title", "desc", "marker", "clipPath", "linearGradient", "radialGradient", "stop", "use"]
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if root == nil { root = name }
        if name == "style" { inStyle = true; styleText = "" }
        if !allowed.contains(name) { valid = false; issues.insert("element " + name) }
        for (key, value) in attributes {
            let lower = key.lowercased(), content = value.lowercased()
            if lower.hasPrefix("on") || ((lower == "href" || lower == "xlink:href") && !value.hasPrefix("#")) { valid = false; issues.insert("attribute " + key) }
            if !safeReferences(content) { valid = false; issues.insert("external URL attribute " + key) }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters value: String) {
        if inStyle { styleText += value }
    }
    func parser(_ parser: XMLParser, foundCDATA data: Data) { if inStyle { styleText += String(decoding: data, as: UTF8.self) } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "style" { if !safeReferences(styleText) { valid = false; issues.insert("external CSS") }; inStyle = false }
    }
    private func safeReferences(_ value: String) -> Bool {
        let lower = value.lowercased()
        guard !lower.contains("@import"), !lower.contains("expression("), !lower.contains("javascript:"), !lower.contains("\\") else { return false }
        let cleaned = lower.replacingOccurrences(of: #"url\(\s*['"]?#[a-z0-9_:-]+['"]?\s*\)"#, with: "", options: .regularExpression)
        return !cleaned.contains("url(")
    }
}

@MainActor public final class VisualRenderer {
    public var timeoutSeconds: Double = 30
    public private(set) var diagnostics: [String] = []
    public init() {}
    public func render(_ lesson: Lesson, directory: URL, image: ((String, URL) async throws -> Void)? = nil) async throws -> [RenderedVisual] {
        var values: [RenderedVisual] = []
        for visual in lesson.visuals {
            try Task.checkCancellation()
            var selected: RenderedVisual?, reason: String?
            for (index, candidate) in ([VisualCandidate(kind: visual.kind, source: visual.source)] + visual.fallbacks).enumerated() {
                do {
                    if candidate.kind == "ascii" {
                        try validateASCII(candidate.source)
                        selected = RenderedVisual(id: visual.id, kind: "ascii", content: candidate.source, fallbackReason: index > 0 ? reason : nil)
                    } else {
                        let file = visual.id + ".png", output = directory.appendingPathComponent(file)
                        if candidate.kind == "image_prompt" {
                            guard let image else { throw StudyError.invalid("이미지 생성이 꺼져 있습니다.") }
                            try await image(candidate.source, output)
                        } else {
                            if candidate.kind == "svg" { try VisualSafety.svg(candidate.source) }
                            let session = WebVisualSession(timeout: timeoutSeconds)
                            let png = try await session.render(source: candidate.source, kind: candidate.kind)
                            try png.write(to: output, options: .atomic)
                        }
                        _ = try VisualSafety.png(output)
                        selected = RenderedVisual(id: visual.id, kind: "image", content: candidate.source, file: file, fallbackReason: index > 0 ? reason : nil)
                    }
                    break
                } catch is CancellationError { throw CancellationError() }
                catch StudyError.cancelled { throw StudyError.cancelled }
                catch { diagnostics.append("\(candidate.kind): \(error.localizedDescription)"); reason = "원본 그림을 표시하지 못해 저장된 대체 도식을 사용합니다." }
            }
            guard let selected else { throw StudyError.invalid("그림과 대체 후보를 모두 표시하지 못했습니다. 이전 교재를 유지했습니다.") }
            values.append(selected)
        }
        return values
    }
}

@MainActor private final class WebVisualSession: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let timeout: Double
    var continuation: CheckedContinuation<Data, Error>?
    var source = "", kind = ""
    var timer: Task<Void, Never>?
    init(timeout: Double) {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 760), configuration: configuration)
        self.timeout = timeout; super.init(); webView.navigationDelegate = self
    }
    func render(source: String, kind: String) async throws -> Data {
        self.source = source; self.kind = kind
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.timer = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(self?.timeout ?? 30) * 1_000_000_000)
                    if !Task.isCancelled { self?.finish(.failure(StudyError.timeout)) }
                }
                let script: String
                if kind == "mermaid", let url = Bundle.module.url(forResource: "mermaid-11.12.2.min", withExtension: "js", subdirectory: "Resources/vendor"), let value = try? String(contentsOf: url, encoding: .utf8) { script = value }
                else if kind == "svg" { script = "" }
                else { finish(.failure(StudyError.invalid("그림 렌더러를 읽을 수 없습니다."))); return }
                // Only the trusted bundled runtime enters the page. Source is passed as a JS argument below.
                webView.loadHTMLString("<html><head><meta charset='utf-8'><style>html,body{margin:0;background:white;font-family:Helvetica,sans-serif}#canvas{padding:24px}svg{max-width:1152px;max-height:700px}svg text{font-family:Helvetica,sans-serif!important}</style><script>\(script)</script></head><body><div id='canvas'></div></body></html>", baseURL: nil)
            }
        }, onCancel: { Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) } })
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(action.request.url?.scheme == "about" ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            do {
                let js = kind == "mermaid" ? "mermaid.initialize({startOnLoad:false,securityLevel:'strict',theme:'neutral',htmlLabels:false,flowchart:{htmlLabels:false}});const result=await mermaid.render('diagram',source);document.getElementById('canvas').innerHTML=result.svg;await document.fonts.ready;return result.svg;" : "document.getElementById('canvas').innerHTML=source;await document.fonts.ready;return source;"
                let value = try await webView.callAsyncJavaScript(js, arguments: ["source": source], in: nil, contentWorld: .page)
                guard let svg = value as? String else { throw StudyError.invalid("그림 결과가 없습니다.") }
                try VisualSafety.svg(svg)
                let rectValue = try await webView.evaluateJavaScript("JSON.stringify(document.querySelector('svg').getBoundingClientRect().toJSON())")
                guard let string = rectValue as? String, let data = string.data(using: .utf8), let rect = try JSONSerialization.jsonObject(with: data) as? [String: Double],
                      let width = rect["width"], let height = rect["height"], width > 0, height > 0 else { throw StudyError.invalid("그림 크기가 올바르지 않습니다.") }
                let config = WKSnapshotConfiguration(); config.rect = CGRect(x: max(0, rect["x"] ?? 0), y: max(0, rect["y"] ?? 0), width: min(width, 1200), height: min(height, 760)); config.snapshotWidth = 1600
                let snapshot = try await webView.takeSnapshot(configuration: config)
                guard let tiff = snapshot.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { throw StudyError.invalid("그림 캡처를 저장하지 못했습니다.") }
                finish(.success(png))
            } catch { finish(.failure(error)) }
        }
    }
    func finish(_ result: Result<Data, Error>) {
        guard let continuation else { return }; self.continuation = nil
        timer?.cancel(); webView.stopLoading(); webView.navigationDelegate = nil; continuation.resume(with: result)
    }
}
