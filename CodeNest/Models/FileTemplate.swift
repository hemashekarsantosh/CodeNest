//
//  FileTemplate.swift
//  CodeNest
//

import Foundation

struct FileTemplate: Identifiable, Hashable {
    let id: String
    let label: String
    let makeContent: (String) -> String
    /// If non-nil, a "Generate main method" checkbox is shown when this template is selected.
    let makeContentWithMain: ((String) -> String)?

    init(id: String, label: String, makeContent: @escaping (String) -> String, makeContentWithMain: ((String) -> String)? = nil) {
        self.id = id
        self.label = label
        self.makeContent = makeContent
        self.makeContentWithMain = makeContentWithMain
    }

    static func == (lhs: FileTemplate, rhs: FileTemplate) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Returns templates for the given file extension, or nil if no templates exist (plain file).
    static func templates(for ext: String) -> [FileTemplate]? {
        switch ext.lowercased() {
        case "swift": return swiftTemplates
        case "java":  return javaTemplates
        case "ts":    return typescriptTemplates
        case "js":    return javascriptTemplates
        default:      return nil
        }
    }

    // MARK: - Swift

    private static let swiftTemplates: [FileTemplate] = [
        FileTemplate(id: "swift.plain", label: "Plain File") { _ in "" },
        FileTemplate(id: "swift.class", label: "Class",
            makeContent: { name in
                """
                import Foundation

                class \(name) {
                    init() {
                    }
                }
                """
            },
            makeContentWithMain: { name in
                """
                import Foundation

                class \(name) {
                    init() {
                    }

                    static func main() {
                        let instance = \(name)()
                        print("Hello from \\(\(name).self)!")
                    }
                }

                \(name).main()
                """
            }
        ),
        FileTemplate(id: "swift.struct", label: "Struct") { name in
            """
            import Foundation

            struct \(name) {
            }
            """
        },
        FileTemplate(id: "swift.protocol", label: "Protocol") { name in
            """
            import Foundation

            protocol \(name) {
            }
            """
        },
        FileTemplate(id: "swift.enum", label: "Enum") { name in
            """
            import Foundation

            enum \(name) {
            }
            """
        },
        FileTemplate(id: "swift.actor", label: "Actor") { name in
            """
            import Foundation

            actor \(name) {
                init() {
                }
            }
            """
        },
    ]

    // MARK: - Java

    private static let javaTemplates: [FileTemplate] = [
        FileTemplate(id: "java.class", label: "Class",
            makeContent: { name in
                """
                public class \(name) {

                    public \(name)() {
                    }
                }
                """
            },
            makeContentWithMain: { name in
                """
                public class \(name) {

                    public \(name)() {
                    }

                    public static void main(String[] args) {
                        System.out.println("Hello from \(name)!");
                    }
                }
                """
            }
        ),
        FileTemplate(id: "java.interface", label: "Interface") { name in
            """
            public interface \(name) {
            }
            """
        },
        FileTemplate(id: "java.record", label: "Record") { name in
            """
            public record \(name)() {
            }
            """
        },
        FileTemplate(id: "java.enum", label: "Enum") { name in
            """
            public enum \(name) {
            }
            """
        },
        FileTemplate(id: "java.abstract", label: "Abstract Class") { name in
            """
            public abstract class \(name) {
            }
            """
        },
    ]

    // MARK: - TypeScript

    private static let typescriptTemplates: [FileTemplate] = [
        FileTemplate(id: "ts.plain", label: "Plain File") { _ in "" },
        FileTemplate(id: "ts.class", label: "Class",
            makeContent: { name in
                """
                export class \(name) {
                    constructor() {
                    }
                }
                """
            },
            makeContentWithMain: { name in
                """
                export class \(name) {
                    constructor() {
                    }

                    static main(): void {
                        console.log(`Hello from \(name)!`);
                    }
                }

                \(name).main();
                """
            }
        ),
        FileTemplate(id: "ts.interface", label: "Interface") { name in
            """
            export interface \(name) {
            }
            """
        },
        FileTemplate(id: "ts.type", label: "Type Alias") { name in
            """
            export type \(name) = {
            };
            """
        },
        FileTemplate(id: "ts.enum", label: "Enum") { name in
            """
            export enum \(name) {
            }
            """
        },
    ]

    // MARK: - JavaScript

    private static let javascriptTemplates: [FileTemplate] = [
        FileTemplate(id: "js.plain", label: "Plain File") { _ in "" },
        FileTemplate(id: "js.class", label: "ES6 Class",
            makeContent: { name in
                """
                export class \(name) {
                    constructor() {
                    }
                }
                """
            },
            makeContentWithMain: { name in
                """
                export class \(name) {
                    constructor() {
                    }

                    static main() {
                        console.log(`Hello from \(name)!`);
                    }
                }

                \(name).main();
                """
            }
        ),
        FileTemplate(id: "js.module", label: "ES6 Module") { name in
            """
            // \(name)

            export default {
            };
            """
        },
    ]
}
