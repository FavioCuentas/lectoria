import SwiftUI

extension AttributedString {
    /// Interpreta Markdown inline (negritas, cursivas, código) conservando los saltos de línea,
    /// para mostrar respuestas de IA/traducción sin asteriscos crudos.
    /// Si el parseo falla, devuelve el texto plano original.
    static func inlineMarkdown(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(string)
    }
}
