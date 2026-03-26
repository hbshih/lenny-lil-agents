import AppKit
import Foundation

struct Options {
    var inputPath: String
    var outputPath: String?
    var force = false
}

enum ConversionError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case unreadableImage(String)
    case pngEncodingFailed(String)

    var description: String {
        switch self {
        case .invalidArguments(let message):
            return message
        case .unreadableImage(let path):
            return "Could not read image at \(path)"
        case .pngEncodingFailed(let path):
            return "Could not encode PNG for \(path)"
        }
    }
}

func parseOptions() throws -> Options {
    let args = Array(CommandLine.arguments.dropFirst())
    guard !args.isEmpty else {
        throw ConversionError.invalidArguments("""
        Usage:
          swift Scripts/convert_avatars_to_png.swift <input-path> [output-path] [--force]

        Examples:
          swift Scripts/convert_avatars_to_png.swift /path/to/avatars
          swift Scripts/convert_avatars_to_png.swift /path/to/avatars /path/to/png-avatars
          swift Scripts/convert_avatars_to_png.swift /path/to/avatar.webp /path/to/avatar.png --force
        """)
    }

    var positional: [String] = []
    var force = false

    for arg in args {
        if arg == "--force" {
            force = true
        } else {
            positional.append(arg)
        }
    }

    guard let inputPath = positional.first else {
        throw ConversionError.invalidArguments("Missing input path.")
    }

    return Options(
        inputPath: inputPath,
        outputPath: positional.count > 1 ? positional[1] : nil,
        force: force
    )
}

func isImageFile(_ url: URL) -> Bool {
    let supported = Set(["webp", "png", "jpg", "jpeg", "gif", "tiff", "bmp", "heic"])
    return supported.contains(url.pathExtension.lowercased())
}

func outputURL(for inputURL: URL, baseOutputPath: String?) -> URL {
    if let baseOutputPath {
        let outputBaseURL = URL(fileURLWithPath: baseOutputPath, isDirectory: true)
        return outputBaseURL.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent + ".png")
    }

    return inputURL.deletingPathExtension().appendingPathExtension("png")
}

func convertImage(at inputURL: URL, to outputURL: URL, force: Bool) throws -> Bool {
    if FileManager.default.fileExists(atPath: outputURL.path), !force {
        return false
    }

    guard let image = NSImage(contentsOf: inputURL) else {
        throw ConversionError.unreadableImage(inputURL.path)
    }
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw ConversionError.pngEncodingFailed(inputURL.path)
    }

    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try pngData.write(to: outputURL)
    return true
}

func convertDirectory(inputURL: URL, outputPath: String?, force: Bool) throws {
    let files = try FileManager.default.contentsOfDirectory(at: inputURL, includingPropertiesForKeys: nil)
        .filter { isImageFile($0) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var converted = 0
    var skipped = 0

    for file in files {
        let destination = outputURL(for: file, baseOutputPath: outputPath)
        let didConvert = try convertImage(at: file, to: destination, force: force)
        if didConvert {
            converted += 1
            print("converted \(file.lastPathComponent) -> \(destination.lastPathComponent)")
        } else {
            skipped += 1
            print("skipped \(file.lastPathComponent)")
        }
    }

    print("done: converted \(converted), skipped \(skipped)")
}

func convertSingleFile(inputURL: URL, outputPath: String?, force: Bool) throws {
    let destination: URL
    if let outputPath, outputPath.lowercased().hasSuffix(".png") {
        destination = URL(fileURLWithPath: outputPath)
    } else {
        destination = outputURL(for: inputURL, baseOutputPath: outputPath)
    }

    let didConvert = try convertImage(at: inputURL, to: destination, force: force)
    print(didConvert ? "converted \(inputURL.lastPathComponent) -> \(destination.path)" : "skipped \(inputURL.lastPathComponent)")
}

do {
    let options = try parseOptions()
    let inputURL = URL(fileURLWithPath: options.inputPath)

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory) else {
        throw ConversionError.invalidArguments("Input path does not exist: \(options.inputPath)")
    }

    if isDirectory.boolValue {
        try convertDirectory(inputURL: inputURL, outputPath: options.outputPath, force: options.force)
    } else {
        try convertSingleFile(inputURL: inputURL, outputPath: options.outputPath, force: options.force)
    }
} catch let error as ConversionError {
    fputs("error: \(error.description)\n", stderr)
    exit(1)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
