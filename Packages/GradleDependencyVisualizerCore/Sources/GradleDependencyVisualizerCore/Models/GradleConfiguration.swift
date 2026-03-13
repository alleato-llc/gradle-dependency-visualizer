public enum GradleConfiguration: String, Sendable, CaseIterable {
    case compileClasspath
    case runtimeClasspath
    case implementationDependenciesMetadata
    case testCompileClasspath
    case testRuntimeClasspath
    case annotationProcessor
    case compileOnly
    case runtimeOnly
    case implementation
    case testImplementation
    case api

    public var displayName: String {
        switch self {
        case .compileClasspath: "Compile Classpath"
        case .runtimeClasspath: "Runtime Classpath"
        case .implementationDependenciesMetadata: "Implementation Dependencies Metadata"
        case .testCompileClasspath: "Test Compile Classpath"
        case .testRuntimeClasspath: "Test Runtime Classpath"
        case .annotationProcessor: "Annotation Processor"
        case .compileOnly: "Compile Only"
        case .runtimeOnly: "Runtime Only"
        case .implementation: "Implementation"
        case .testImplementation: "Test Implementation"
        case .api: "API"
        }
    }

    public var description: String {
        switch self {
        case .compileClasspath:
            "Resolved dependencies needed to compile main source code. This is the most common view — it shows what your code compiles against."
        case .runtimeClasspath:
            "Resolved dependencies needed at runtime. Includes compile dependencies plus runtime-only additions."
        case .implementationDependenciesMetadata:
            "Internal Gradle metadata for dependency resolution. Rarely useful for manual inspection."
        case .testCompileClasspath:
            "Resolved dependencies needed to compile test source code. Includes main compile dependencies plus test-only additions."
        case .testRuntimeClasspath:
            "Resolved dependencies needed to run tests. The most complete test dependency view."
        case .annotationProcessor:
            "Dependencies used for compile-time annotation processing (e.g., Lombok, Dagger, MapStruct)."
        case .compileOnly:
            "Dependencies available at compile time but not packaged at runtime (e.g., provided by the container)."
        case .runtimeOnly:
            "Dependencies not needed for compilation but required at runtime (e.g., JDBC drivers, logging backends)."
        case .implementation:
            "Declared implementation dependencies before Gradle resolves the full classpath. Shows your direct declarations."
        case .testImplementation:
            "Declared test dependencies before resolution. Shows what you explicitly added for testing."
        case .api:
            "Dependencies exposed to consumers of your library. Only applicable to projects using the java-library plugin."
        }
    }
}
