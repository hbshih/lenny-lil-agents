import AppKit
import Foundation

struct RGBA {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8
}

let gridSize = 24
var overlayPixels = Array<RGBA?>(repeating: nil, count: gridSize * gridSize)
var templateMask = Array(repeating: false, count: gridSize * gridSize)

func hex(_ value: UInt32, alpha: UInt8 = 255) -> RGBA {
    RGBA(
        r: UInt8((value >> 16) & 0xFF),
        g: UInt8((value >> 8) & 0xFF),
        b: UInt8(value & 0xFF),
        a: alpha
    )
}

func index(_ x: Int, _ y: Int) -> Int {
    y * gridSize + x
}

func setPixel(_ x: Int, _ y: Int, _ color: RGBA) {
    guard (0..<gridSize).contains(x), (0..<gridSize).contains(y) else { return }
    overlayPixels[index(x, y)] = color
}

func setTemplatePixel(_ x: Int, _ y: Int, _ value: Bool = true) {
    guard (0..<gridSize).contains(x), (0..<gridSize).contains(y) else { return }
    templateMask[index(x, y)] = value
}

func fillRect(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: RGBA) {
    guard width > 0, height > 0 else { return }
    for py in y..<(y + height) {
        for px in x..<(x + width) {
            setPixel(px, py, color)
        }
    }
}

func fillTemplateRect(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ value: Bool = true) {
    guard width > 0, height > 0 else { return }
    for py in y..<(y + height) {
        for px in x..<(x + width) {
            setTemplatePixel(px, py, value)
        }
    }
}

func mirroredSet(_ x: Int, _ y: Int, _ color: RGBA) {
    setPixel(x, y, color)
    setPixel((gridSize - 1) - x, y, color)
}

func mirroredRect(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: RGBA) {
    fillRect(x, y, width, height, color)
    fillRect(gridSize - x - width, y, width, height, color)
}

let background = hex(0x1E2F68)
let hairDark = hex(0x3B1E18)
let hairMid = hex(0x6A372B)
let hairLight = hex(0x945645)
let skin = hex(0xF2B07A)
let skinShade = hex(0xC77853)
let eyeWhite = hex(0xFFF7E8)
let pupil = hex(0x191919)

func drawSprite() {
    // Hair silhouette and top spikes.
    fillRect(5, 2, 4, 1, hairDark)
    fillRect(10, 1, 3, 1, hairDark)
    fillRect(14, 2, 4, 1, hairDark)
    fillRect(4, 3, 15, 2, hairDark)
    fillRect(3, 5, 17, 2, hairDark)
    fillRect(3, 7, 3, 1, hairDark)
    fillRect(18, 7, 3, 1, hairDark)
    fillRect(6, 4, 8, 1, hairMid)
    fillRect(8, 3, 6, 1, hairLight)
    fillRect(14, 4, 3, 1, hairMid)
    fillRect(6, 2, 1, 1, hairMid)
    fillRect(16, 2, 1, 1, hairMid)
    setPixel(11, 0, hairLight)
    setPixel(12, 0, hairDark)

    // Face and ears.
    fillRect(5, 7, 14, 8, skin)
    fillRect(6, 15, 12, 2, skin)
    fillRect(7, 17, 10, 1, skin)
    fillRect(4, 10, 1, 4, skinShade)
    fillRect(19, 10, 1, 4, skinShade)
    fillRect(5, 10, 1, 4, skin)
    fillRect(18, 10, 1, 4, skin)
    fillRect(5, 14, 1, 1, skinShade)
    fillRect(18, 14, 1, 1, skinShade)

    // Jaw shading.
    fillRect(6, 15, 2, 1, skinShade)
    fillRect(16, 15, 2, 1, skinShade)
    fillRect(8, 16, 8, 1, skinShade)

    // Eyebrows.
    fillRect(7, 9, 4, 1, hairMid)
    fillRect(13, 9, 4, 1, hairMid)
    setPixel(11, 9, hairLight)

    // Eyes.
    fillRect(7, 11, 3, 2, eyeWhite)
    fillRect(14, 11, 3, 2, eyeWhite)
    fillRect(8, 11, 1, 2, pupil)
    fillRect(15, 11, 1, 2, pupil)
    setPixel(9, 12, skinShade)
    setPixel(14, 12, skinShade)

    // Nose and cheeks.
    fillRect(11, 12, 2, 2, skinShade)
    setPixel(10, 13, skinShade)
    setPixel(13, 13, skinShade)

    // Beard and moustache.
    fillRect(6, 14, 3, 1, hairDark)
    fillRect(15, 14, 3, 1, hairDark)
    fillRect(8, 15, 8, 1, hairDark)
    fillRect(7, 16, 10, 2, hairDark)
    fillRect(6, 17, 12, 1, hairDark)
    fillRect(8, 18, 8, 1, hairDark)
    fillRect(8, 14, 2, 1, hairMid)
    fillRect(14, 14, 2, 1, hairMid)
    fillRect(10, 15, 4, 1, hairMid)
    setPixel(11, 14, hairMid)
    setPixel(12, 14, hairMid)
    setPixel(11, 16, skin)
    setPixel(12, 16, skin)
    setPixel(11, 17, skinShade)
    setPixel(12, 17, skinShade)

    // Neck shadow.
    fillRect(9, 18, 6, 1, skinShade)

    // Side hair framing the face.
    fillRect(4, 8, 2, 2, hairDark)
    fillRect(18, 8, 2, 2, hairDark)
    fillRect(5, 7, 1, 1, hairMid)
    fillRect(18, 7, 1, 1, hairMid)
}

func drawTemplateMask() {
    fillTemplateRect(5, 2, 4, 1)
    fillTemplateRect(10, 1, 3, 1)
    fillTemplateRect(14, 2, 4, 1)
    fillTemplateRect(4, 3, 15, 3)
    fillTemplateRect(3, 6, 17, 2)
    fillTemplateRect(3, 8, 18, 7)
    fillTemplateRect(4, 15, 16, 2)
    fillTemplateRect(6, 17, 12, 2)
    fillTemplateRect(8, 19, 8, 2)

    // Eye cutouts.
    fillTemplateRect(7, 11, 3, 2, false)
    fillTemplateRect(14, 11, 3, 2, false)

    // Beard split.
    fillTemplateRect(11, 18, 2, 2, false)

    // Small side notches around the cheeks.
    fillTemplateRect(4, 14, 1, 1, false)
    fillTemplateRect(19, 14, 1, 1, false)
}

func writePNG(width: Int, height: Int, url: URL, template: Bool) throws {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: bytesPerRow,
        bitsPerPixel: 32
    )!

    guard let data = rep.bitmapData else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing bitmap data"])
    }

    for y in 0..<height {
        for x in 0..<width {
            let sourceX = x * gridSize / width
            let sourceY = y * gridSize / height
            let overlay = overlayPixels[index(sourceX, sourceY)]
            let color: RGBA

            if template {
                color = templateMask[index(sourceX, sourceY)]
                    ? RGBA(r: 255, g: 255, b: 255, a: 255)
                    : RGBA(r: 0, g: 0, b: 0, a: 0)
            } else {
                color = overlay ?? background
            }

            let offset = y * bytesPerRow + x * bytesPerPixel
            data[offset] = color.r
            data[offset + 1] = color.g
            data[offset + 2] = color.b
            data[offset + 3] = color.a
        }
    }

    let pngData = rep.representation(using: .png, properties: [:])!
    try pngData.write(to: url, options: .atomic)
}

drawSprite()
drawTemplateMask()

let fileManager = FileManager.default
let appIconDir = URL(fileURLWithPath: "LilAgents/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let menuIconDir = URL(fileURLWithPath: "LilAgents/Assets.xcassets/MenuBarIcon.imageset", isDirectory: true)

let appIconOutputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (fileName, size) in appIconOutputs {
    try writePNG(width: size, height: size, url: appIconDir.appendingPathComponent(fileName), template: false)
}

let menuIconOutputs: [(String, Int)] = [
    ("bubble-icon.png", 22),
    ("bubble-icon@2x.png", 44),
    ("bubble-icon@3x.png", 66)
]

for (fileName, size) in menuIconOutputs {
    try writePNG(width: size, height: size, url: menuIconDir.appendingPathComponent(fileName), template: true)
}

try writePNG(width: 22, height: 22, url: URL(fileURLWithPath: "LilAgents/menuicon.png"), template: true)
try writePNG(width: 44, height: 44, url: URL(fileURLWithPath: "LilAgents/menuicon-2x.png"), template: true)

print("Generated app icon and menu bar icon assets.")
