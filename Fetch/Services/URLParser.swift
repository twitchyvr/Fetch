import Foundation

/// Intelligently extracts URLs from any text format: plain text, JSON arrays, CSV, mixed content.
enum URLParser {

    /// Extract all valid http/https URLs from arbitrary text input.
    /// Handles: one-per-line, JSON arrays, CSV, mixed prose, and file contents.
    static func extractURLs(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var urls: [String] = []

        // Try JSON array first: ["url1", "url2", ...]
        if trimmed.hasPrefix("[") {
            if let data = trimmed.data(using: .utf8),
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
                urls = jsonArray.compactMap { validateURL($0) }
                if !urls.isEmpty { return deduplicate(urls) }
            }
            // Also try JSON array of objects with "url" key
            if let data = trimmed.data(using: .utf8),
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                urls = jsonArray.compactMap { dict in
                    (dict["url"] as? String).flatMap { validateURL($0) }
                }
                if !urls.isEmpty { return deduplicate(urls) }
            }
        }

        // Regex extraction: find all http/https URLs in arbitrary text
        let pattern = #"https?://[^\s<>\"\'\]\)\},]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches {
            let urlString = nsText.substring(with: match.range)
            // Clean trailing punctuation that may have been captured
            let cleaned = urlString
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?)]}"))
            if let valid = validateURL(cleaned) {
                urls.append(valid)
            }
        }

        return deduplicate(urls)
    }

    /// Extract URLs from a file at the given path. Supports .txt, .json, .csv.
    static func extractURLs(fromFileAt path: String) -> [String] {
        guard let data = FileManager.default.contents(atPath: path),
              let text = String(data: data, encoding: .utf8)
        else { return [] }
        return extractURLs(from: text)
    }

    /// Validate that a string is a well-formed http/https URL.
    private static func validateURL(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              url.host != nil
        else { return nil }
        return trimmed
    }

    /// Remove duplicates while preserving order.
    private static func deduplicate(_ urls: [String]) -> [String] {
        var seen = Set<String>()
        return urls.filter { url in
            let normalized = url.lowercased()
            guard !seen.contains(normalized) else { return false }
            seen.insert(normalized)
            return true
        }
    }
}
