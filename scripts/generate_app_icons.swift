// Run from the project root: swift scripts/generate_app_icons.swift
// Generates Android and iOS icons from the launcher artwork rendered from
// assets/branding/app_icon.svg.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func image(_ path: String) -> CGImage {
    NSImage(contentsOf: root.appendingPathComponent(path))!
        .cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

// Full-bleed square: the platforms apply their own corner masks.
let square = image("assets/branding/launcher_icon.png")
// The lettering alone, for the adaptive icon's foreground layer.
let foreground = image("assets/branding/launcher_foreground.png")

func png(_ source: CGImage, _ size: Int, opaque: Bool, scale: CGFloat = 1) -> Data {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: alpha.rawValue)!
    context.interpolationQuality = .high
    let side = CGFloat(size)
    let inset = side * (1 - scale) / 2
    context.draw(source, in: CGRect(x: inset, y: inset, width: side * scale, height: side * scale))
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    return bitmap.representation(using: .png, properties: [:])!
}

func write(_ data: Data, _ path: String) throws {
    let destination = root.appendingPathComponent(path)
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true)
    try data.write(to: destination)
}

for (density, size) in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)] {
    try write(png(square, size, opaque: true), "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}
// The artwork's 1024 px correspond to the 72 dp an adaptive icon shows of its
// 108 dp layer, so the lettering keeps the proportions of the square icon.
try write(png(foreground, 432, opaque: false, scale: 72.0 / 108.0),
    "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png")

do {
    let directory = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf:
        root.appendingPathComponent("\(directory)/Contents.json"))) as! [String: Any]
    for entry in catalog["images"] as! [[String: String]] {
        let points = Double(entry["size"]!.components(separatedBy: "x")[0])!
        let scale = Double(entry["scale"]!.dropLast())!
        try write(png(square, Int(points * scale), opaque: true), "\(directory)/\(entry["filename"]!)")
    }
}

try write(png(square, 1024, opaque: true), "build/previews/app_icon_store_1024.png")
print("Generated application icons from assets/branding/launcher_icon.png")
