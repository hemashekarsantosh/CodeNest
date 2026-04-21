//
//  ShellGrammar.swift
//  CodeNest
//

import Foundation

struct ShellGrammar: SyntaxGrammar {
    let rules: [SyntaxRule]

    init() {
        rules = [
            // 1. Comments # ...
            SyntaxRule(
                pattern: #"#.*$"#,
                options: .anchorsMatchLines,
                tokenType: .comment
            ),
            // 2. Double-quoted strings "..."
            SyntaxRule(
                pattern: #""(?:[^"\\]|\\.)*""#,
                tokenType: .string
            ),
            // 3. Single-quoted strings '...' (no escapes inside)
            SyntaxRule(
                pattern: #"'[^']*'"#,
                tokenType: .string
            ),
            // 4. Variable references $VAR, ${VAR}, $1, $@, $#, $?
            SyntaxRule(
                pattern: #"\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*|\$[0-9@#?*$!-]"#,
                tokenType: .attribute
            ),
            // 5. Keywords / builtins
            SyntaxRule(
                pattern: #"\b(alias|bg|bind|break|builtin|caller|case|cd|command|compgen|complete|continue|declare|dirs|disown|do|done|echo|elif|else|enable|esac|eval|exec|exit|export|false|fc|fg|fi|for|function|getopts|hash|help|history|if|in|jobs|kill|let|local|logout|mapfile|popd|printf|pushd|pwd|read|readarray|readonly|return|select|set|shift|shopt|source|suspend|test|then|time|times|trap|true|type|typeset|ulimit|umask|unalias|unset|until|wait|while)\b"#,
                tokenType: .keyword
            ),
            // 6. Numbers
            SyntaxRule(
                pattern: #"\b\d+\b"#,
                tokenType: .number
            ),
        ]
    }
}
