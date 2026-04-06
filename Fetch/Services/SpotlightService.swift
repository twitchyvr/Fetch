import CoreSpotlight
import UniformTypeIdentifiers

@MainActor
final class SpotlightService {
    static let shared = SpotlightService()

    private init() {}

    func indexDownload(
        title: String,
        url: String,
        outputPath: String?,
        extractor: String?,
        duration: Double?,
        thumbnailURL: String?
    ) {
        let item = CSSearchableItem(
            uniqueIdentifier: url,
            domainIdentifier: "com.mattrogers.Fetch.downloads",
            attributeSet: buildAttributes(
                title: title,
                url: url,
                outputPath: outputPath,
                extractor: extractor,
                duration: duration,
                thumbnailURL: thumbnailURL
            )
        )
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    func removeAll() {
        CSSearchableIndex.default().deleteAllSearchableItems()
    }

    func removeStaleItems(validPaths: [String]) {
        // Remove indexed items whose files no longer exist on disk
        let fm = FileManager.default
        let stalePaths = validPaths.filter { !fm.fileExists(atPath: $0) }
        guard !stalePaths.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: stalePaths)
    }

    private func buildAttributes(
        title: String,
        url: String,
        outputPath: String?,
        extractor: String?,
        duration: Double?,
        thumbnailURL: String?
    ) -> CSSearchableItemAttributeSet {
        let attrs = CSSearchableItemAttributeSet(contentType: .movie)
        attrs.title = title
        attrs.contentDescription = "Downloaded from \(extractor ?? "unknown") via Fetch"
        attrs.url = URL(string: url)
        if let path = outputPath {
            attrs.contentURL = URL(fileURLWithPath: path)
        }
        if let dur = duration {
            attrs.duration = NSNumber(value: dur)
        }
        if let thumb = thumbnailURL, let thumbURL = URL(string: thumb) {
            attrs.thumbnailURL = thumbURL
        }
        return attrs
    }
}
