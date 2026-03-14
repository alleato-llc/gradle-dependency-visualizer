import Foundation

public enum GradleBuildFileParser {
    public struct DependencyDeclaration: Sendable, Hashable {
        public let configuration: String
        public let group: String
        public let artifact: String
        public let version: String
        public let line: Int

        public init(configuration: String, group: String, artifact: String, version: String, line: Int) {
            self.configuration = configuration
            self.group = group
            self.artifact = artifact
            self.version = version
            self.line = line
        }
    }

    private static let configurations = "implementation|testImplementation|api|compileOnly|runtimeOnly|annotationProcessor"

    // Groovy string: implementation 'g:a:v' or implementation "g:a:v"
    private static let groovyStringPattern = try! NSRegularExpression(
        pattern: #"(\#(configurations))\s+['\"]([^:]+):([^:]+):([^'"]+)['\"]"#
            .replacingOccurrences(of: #"\#(configurations)"#, with: configurations),
        options: []
    )

    // Kotlin DSL: implementation("g:a:v")
    private static let kotlinDSLPattern = try! NSRegularExpression(
        pattern: "(\(configurations))\\s*\\(\\s*[\"']([^:]+):([^:]+):([^\"']+)[\"']\\s*\\)",
        options: []
    )

    // Groovy map: implementation group: 'g', name: 'a', version: 'v'
    private static let groovyMapPattern = try! NSRegularExpression(
        pattern: "(\(configurations))\\s+group:\\s*['\"]([^'\"]+)['\"]\\s*,\\s*name:\\s*['\"]([^'\"]+)['\"]\\s*,\\s*version:\\s*['\"]([^'\"]+)['\"]",
        options: []
    )

    public static func parseDependencies(from content: String) -> [DependencyDeclaration] {
        let lines = content.components(separatedBy: .newlines)
        var results: [DependencyDeclaration] = []
        var inBlockComment = false

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Track block comments
            if trimmed.contains("/*") {
                inBlockComment = true
            }
            if trimmed.contains("*/") {
                inBlockComment = false
                continue
            }
            if inBlockComment { continue }

            // Skip line comments
            if trimmed.hasPrefix("//") { continue }

            let lineNumber = index + 1
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)

            for pattern in [groovyStringPattern, kotlinDSLPattern, groovyMapPattern] {
                if let match = pattern.firstMatch(in: line, options: [], range: range) {
                    let config = nsLine.substring(with: match.range(at: 1))
                    let group = nsLine.substring(with: match.range(at: 2))
                    let artifact = nsLine.substring(with: match.range(at: 3))
                    let version = nsLine.substring(with: match.range(at: 4))
                    results.append(DependencyDeclaration(
                        configuration: config,
                        group: group,
                        artifact: artifact,
                        version: version,
                        line: lineNumber
                    ))
                    break
                }
            }
        }

        return results
    }
}
