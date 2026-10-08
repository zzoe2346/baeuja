import Foundation

public struct MarkdownBlock: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case paragraph, heading(Int), code(String), bullet, numbered(Int), quote, rule, table(
            [[String]])
    }
    public var kind: Kind
    public var text: String
}
public enum LessonMarkdown {
    public static func blocks(_ text: String) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = [], paragraph: [String] = [], code: [String] = []
        var language: String? = nil
        let lines = text.components(separatedBy: "\n")
        var index = 0
        func flush() {
            if !paragraph.isEmpty {
                result.append(
                    MarkdownBlock(kind: .paragraph, text: paragraph.joined(separator: "\n")));
                paragraph = []
            }
        }
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("```") {
                flush()
                if let lang = language {
                    result.append(
                        MarkdownBlock(kind: .code(lang), text: code.joined(separator: "\n")));
                    code = []; language = nil
                } else {
                    language = String(line.dropFirst(3)).trimmed
                }
            } else if language != nil {
                code.append(line)
            } else if index + 1 < lines.count, let header = cells(line),
                let divider = cells(lines[index + 1]), header.count == divider.count,
                header.count <= 16,
                divider.allSatisfy({ value in
                    let d = value.trimmingCharacters(in: CharacterSet(charactersIn: ":"));
                    return d.count >= 3 && d.allSatisfy { $0 == "-" }
                })
            {
                flush()
                var rows = [header]; index += 2
                while index < lines.count, let row = cells(lines[index]), row.count == header.count
                { rows.append(row); index += 1 }
                result.append(MarkdownBlock(kind: .table(rows), text: "")); continue
            } else if line.trimmed.isEmpty {
                flush()
            } else if line.hasPrefix("#") && line.contains(" ") {
                flush(); let level = line.prefix(while: { $0 == "#" }).count
                result.append(
                    MarkdownBlock(
                        kind: .heading(min(level, 6)), text: String(line.dropFirst(level)).trimmed))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush();
                result.append(MarkdownBlock(kind: .bullet, text: String(line.dropFirst(2))))
            } else if let dot = line.firstIndex(of: "."),
                line[..<dot].allSatisfy({ $0 >= "0" && $0 <= "9" }), let number = Int(line[..<dot]),
                line[line.index(after: dot)...].hasPrefix(" ")
            {
                flush();
                result.append(
                    MarkdownBlock(
                        kind: .numbered(number), text: String(line[line.index(dot, offsetBy: 2)...])
                    ))
            } else if line.hasPrefix("> ") {
                flush(); result.append(MarkdownBlock(kind: .quote, text: String(line.dropFirst(2))))
            } else if ["---", "***"].contains(line.trimmed) {
                flush(); result.append(MarkdownBlock(kind: .rule, text: ""))
            } else {
                paragraph.append(line)
            }
            index += 1
        }
        flush()
        if let lang = language {
            result.append(MarkdownBlock(kind: .code(lang), text: code.joined(separator: "\n")))
        }
        return result
    }
    private static func cells(_ line: String) -> [String]? {
        guard line.contains("|") else { return nil }
        var values: [String] = [], value = "", escaped = false
        for character in line.trimmed {
            if escaped {
                value += character == "|" ? "|" : "\\" + String(character); escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "|" {
                values.append(value.trimmed); value = ""
            } else {
                value.append(character)
            }
        }
        if escaped { value += "\\" }; values.append(value.trimmed)
        if line.trimmed.hasPrefix("|") { values.removeFirst() }
        if line.trimmed.hasSuffix("|") { values.removeLast() }
        return values.count >= 2 ? values : nil
    }
    public static func inline(_ value: String) -> AttributedString {
        // Text never executes HTML or downloads Markdown images.
        (try? AttributedString(
            markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(value)
    }
}
