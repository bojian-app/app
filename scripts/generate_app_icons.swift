// Run from the project root: swift scripts/generate_app_icons.swift
// Generates Android and iOS icons from the shared mobile app artwork.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = NSImage(contentsOf: root.appendingPathComponent("assets/branding/app_icon.png"))!
// Keep the original artwork intact; apply the same inset to every app icon.
let artworkScale: CGFloat = 0.855

func png(_ size: Int, opaque: Bool = false, scale: CGFloat = 1) -> Data {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: alpha.rawValue)!
    context.interpolationQuality = .high
    let side = CGFloat(size)
    if opaque {
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    }
    let renderedScale = scale * artworkScale
    let inset = side * (1 - renderedScale) / 2
    let original = source.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    context.draw(original, in: CGRect(x: inset, y: inset, width: side * renderedScale, height: side * renderedScale))
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
    try write(png(size, opaque: true), "android/app/src/main/res/mipmap-\(density)/ic_launcher.png")
}
// Keep the artwork inside the adaptive icon's central safe region.
try write(png(432, scale: 0.7), "android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png")
try write(Data(contentsOf: root.appendingPathComponent("assets/branding/app_icon.png")),
    "android/app/src/main/res/drawable-nodpi/startup_mascot.png")

do {
    let directory = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf:
        root.appendingPathComponent("\(directory)/Contents.json"))) as! [String: Any]
    for entry in catalog["images"] as! [[String: String]] {
        let points = Double(entry["size"]!.components(separatedBy: "x")[0])!
        let scale = Double(entry["scale"]!.dropLast())!
        try write(png(Int(points * scale), opaque: true), "\(directory)/\(entry["filename"]!)")
    }
}

try write(png(1024, opaque: true), "build/previews/app_icon_store_1024.png")
print("Generated application icons from assets/branding/app_icon.png")
