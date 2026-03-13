import Foundation
import Testing
import GradleDependencyVisualizerCore
import GradleDependencyVisualizerServices
import GradleDependencyVisualizerTestSupport

@Suite
struct JsonTreeImporterTests {
    // MARK: - Error handling

    @Test
    func invalidJSONThrowsDecodingError() {
        let data = Data("not json".utf8)
        #expect(throws: DecodingError.self) {
            try JsonTreeImporter.importTree(from: data)
        }
    }

    @Test
    func emptyObjectThrowsDecodingError() {
        let data = Data("{}".utf8)
        #expect(throws: DecodingError.self) {
            try JsonTreeImporter.importTree(from: data)
        }
    }

    @Test
    func missingRootsFieldThrowsDecodingError() {
        let json = """
        {"projectName": "test", "configuration": "compileClasspath", "conflicts": []}
        """
        #expect(throws: DecodingError.self) {
            try JsonTreeImporter.importTree(from: Data(json.utf8))
        }
    }

    @Test
    func missingConfigurationFieldThrowsDecodingError() {
        let json = """
        {"projectName": "test", "roots": [], "conflicts": []}
        """
        #expect(throws: DecodingError.self) {
            try JsonTreeImporter.importTree(from: Data(json.utf8))
        }
    }

    @Test
    func invalidConfigurationValueThrowsDecodingError() {
        let json = """
        {"projectName": "test", "configuration": "nonExistentConfig", "roots": [], "conflicts": []}
        """
        #expect(throws: DecodingError.self) {
            try JsonTreeImporter.importTree(from: Data(json.utf8))
        }
    }

    @Test
    func emptyDataThrowsDecodingError() {
        #expect(throws: DecodingError.self) {
            try JsonTreeImporter.importTree(from: Data())
        }
    }

    // MARK: - Successful import

    @Test
    func importsMinimalValidTree() throws {
        let json = """
        {
            "projectName": "minimal",
            "configuration": "compileClasspath",
            "roots": [],
            "conflicts": []
        }
        """
        let tree = try JsonTreeImporter.importTree(from: Data(json.utf8))

        #expect(tree.projectName == "minimal")
        #expect(tree.configuration == .compileClasspath)
        #expect(tree.roots.isEmpty)
        #expect(tree.conflicts.isEmpty)
    }

    @Test
    func importsNodeWithAllFields() throws {
        let json = """
        {
            "projectName": "test",
            "configuration": "runtimeClasspath",
            "roots": [{
                "group": "com.example",
                "artifact": "lib",
                "requestedVersion": "1.0.0",
                "resolvedVersion": "2.0.0",
                "isOmitted": true,
                "isConstraint": true,
                "children": []
            }],
            "conflicts": []
        }
        """
        let tree = try JsonTreeImporter.importTree(from: Data(json.utf8))
        let node = tree.roots[0]

        #expect(node.group == "com.example")
        #expect(node.artifact == "lib")
        #expect(node.requestedVersion == "1.0.0")
        #expect(node.resolvedVersion == "2.0.0")
        #expect(node.isOmitted == true)
        #expect(node.isConstraint == true)
    }

    @Test
    func importsConflictWithAllFields() throws {
        let json = """
        {
            "projectName": "test",
            "configuration": "compileClasspath",
            "roots": [],
            "conflicts": [{
                "coordinate": "com.example:lib",
                "requestedVersion": "1.0.0",
                "resolvedVersion": "2.0.0",
                "requestedBy": "com.parent:parent"
            }]
        }
        """
        let tree = try JsonTreeImporter.importTree(from: Data(json.utf8))
        let conflict = tree.conflicts[0]

        #expect(conflict.coordinate == "com.example:lib")
        #expect(conflict.requestedVersion == "1.0.0")
        #expect(conflict.resolvedVersion == "2.0.0")
        #expect(conflict.requestedBy == "com.parent:parent")
    }

    @Test
    func importedNodeGetsUniqueId() throws {
        let json = """
        {
            "projectName": "test",
            "configuration": "compileClasspath",
            "roots": [{
                "group": "com.example",
                "artifact": "lib",
                "requestedVersion": "1.0.0",
                "isOmitted": false,
                "isConstraint": false,
                "children": []
            }],
            "conflicts": []
        }
        """
        let tree1 = try JsonTreeImporter.importTree(from: Data(json.utf8))
        let tree2 = try JsonTreeImporter.importTree(from: Data(json.utf8))

        #expect(tree1.roots[0].id != tree2.roots[0].id)
    }

    @Test
    func importsNestedChildren() throws {
        let json = """
        {
            "projectName": "test",
            "configuration": "compileClasspath",
            "roots": [{
                "group": "com.a",
                "artifact": "a",
                "requestedVersion": "1.0",
                "isOmitted": false,
                "isConstraint": false,
                "children": [{
                    "group": "com.b",
                    "artifact": "b",
                    "requestedVersion": "2.0",
                    "isOmitted": false,
                    "isConstraint": false,
                    "children": [{
                        "group": "com.c",
                        "artifact": "c",
                        "requestedVersion": "3.0",
                        "isOmitted": false,
                        "isConstraint": false,
                        "children": []
                    }]
                }]
            }],
            "conflicts": []
        }
        """
        let tree = try JsonTreeImporter.importTree(from: Data(json.utf8))

        #expect(tree.roots[0].artifact == "a")
        #expect(tree.roots[0].children[0].artifact == "b")
        #expect(tree.roots[0].children[0].children[0].artifact == "c")
    }

    @Test
    func importsAllConfigurations() throws {
        for config in GradleConfiguration.allCases {
            let json = """
            {
                "projectName": "test",
                "configuration": "\(config.rawValue)",
                "roots": [],
                "conflicts": []
            }
            """
            let tree = try JsonTreeImporter.importTree(from: Data(json.utf8))
            #expect(tree.configuration == config)
        }
    }
}
