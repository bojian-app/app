// Run from the project root: swift scripts/generate_app_icons.swift
// Source: bojian-macos/Bojian/Assets.xcassets/AppIcon.appiconset/BojianAppIcon-512@2x.png
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

for platform in ["ios", "macos"] {
    let directory = "\(platform)/Runner/Assets.xcassets/AppIcon.appiconset"
    let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf:
        root.appendingPathComponent("\(directory)/Contents.json"))) as! [String: Any]
    for entry in catalog["images"] as! [[String: String]] {
        let points = Double(entry["size"]!.components(separatedBy: "x")[0])!
        let scale = Double(entry["scale"]!.dropLast())!
        try write(png(Int(points * scale), opaque: platform == "ios"), "\(directory)/\(entry["filename"]!)")
    }
}

for size in [192, 512] {
    try write(png(size), "web/icons/Icon-\(size).png")
    try write(png(size, opaque: true, scale: 0.8), "web/icons/Icon-maskable-\(size).png")
}
try write(png(1024, opaque: true), "build/previews/app_icon_store_1024.png")
try write(png(32), "web/favicon.png")
try write(png(256), "linux/runner/resources/app_icon.png")

// Windows ICO directory followed by PNG images at each supported size.
let sizes = [16, 24, 32, 48, 64, 128, 256]
let images = sizes.map { png($0) }
var ico = Data()
func appendLE(_ value: Int, bytes: Int) {
    for shift in 0..<bytes { ico.append(UInt8((value >> (shift * 8)) & 255)) }
}
appendLE(0, bytes: 2)
appendLE(1, bytes: 2)
appendLE(sizes.count, bytes: 2)
var offset = 6 + sizes.count * 16
for (size, data) in zip(sizes, images) {
    appendLE(size == 256 ? 0 : size, bytes: 1)
    appendLE(size == 256 ? 0 : size, bytes: 1)
    appendLE(0, bytes: 2)
    appendLE(1, bytes: 2)
    appendLE(32, bytes: 2)
    appendLE(data.count, bytes: 4)
    appendLE(offset, bytes: 4)
    offset += data.count
}
for data in images { ico.append(data) }
try write(ico, "windows/runner/resources/app_icon.ico")
print("Generated application icons from assets/branding/app_icon.png")
