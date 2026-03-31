import AppKit

func resolvedAvatarImage(at path: String) -> NSImage? {
    let resolvedPath = pngAvatarPath(for: path) ?? path
    return NSImage(contentsOfFile: resolvedPath)
}

func pngAvatarPath(for path: String) -> String? {
    guard path.lowercased().hasSuffix(".webp"),
          let image = NSImage(contentsOfFile: path),
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return nil
    }

    let cacheDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lenny-avatar-cache", isDirectory: true)
    try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

    let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent + ".png"
    let pngURL = cacheDir.appendingPathComponent(fileName)

    if !FileManager.default.fileExists(atPath: pngURL.path) {
        try? pngData.write(to: pngURL)
    }

    return pngURL.path
}
