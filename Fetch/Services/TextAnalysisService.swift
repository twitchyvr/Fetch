import Foundation
import NaturalLanguage

/// Uses Apple's NaturalLanguage framework for text analysis on video descriptions and transcripts.
enum TextAnalysisService {

    // MARK: - Language Detection

    /// Detect the dominant language of a text.
    static func detectLanguage(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let lang = recognizer.dominantLanguage else { return nil }
        return Locale.current.localizedString(forIdentifier: lang.rawValue)
    }

    // MARK: - Keyword Extraction

    /// Extract key topics/entities from text using NLTagger.
    static func extractKeywords(from text: String, limit: Int = 10) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text

        var keywords: [String: Int] = [:]
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
                let word = String(text[range])
                keywords[word, default: 0] += 1
            }
            return true
        }

        // Also get nouns as topics
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if tag == .noun {
                let word = String(text[range])
                if word.count > 3 {
                    keywords[word, default: 0] += 1
                }
            }
            return true
        }

        return keywords.sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }

    // MARK: - Sentiment Analysis

    /// Analyze the sentiment of text (positive/negative/neutral).
    static func analyzeSentiment(_ text: String) -> SentimentResult {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        var scores: [Double] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag, let score = Double(tag.rawValue) {
                scores.append(score)
            }
            return true
        }

        let avg = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        if avg > 0.1 { return .positive(avg) }
        if avg < -0.1 { return .negative(avg) }
        return .neutral
    }

    enum SentimentResult {
        case positive(Double)
        case negative(Double)
        case neutral

        var label: String {
            switch self {
            case .positive: "Positive"
            case .negative: "Negative"
            case .neutral: "Neutral"
            }
        }

        var icon: String {
            switch self {
            case .positive: "hand.thumbsup.fill"
            case .negative: "hand.thumbsdown.fill"
            case .neutral: "minus.circle"
            }
        }
    }

    // MARK: - Summary Generation

    /// Generate a simple extractive summary by selecting the most important sentences.
    static func summarize(_ text: String, sentenceCount: Int = 3) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [(String, Double)] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count > 20 {
                // Score by length (longer = more info) and position (earlier = more important)
                let positionScore = 1.0 - Double(sentences.count) * 0.1
                let lengthScore = min(Double(sentence.count) / 200.0, 1.0)
                sentences.append((sentence, positionScore + lengthScore))
            }
            return true
        }

        return sentences.sorted { $0.1 > $1.1 }
            .prefix(sentenceCount)
            .map(\.0)
            .joined(separator: " ")
    }

    // MARK: - Content Insights

    /// Generate a set of insights about a video based on its description.
    static func generateInsights(title: String, description: String?, uploader: String?) -> [ContentInsight] {
        var insights: [ContentInsight] = []

        // Language detection
        let textToAnalyze = [title, description ?? ""].joined(separator: " ")
        if let lang = detectLanguage(textToAnalyze) {
            insights.append(ContentInsight(icon: "globe", label: "Language", value: lang))
        }

        // Keywords
        if let desc = description, !desc.isEmpty {
            let keywords = extractKeywords(from: desc, limit: 5)
            if !keywords.isEmpty {
                insights.append(ContentInsight(icon: "tag", label: "Topics", value: keywords.joined(separator: ", ")))
            }

            // Sentiment
            let sentiment = analyzeSentiment(desc)
            insights.append(ContentInsight(icon: sentiment.icon, label: "Tone", value: sentiment.label))

            // Summary
            let summary = summarize(desc, sentenceCount: 2)
            if !summary.isEmpty && summary.count > 30 {
                insights.append(ContentInsight(icon: "doc.text", label: "Summary", value: summary))
            }
        }

        return insights
    }

    struct ContentInsight: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let value: String
    }
}
