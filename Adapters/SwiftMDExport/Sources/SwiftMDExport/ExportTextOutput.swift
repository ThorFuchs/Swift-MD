// SPDX-License-Identifier: Apache-2.0
import Foundation

public enum ExportLineEndings: String, CaseIterable, Identifiable, Hashable, Sendable {
    case lf = "Unix (LF)", crlf = "Windows (CRLF)"
    public var id: Self { self }
}

public enum ExportTextOutput {
    /// Only for explicitly selected text export variants, not Save As,
    /// exact Typst inputs or raw native XML serialization.
    public static func encode(_ text: String, lineEndings: ExportLineEndings = .lf) -> Data {
        let lf = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return Data((lineEndings == .lf ? lf : lf.replacingOccurrences(of: "\n", with: "\r\n")).utf8)
    }

    /// Fixed article envelope around the actual backend fragment. Never
    /// executes TeX, follows image references, or promises compilability of
    /// arbitrary Unicode, extensions or literal code from the source.
    public static func latexArticle(_ fragment: String, letter: Bool = false) -> String {
        let paper = letter ? "letterpaper" : "a4paper"
        return """
        % Generated source. Review before compiling; do not enable shell escape.
        \\documentclass[11pt,\(paper)]{article}
        \\usepackage[T1]{fontenc}
        \\usepackage[utf8]{inputenc}
        \\usepackage{textcomp}
        \\usepackage{amsmath,amssymb}
        \\usepackage{graphicx}
        \\usepackage{longtable,booktabs}
        \\usepackage[normalem]{ulem}
        \\usepackage{hyperref}
        \\begin{document}

        \(fragment)

        \\end{document}

        """
    }
}
