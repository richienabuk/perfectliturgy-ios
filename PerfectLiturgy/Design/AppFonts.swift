import CoreText
import Foundation

enum AppFonts {
    static let fileNames = [
        "Cinzel-SemiBold.ttf",
        "CormorantGaramond-Medium.ttf",
        "CormorantGaramond-MediumItalic.ttf",
        "CormorantGaramond-SemiBold.ttf",
        "CormorantGaramond-SemiBoldItalic.ttf",
        "PlusJakartaSans-Regular.ttf",
        "PlusJakartaSans-Medium.ttf",
        "PlusJakartaSans-SemiBold.ttf",
    ]

    static let postScriptNames = fileNames.map { ($0 as NSString).deletingPathExtension }

    static func register(bundle: Bundle = .main) {
        for file in fileNames {
            guard let url = url(for: file, in: bundle) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func url(for file: String, in bundle: Bundle) -> URL? {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext, subdirectory: "Design/Fonts")
            ?? bundle.url(forResource: name, withExtension: ext, subdirectory: "Fonts")
            ?? bundle.url(forResource: name, withExtension: ext)
    }
}
