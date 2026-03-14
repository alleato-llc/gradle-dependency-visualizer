import Foundation
import GradleDependencyVisualizerCore

public enum GradleProjectListParser {
    private static let projectPattern = try! NSRegularExpression(
        pattern: #"[+\\]--- Project '([^']+)'"#
    )

    public static func parse(output: String) -> [GradleModule] {
        var modules: [GradleModule] = []

        for line in output.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = projectPattern.firstMatch(in: line, range: range),
                  let pathRange = Range(match.range(at: 1), in: line) else {
                continue
            }

            let path = String(line[pathRange])
            let name = path.split(separator: ":").last.map(String.init) ?? path
            modules.append(GradleModule(name: name, path: path))
        }

        return modules
    }
}
