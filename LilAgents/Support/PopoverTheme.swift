import AppKit

struct PopoverTheme {
    let name: String
    // Popover
    let popoverBg: NSColor
    let popoverBorder: NSColor
    let popoverBorderWidth: CGFloat
    let popoverCornerRadius: CGFloat
    let titleBarBg: NSColor
    let titleText: NSColor
    let titleFont: NSFont
    let titleString: String
    let separatorColor: NSColor
    // Terminal
    let font: NSFont
    let fontBold: NSFont
    let textPrimary: NSColor
    let textDim: NSColor
    let accentColor: NSColor
    let errorColor: NSColor
    let successColor: NSColor
    let inputBg: NSColor
    let inputCornerRadius: CGFloat
    // Bubble
    let bubbleBg: NSColor
    let bubbleBorder: NSColor
    let bubbleText: NSColor
    let bubbleCompletionBorder: NSColor
    let bubbleCompletionText: NSColor
    let bubbleFont: NSFont
    let bubbleCornerRadius: CGFloat

    // MARK: - Presets

    static let teenageEngineering = PopoverTheme(
        name: "Midnight",
        popoverBg: NSColor(red: 0.050, green: 0.050, blue: 0.058, alpha: 0.97),
        popoverBorder: NSColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 0.62),
        popoverBorderWidth: 1.0,
        popoverCornerRadius: 14,
        titleBarBg: NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0),
        titleText: NSColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1.0),
        titleFont: NSFont(name: "SFMono-Bold", size: 10) ?? .monospacedSystemFont(ofSize: 10, weight: .bold),
        titleString: "LENNY",
        separatorColor: NSColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 0.22),
        font: NSFont(name: "SFMono-Regular", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .regular),
        fontBold: NSFont(name: "SFMono-Medium", size: 11.5) ?? .monospacedSystemFont(ofSize: 11.5, weight: .medium),
        textPrimary: NSColor(red: 0.92, green: 0.92, blue: 0.93, alpha: 1.0),
        textDim: NSColor(white: 0.52, alpha: 1.0),
        accentColor: NSColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1.0),
        errorColor: NSColor(red: 1.0, green: 0.32, blue: 0.22, alpha: 1.0),
        successColor: NSColor(red: 0.38, green: 0.68, blue: 0.38, alpha: 1.0),
        inputBg: NSColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1.0),
        inputCornerRadius: 8,
        bubbleBg: NSColor(red: 0.09, green: 0.09, blue: 0.10, alpha: 0.96),
        bubbleBorder: NSColor(red: 1.0, green: 0.42, blue: 0.0, alpha: 0.52),
        bubbleText: NSColor(white: 0.62, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.28, green: 0.82, blue: 0.28, alpha: 0.62),
        bubbleCompletionText: NSColor(red: 0.28, green: 0.85, blue: 0.28, alpha: 1.0),
        bubbleFont: .monospacedSystemFont(ofSize: 10, weight: .medium),
        bubbleCornerRadius: 10
    )

    static let playful = PopoverTheme(
        name: "Peach",
        popoverBg: NSColor(red: 0.988, green: 0.960, blue: 0.912, alpha: 0.96),
        popoverBorder: NSColor(red: 0.848, green: 0.618, blue: 0.308, alpha: 0.55),
        popoverBorderWidth: 1.0,
        popoverCornerRadius: 32,
        titleBarBg: NSColor(red: 0.972, green: 0.900, blue: 0.772, alpha: 0.84),
        titleText: NSColor(red: 0.365, green: 0.212, blue: 0.075, alpha: 1.0),
        titleFont: NSFont.systemFont(ofSize: 11, weight: .semibold),
        titleString: "LennyTheGenie",
        separatorColor: NSColor(red: 0.838, green: 0.718, blue: 0.528, alpha: 0.30),
        font: NSFont.systemFont(ofSize: 13, weight: .regular),
        fontBold: NSFont.systemFont(ofSize: 13, weight: .semibold),
        textPrimary: NSColor(red: 0.182, green: 0.138, blue: 0.098, alpha: 1.0),
        textDim: NSColor(red: 0.455, green: 0.382, blue: 0.308, alpha: 1.0),
        accentColor: NSColor(red: 0.798, green: 0.462, blue: 0.108, alpha: 1.0),
        errorColor: NSColor(red: 0.778, green: 0.252, blue: 0.182, alpha: 1.0),
        successColor: NSColor(red: 0.238, green: 0.542, blue: 0.398, alpha: 1.0),
        inputBg: NSColor(red: 0.998, green: 0.985, blue: 0.965, alpha: 0.98),
        inputCornerRadius: 12,
        bubbleBg: NSColor(red: 0.994, green: 0.944, blue: 0.868, alpha: 0.96),
        bubbleBorder: NSColor(red: 0.848, green: 0.638, blue: 0.338, alpha: 0.48),
        bubbleText: NSColor(red: 0.438, green: 0.342, blue: 0.268, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.28, green: 0.72, blue: 0.48, alpha: 0.62),
        bubbleCompletionText: NSColor(red: 0.18, green: 0.58, blue: 0.38, alpha: 1.0),
        bubbleFont: NSFont.systemFont(ofSize: 11, weight: .semibold),
        bubbleCornerRadius: 14
    )

    static let wii = PopoverTheme(
        name: "Cloud",
        popoverBg: NSColor(red: 0.955, green: 0.960, blue: 0.970, alpha: 0.97),
        popoverBorder: NSColor(red: 0.718, green: 0.748, blue: 0.800, alpha: 0.48),
        popoverBorderWidth: 0.75,
        popoverCornerRadius: 26,
        titleBarBg: NSColor(red: 0.900, green: 0.914, blue: 0.935, alpha: 1.0),
        titleText: NSColor(red: 0.218, green: 0.218, blue: 0.278, alpha: 1.0),
        titleFont: NSFont(name: "Optima-Bold", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold),
        titleString: "lenny ~",
        separatorColor: NSColor(red: 0.718, green: 0.748, blue: 0.800, alpha: 0.32),
        font: NSFont(name: "Optima", size: 13) ?? .systemFont(ofSize: 13, weight: .regular),
        fontBold: NSFont(name: "Optima-Bold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold),
        textPrimary: NSColor(red: 0.118, green: 0.118, blue: 0.168, alpha: 1.0),
        textDim: NSColor(red: 0.478, green: 0.478, blue: 0.538, alpha: 1.0),
        accentColor: NSColor(red: 0.0, green: 0.438, blue: 0.818, alpha: 1.0),
        errorColor: NSColor(red: 0.848, green: 0.198, blue: 0.148, alpha: 1.0),
        successColor: NSColor(red: 0.178, green: 0.618, blue: 0.278, alpha: 1.0),
        inputBg: NSColor(red: 0.992, green: 0.995, blue: 1.000, alpha: 1.0),
        inputCornerRadius: 10,
        bubbleBg: NSColor(red: 0.940, green: 0.950, blue: 0.975, alpha: 0.95),
        bubbleBorder: NSColor(red: 0.0, green: 0.438, blue: 0.818, alpha: 0.32),
        bubbleText: NSColor(red: 0.418, green: 0.438, blue: 0.518, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.178, green: 0.678, blue: 0.278, alpha: 0.52),
        bubbleCompletionText: NSColor(red: 0.118, green: 0.518, blue: 0.178, alpha: 1.0),
        bubbleFont: NSFont(name: "Optima", size: 10) ?? .systemFont(ofSize: 10, weight: .regular),
        bubbleCornerRadius: 10
    )

    static let iPod = PopoverTheme(
        name: "Moss",
        popoverBg: NSColor(red: 0.798, green: 0.828, blue: 0.755, alpha: 0.98),
        popoverBorder: NSColor(red: 0.518, green: 0.558, blue: 0.472, alpha: 0.88),
        popoverBorderWidth: 2.0,
        popoverCornerRadius: 10,
        titleBarBg: NSColor(red: 0.698, green: 0.732, blue: 0.658, alpha: 1.0),
        titleText: NSColor(red: 0.118, green: 0.138, blue: 0.078, alpha: 1.0),
        titleFont: NSFont(name: "Chicago", size: 11) ?? .systemFont(ofSize: 11, weight: .bold),
        titleString: "Lenny",
        separatorColor: NSColor(red: 0.518, green: 0.558, blue: 0.472, alpha: 0.52),
        font: NSFont(name: "Geneva", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .regular),
        fontBold: NSFont(name: "Geneva", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .bold),
        textPrimary: NSColor(red: 0.078, green: 0.098, blue: 0.058, alpha: 1.0),
        textDim: NSColor(red: 0.318, green: 0.358, blue: 0.268, alpha: 1.0),
        accentColor: NSColor(red: 0.148, green: 0.418, blue: 0.178, alpha: 1.0),
        errorColor: NSColor(red: 0.578, green: 0.118, blue: 0.078, alpha: 1.0),
        successColor: NSColor(red: 0.118, green: 0.378, blue: 0.118, alpha: 1.0),
        inputBg: NSColor(red: 0.858, green: 0.888, blue: 0.818, alpha: 1.0),
        inputCornerRadius: 4,
        bubbleBg: NSColor(red: 0.808, green: 0.838, blue: 0.765, alpha: 0.96),
        bubbleBorder: NSColor(red: 0.518, green: 0.558, blue: 0.472, alpha: 0.62),
        bubbleText: NSColor(red: 0.378, green: 0.398, blue: 0.338, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.178, green: 0.498, blue: 0.178, alpha: 0.62),
        bubbleCompletionText: NSColor(red: 0.118, green: 0.378, blue: 0.118, alpha: 1.0),
        bubbleFont: NSFont(name: "Geneva", size: 10) ?? .monospacedSystemFont(ofSize: 10, weight: .medium),
        bubbleCornerRadius: 6
    )

    // Deep indigo night with warm amber accents
    static let dusk = PopoverTheme(
        name: "Dusk",
        popoverBg: NSColor(red: 0.068, green: 0.068, blue: 0.135, alpha: 0.97),
        popoverBorder: NSColor(red: 0.818, green: 0.608, blue: 0.218, alpha: 0.50),
        popoverBorderWidth: 1.0,
        popoverCornerRadius: 28,
        titleBarBg: NSColor(red: 0.108, green: 0.108, blue: 0.205, alpha: 1.0),
        titleText: NSColor(red: 0.940, green: 0.778, blue: 0.418, alpha: 1.0),
        titleFont: NSFont(name: "Avenir Next Demi Bold", size: 11) ?? .systemFont(ofSize: 11, weight: .semibold),
        titleString: "LennyTheGenie",
        separatorColor: NSColor(red: 0.818, green: 0.608, blue: 0.218, alpha: 0.24),
        font: NSFont(name: "Avenir Next Regular", size: 13) ?? .systemFont(ofSize: 13, weight: .regular),
        fontBold: NSFont(name: "Avenir Next Demi Bold", size: 13) ?? .systemFont(ofSize: 13, weight: .semibold),
        textPrimary: NSColor(red: 0.878, green: 0.878, blue: 0.958, alpha: 1.0),
        textDim: NSColor(red: 0.518, green: 0.518, blue: 0.668, alpha: 1.0),
        accentColor: NSColor(red: 0.940, green: 0.708, blue: 0.278, alpha: 1.0),
        errorColor: NSColor(red: 1.0, green: 0.418, blue: 0.358, alpha: 1.0),
        successColor: NSColor(red: 0.348, green: 0.878, blue: 0.598, alpha: 1.0),
        inputBg: NSColor(red: 0.118, green: 0.118, blue: 0.225, alpha: 1.0),
        inputCornerRadius: 12,
        bubbleBg: NSColor(red: 0.108, green: 0.108, blue: 0.198, alpha: 0.96),
        bubbleBorder: NSColor(red: 0.818, green: 0.608, blue: 0.218, alpha: 0.50),
        bubbleText: NSColor(red: 0.678, green: 0.678, blue: 0.818, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.348, green: 0.878, blue: 0.598, alpha: 0.60),
        bubbleCompletionText: NSColor(red: 0.348, green: 0.878, blue: 0.598, alpha: 1.0),
        bubbleFont: NSFont(name: "Avenir Next Regular", size: 10) ?? .systemFont(ofSize: 10, weight: .regular),
        bubbleCornerRadius: 14
    )

    static let harbor = PopoverTheme(
        name: "Harbor",
        popoverBg: NSColor(red: 0.955, green: 0.965, blue: 0.978, alpha: 0.88),
        popoverBorder: NSColor(red: 0.780, green: 0.820, blue: 0.875, alpha: 0.70),
        popoverBorderWidth: 0.75,
        popoverCornerRadius: 22,
        titleBarBg: NSColor(red: 0.970, green: 0.978, blue: 0.988, alpha: 0.78),
        titleText: NSColor(red: 0.110, green: 0.145, blue: 0.200, alpha: 1.0),
        titleFont: NSFont.systemFont(ofSize: 12, weight: .semibold),
        titleString: "Lenny",
        separatorColor: NSColor(red: 0.760, green: 0.800, blue: 0.860, alpha: 0.46),
        font: NSFont.systemFont(ofSize: 14, weight: .regular),
        fontBold: NSFont.systemFont(ofSize: 14, weight: .semibold),
        textPrimary: NSColor(red: 0.135, green: 0.160, blue: 0.210, alpha: 1.0),
        textDim: NSColor(red: 0.430, green: 0.490, blue: 0.560, alpha: 1.0),
        accentColor: NSColor(red: 0.188, green: 0.420, blue: 0.700, alpha: 1.0),
        errorColor: NSColor(red: 0.720, green: 0.240, blue: 0.220, alpha: 1.0),
        successColor: NSColor(red: 0.168, green: 0.540, blue: 0.420, alpha: 1.0),
        inputBg: NSColor(red: 0.986, green: 0.990, blue: 0.996, alpha: 0.94),
        inputCornerRadius: 14,
        bubbleBg: NSColor(red: 0.972, green: 0.980, blue: 0.992, alpha: 0.90),
        bubbleBorder: NSColor(red: 0.740, green: 0.800, blue: 0.875, alpha: 0.38),
        bubbleText: NSColor(red: 0.350, green: 0.410, blue: 0.490, alpha: 1.0),
        bubbleCompletionBorder: NSColor(red: 0.168, green: 0.540, blue: 0.420, alpha: 0.45),
        bubbleCompletionText: NSColor(red: 0.128, green: 0.430, blue: 0.330, alpha: 1.0),
        bubbleFont: NSFont.systemFont(ofSize: 11, weight: .medium),
        bubbleCornerRadius: 12
    )

    static let allThemes: [PopoverTheme] = [.harbor]
    static var current: PopoverTheme = .harbor
    static var customFontName: String? = ".AppleSystemUIFontRounded"
    static var customFontSize: CGFloat = 13

    // MARK: - Theme Modifiers

    func withCharacterColor(_ color: NSColor) -> PopoverTheme {
        guard name == "Peach" else { return self }
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else { return self }
        let r = rgbColor.redComponent
        let g = rgbColor.greenComponent
        let b = rgbColor.blueComponent
        let light = NSColor(red: min(r + 0.4, 1), green: min(g + 0.4, 1), blue: min(b + 0.4, 1), alpha: 0.25)
        let border = NSColor(red: r, green: g, blue: b, alpha: 0.6)
        return PopoverTheme(
            name: name, popoverBg: popoverBg,
            popoverBorder: border,
            popoverBorderWidth: popoverBorderWidth, popoverCornerRadius: popoverCornerRadius,
            titleBarBg: NSColor(red: min(r * 0.3 + 0.7, 1), green: min(g * 0.3 + 0.7, 1), blue: min(b * 0.3 + 0.7, 1), alpha: 1.0),
            titleText: color, titleFont: titleFont, titleString: titleString,
            separatorColor: light,
            font: font, fontBold: fontBold,
            textPrimary: textPrimary, textDim: textDim,
            accentColor: color,
            errorColor: errorColor, successColor: successColor,
            inputBg: inputBg, inputCornerRadius: inputCornerRadius,
            bubbleBg: NSColor(red: min(r * 0.15 + 0.85, 1), green: min(g * 0.15 + 0.85, 1), blue: min(b * 0.15 + 0.85, 1), alpha: 0.95),
            bubbleBorder: border,
            bubbleText: bubbleText,
            bubbleCompletionBorder: bubbleCompletionBorder, bubbleCompletionText: bubbleCompletionText,
            bubbleFont: bubbleFont, bubbleCornerRadius: bubbleCornerRadius
        )
    }

    func withCustomFont() -> PopoverTheme {
        // Midnight uses its own mono font — don't override
        guard name != "Midnight" else { return self }
        guard let fontName = PopoverTheme.customFontName,
              let baseFont = NSFont(name: fontName, size: PopoverTheme.customFontSize) else { return self }
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let smallFont = NSFont(name: fontName, size: PopoverTheme.customFontSize - 1) ?? baseFont
        return PopoverTheme(
            name: name, popoverBg: popoverBg, popoverBorder: popoverBorder,
            popoverBorderWidth: popoverBorderWidth, popoverCornerRadius: popoverCornerRadius,
            titleBarBg: titleBarBg, titleText: titleText, titleFont: titleFont, titleString: titleString,
            separatorColor: separatorColor,
            font: baseFont, fontBold: boldFont,
            textPrimary: textPrimary, textDim: textDim, accentColor: accentColor,
            errorColor: errorColor, successColor: successColor,
            inputBg: inputBg, inputCornerRadius: inputCornerRadius,
            bubbleBg: bubbleBg, bubbleBorder: bubbleBorder, bubbleText: bubbleText,
            bubbleCompletionBorder: bubbleCompletionBorder, bubbleCompletionText: bubbleCompletionText,
            bubbleFont: smallFont, bubbleCornerRadius: bubbleCornerRadius
        )
    }

    var rgbPopoverBackground: NSColor {
        popoverBg.usingColorSpace(.deviceRGB) ?? popoverBg
    }
}
