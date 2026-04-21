//
//  ProjectTemplate.swift
//  CodeNest
//

import Foundation

enum Framework: String, CaseIterable, Identifiable {
    case springBoot = "Spring Boot"
    case angular    = "Angular"
    case react      = "React"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .springBoot: return "leaf.fill"
        case .angular:    return "shield.fill"
        case .react:      return "atom"
        }
    }
}

enum BuildTool: String, CaseIterable, Identifiable {
    case maven  = "Maven"
    case gradle = "Gradle"
    var id: String { rawValue }
}

struct ProjectOptions {
    var name: String         = ""
    var framework: Framework = .springBoot
    // Spring Boot
    var groupId: String      = "com.example"
    var buildTool: BuildTool = .maven
    var springBootVersion: String = "3.4.4"   // updated when metadata loads
    var javaVersion: String       = "21"       // updated when metadata loads
    // React
    var useTypeScript: Bool  = true
}
