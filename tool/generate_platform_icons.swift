#!/usr/bin/env swift

import AppKit
import Foundation

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
private let sourceURL = root.appendingPathComponent("logo-remove-background.png")

guard let source = NSImage(contentsOf: sourceURL) else {
  fputs("Unable to load \(sourceURL.path)\n", stderr)
  exit(1)
}

private func pngData(size: Int, markScale: CGFloat) -> Data {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  )!

  bitmap.size = NSSize(width: size, height: size)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  NSGraphicsContext.current?.imageInterpolation = size <= 32 ? .high : .high

  NSColor.clear.setFill()
  NSRect(x: 0, y: 0, width: size, height: size).fill()

  let inset = CGFloat(size) * 0.055
  let tileRect = NSRect(
    x: inset,
    y: inset,
    width: CGFloat(size) - inset * 2,
    height: CGFloat(size) - inset * 2
  )
  let radius = CGFloat(size) * 0.205
  NSColor.white.setFill()
  NSBezierPath(roundedRect: tileRect, xRadius: radius, yRadius: radius).fill()

  // The source already has generous transparent padding. Drawing the complete
  // square at this scale preserves its exact proportions and alpha edges.
  let markSide = CGFloat(size) * markScale
  let markRect = NSRect(
    x: (CGFloat(size) - markSide) / 2,
    y: (CGFloat(size) - markSide) / 2,
    width: markSide,
    height: markSide
  )
  source.draw(
    in: markRect,
    from: NSRect(origin: .zero, size: source.size),
    operation: .sourceOver,
    fraction: 1
  )

  NSGraphicsContext.restoreGraphicsState()
  return bitmap.representation(using: .png, properties: [:])!
}

private func write(_ data: Data, to relativePath: String) {
  let url = root.appendingPathComponent(relativePath)
  try! fileManager.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try! data.write(to: url, options: .atomic)
}

private func icoData(images: [(size: Int, data: Data)]) -> Data {
  var result = Data()
  func appendUInt16(_ value: UInt16) {
    var littleEndian = value.littleEndian
    result.append(Data(bytes: &littleEndian, count: 2))
  }
  func appendUInt32(_ value: UInt32) {
    var littleEndian = value.littleEndian
    result.append(Data(bytes: &littleEndian, count: 4))
  }

  appendUInt16(0)
  appendUInt16(1)
  appendUInt16(UInt16(images.count))

  var offset = 6 + images.count * 16
  for image in images {
    result.append(UInt8(image.size == 256 ? 0 : image.size))
    result.append(UInt8(image.size == 256 ? 0 : image.size))
    result.append(0)
    result.append(0)
    appendUInt16(1)
    appendUInt16(32)
    appendUInt32(UInt32(image.data.count))
    appendUInt32(UInt32(offset))
    offset += image.data.count
  }
  for image in images {
    result.append(image.data)
  }
  return result
}

let app1024 = pngData(size: 1024, markScale: 0.82)
write(app1024, to: "assets/icon/app_icon_1024.png")
write(pngData(size: 512, markScale: 0.82), to: "assets/icon/app_icon_512.png")
write(pngData(size: 256, markScale: 0.82), to: "assets/icon/app_icon_256.png")

for size in [16, 32, 64, 128, 256, 512, 1024] {
  write(
    pngData(size: size, markScale: 0.82),
    to: "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_\(size).png"
  )
}

let windowsSizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
let appIcoImages = windowsSizes.map { (size: $0, data: pngData(size: $0, markScale: 0.82)) }
let trayIcoImages = windowsSizes.map {
  (size: $0, data: pngData(size: $0, markScale: $0 <= 32 ? 0.94 : 0.88))
}
write(icoData(images: appIcoImages), to: "windows/runner/resources/app_icon.ico")
write(icoData(images: trayIcoImages), to: "assets/tray/app_icon.ico")

print("Generated macOS, Windows, Linux, and Windows tray icons.")
