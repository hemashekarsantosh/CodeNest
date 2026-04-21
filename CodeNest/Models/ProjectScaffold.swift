//
//  ProjectScaffold.swift
//  CodeNest
//

import Foundation

// MARK: - Protocol

protocol ProjectScaffold {
    func files(options: ProjectOptions) -> [(relativePath: String, content: String)]
}

// MARK: - Factory

extension ProjectOptions {
    var scaffold: ProjectScaffold {
        switch framework {
        case .springBoot: return SpringBootScaffold()
        case .angular:    return AngularScaffold()
        case .react:      return ReactScaffold()
        }
    }
}

// MARK: - Spring Boot

struct SpringBootScaffold: ProjectScaffold {
    func files(options: ProjectOptions) -> [(relativePath: String, content: String)] {
        let name = options.name
        let group = options.groupId.isEmpty ? "com.example" : options.groupId
        let groupPath = group.replacingOccurrences(of: ".", with: "/")
        let className = name.prefix(1).uppercased() + name.dropFirst()

        var result: [(String, String)] = []

        if options.buildTool == .maven {
            result.append(("pom.xml", pomXML(group: group, artifact: name)))
        } else {
            result.append(("build.gradle", buildGradle(group: group, artifact: name)))
            result.append(("settings.gradle", "rootProject.name = '\(name)'\n"))
        }

        result.append((
            "src/main/java/\(groupPath)/\(name)/\(className)Application.java",
            applicationJava(package: "\(group).\(name)", className: "\(className)Application")
        ))
        result.append((
            "src/main/resources/application.properties",
            "# \(name) configuration\nspring.application.name=\(name)\n"
        ))
        result.append((
            "src/test/java/\(groupPath)/\(name)/\(className)ApplicationTests.java",
            applicationTestsJava(package: "\(group).\(name)", className: "\(className)Application")
        ))

        return result
    }

    private func pomXML(group: String, artifact: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <project xmlns="http://maven.apache.org/POM/4.0.0"
                 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                 xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
            <modelVersion>4.0.0</modelVersion>

            <parent>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter-parent</artifactId>
                <version>3.2.0</version>
                <relativePath/>
            </parent>

            <groupId>\(group)</groupId>
            <artifactId>\(artifact)</artifactId>
            <version>0.0.1-SNAPSHOT</version>
            <name>\(artifact)</name>
            <description>\(artifact) Spring Boot project</description>

            <properties>
                <java.version>17</java.version>
            </properties>

            <dependencies>
                <dependency>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-starter-web</artifactId>
                </dependency>
                <dependency>
                    <groupId>org.springframework.boot</groupId>
                    <artifactId>spring-boot-starter-test</artifactId>
                    <scope>test</scope>
                </dependency>
            </dependencies>

            <build>
                <plugins>
                    <plugin>
                        <groupId>org.springframework.boot</groupId>
                        <artifactId>spring-boot-maven-plugin</artifactId>
                    </plugin>
                </plugins>
            </build>
        </project>
        """
    }

    private func buildGradle(group: String, artifact: String) -> String {
        """
        plugins {
            id 'org.springframework.boot' version '3.2.0'
            id 'io.spring.dependency-management' version '1.1.4'
            id 'java'
        }

        group = '\(group)'
        version = '0.0.1-SNAPSHOT'
        sourceCompatibility = '17'

        repositories {
            mavenCentral()
        }

        dependencies {
            implementation 'org.springframework.boot:spring-boot-starter-web'
            testImplementation 'org.springframework.boot:spring-boot-starter-test'
        }

        tasks.named('test') {
            useJUnitPlatform()
        }
        """
    }

    private func applicationJava(package: String, className: String) -> String {
        """
        package \(package);

        import org.springframework.boot.SpringApplication;
        import org.springframework.boot.autoconfigure.SpringBootApplication;

        @SpringBootApplication
        public class \(className) {

            public static void main(String[] args) {
                SpringApplication.run(\(className).class, args);
            }
        }
        """
    }

    private func applicationTestsJava(package: String, className: String) -> String {
        """
        package \(package);

        import org.junit.jupiter.api.Test;
        import org.springframework.boot.test.context.SpringBootTest;

        @SpringBootTest
        class \(className)Tests {

            @Test
            void contextLoads() {
            }
        }
        """
    }
}

// MARK: - Angular

struct AngularScaffold: ProjectScaffold {
    func files(options: ProjectOptions) -> [(relativePath: String, content: String)] {
        let name = options.name
        return [
            ("package.json", packageJSON(name: name)),
            ("tsconfig.json", tsconfig()),
            ("angular.json", angularJSON(name: name)),
            ("src/main.ts", mainTS(name: name)),
            ("src/index.html", indexHTML(name: name)),
            ("src/styles.css", "/* Global styles */\n"),
            ("src/app/app.module.ts", appModule(name: name)),
            ("src/app/app.component.ts", appComponentTS(name: name)),
            ("src/app/app.component.html", appComponentHTML(name: name)),
            ("src/app/app.component.css", "/* AppComponent styles */\n"),
        ]
    }

    private func packageJSON(name: String) -> String {
        """
        {
          "name": "\(name)",
          "version": "0.0.0",
          "scripts": {
            "ng": "ng",
            "start": "ng serve",
            "build": "ng build",
            "test": "ng test"
          },
          "dependencies": {
            "@angular/animations": "^17.0.0",
            "@angular/common": "^17.0.0",
            "@angular/compiler": "^17.0.0",
            "@angular/core": "^17.0.0",
            "@angular/forms": "^17.0.0",
            "@angular/platform-browser": "^17.0.0",
            "@angular/platform-browser-dynamic": "^17.0.0",
            "@angular/router": "^17.0.0",
            "rxjs": "~7.8.0",
            "tslib": "^2.3.0",
            "zone.js": "~0.14.0"
          },
          "devDependencies": {
            "@angular-devkit/build-angular": "^17.0.0",
            "@angular/cli": "^17.0.0",
            "@angular/compiler-cli": "^17.0.0",
            "typescript": "~5.2.2"
          }
        }
        """
    }

    private func tsconfig() -> String {
        """
        {
          "compileOnSave": false,
          "compilerOptions": {
            "outDir": "./dist/out-tsc",
            "strict": true,
            "noImplicitOverride": true,
            "noPropertyAccessFromIndexSignature": true,
            "noImplicitReturns": true,
            "noFallthroughCasesInSwitch": true,
            "skipLibCheck": true,
            "esModuleInterop": true,
            "sourceMap": true,
            "declaration": false,
            "experimentalDecorators": true,
            "moduleResolution": "bundler",
            "importHelpers": true,
            "target": "ES2022",
            "module": "ES2022",
            "lib": ["ES2022", "dom"]
          },
          "angularCompilerOptions": {
            "enableI18nLegacyMessageIdFormat": false,
            "strictInjectionParameters": true,
            "strictInputAccessModifiers": true,
            "strictTemplates": true
          }
        }
        """
    }

    private func angularJSON(name: String) -> String {
        """
        {
          "$schema": "./node_modules/@angular/cli/lib/config/schema.json",
          "version": 1,
          "newProjectRoot": "projects",
          "projects": {
            "\(name)": {
              "projectType": "application",
              "root": "",
              "sourceRoot": "src",
              "prefix": "app",
              "architect": {
                "build": {
                  "builder": "@angular-devkit/build-angular:application",
                  "options": {
                    "outputPath": "dist/\(name)",
                    "index": "src/index.html",
                    "browser": "src/main.ts",
                    "polyfills": ["zone.js"],
                    "tsConfig": "tsconfig.json",
                    "styles": ["src/styles.css"],
                    "scripts": []
                  }
                },
                "serve": {
                  "builder": "@angular-devkit/build-angular:dev-server",
                  "configurations": {
                    "production": { "buildTarget": "\(name):build:production" },
                    "development": { "buildTarget": "\(name):build:development" }
                  },
                  "defaultConfiguration": "development"
                }
              }
            }
          }
        }
        """
    }

    private func mainTS(name: String) -> String {
        """
        import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
        import { AppModule } from './app/app.module';

        platformBrowserDynamic().bootstrapModule(AppModule)
          .catch(err => console.error(err));
        """
    }

    private func indexHTML(name: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>\(name)</title>
          <base href="/">
          <meta name="viewport" content="width=device-width, initial-scale=1">
        </head>
        <body>
          <app-root></app-root>
        </body>
        </html>
        """
    }

    private func appModule(name: String) -> String {
        """
        import { NgModule } from '@angular/core';
        import { BrowserModule } from '@angular/platform-browser';
        import { AppComponent } from './app.component';

        @NgModule({
          declarations: [AppComponent],
          imports: [BrowserModule],
          providers: [],
          bootstrap: [AppComponent]
        })
        export class AppModule { }
        """
    }

    private func appComponentTS(name: String) -> String {
        """
        import { Component } from '@angular/core';

        @Component({
          selector: 'app-root',
          templateUrl: './app.component.html',
          styleUrls: ['./app.component.css']
        })
        export class AppComponent {
          title = '\(name)';
        }
        """
    }

    private func appComponentHTML(name: String) -> String {
        """
        <div style="text-align:center; padding: 2rem;">
          <h1>Welcome to {{ title }}!</h1>
          <p>Start editing <code>src/app/app.component.ts</code> to get started.</p>
        </div>
        """
    }
}

// MARK: - React

struct ReactScaffold: ProjectScaffold {
    func files(options: ProjectOptions) -> [(relativePath: String, content: String)] {
        let name = options.name
        let useTS = options.useTypeScript
        let ext = useTS ? "tsx" : "jsx"
        let indexExt = useTS ? "tsx" : "jsx"

        var result: [(String, String)] = [
            ("package.json", packageJSON(name: name, useTS: useTS)),
            ("public/index.html", indexHTML(name: name)),
            ("src/index.\(indexExt)", indexFile(name: name, useTS: useTS)),
            ("src/App.\(ext)", appFile(name: name)),
            ("src/App.css", appCSS()),
        ]

        if useTS {
            result.append(("tsconfig.json", tsconfig()))
        }

        return result
    }

    private func packageJSON(name: String, useTS: Bool) -> String {
        var devDeps = ""
        if useTS {
            devDeps = """
            ,
                "@types/react": "^18.2.0",
                "@types/react-dom": "^18.2.0",
                "typescript": "^5.2.2"
            """
        }
        return """
        {
          "name": "\(name)",
          "version": "0.1.0",
          "private": true,
          "dependencies": {
            "react": "^18.2.0",
            "react-dom": "^18.2.0",
            "react-scripts": "5.0.1"
          },
          "devDependencies": {
            "@vitejs/plugin-react": "^4.0.0",
            "vite": "^5.0.0"\(devDeps)
          },
          "scripts": {
            "start": "vite",
            "build": "vite build",
            "preview": "vite preview"
          },
          "browserslist": {
            "production": [">0.2%", "not dead", "not op_mini all"],
            "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
          }
        }
        """
    }

    private func tsconfig() -> String {
        """
        {
          "compilerOptions": {
            "target": "ES2020",
            "useDefineForClassFields": true,
            "lib": ["ES2020", "DOM", "DOM.Iterable"],
            "module": "ESNext",
            "skipLibCheck": true,
            "moduleResolution": "bundler",
            "allowImportingTsExtensions": true,
            "resolveJsonModule": true,
            "isolatedModules": true,
            "noEmit": true,
            "jsx": "react-jsx",
            "strict": true,
            "noUnusedLocals": true,
            "noUnusedParameters": true,
            "noFallthroughCasesInSwitch": true
          },
          "include": ["src"]
        }
        """
    }

    private func indexHTML(name: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <title>\(name)</title>
          </head>
          <body>
            <noscript>You need to enable JavaScript to run this app.</noscript>
            <div id="root"></div>
          </body>
        </html>
        """
    }

    private func indexFile(name: String, useTS: Bool) -> String {
        """
        import React from 'react';
        import ReactDOM from 'react-dom/client';
        import App from './App';
        import './App.css';

        const root = ReactDOM.createRoot(
          document.getElementById('root') as HTMLElement
        );
        root.render(
          <React.StrictMode>
            <App />
          </React.StrictMode>
        );
        """
    }

    private func appFile(name: String) -> String {
        """
        import React from 'react';
        import './App.css';

        function App() {
          return (
            <div className="App">
              <header className="App-header">
                <h1>Welcome to \(name)</h1>
                <p>Edit <code>src/App.tsx</code> and save to reload.</p>
              </header>
            </div>
          );
        }

        export default App;
        """
    }

    private func appCSS() -> String {
        """
        .App {
          text-align: center;
        }

        .App-header {
          background-color: #282c34;
          min-height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          font-size: calc(10px + 2vmin);
          color: white;
        }

        .App-header code {
          background: rgba(255,255,255,0.1);
          padding: 2px 6px;
          border-radius: 4px;
        }
        """
    }
}
