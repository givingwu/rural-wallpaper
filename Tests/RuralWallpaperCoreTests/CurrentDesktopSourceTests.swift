import AppKit
import Foundation
import XCTest
@testable import RuralWallpaperCore

final class CurrentDesktopSourceTests: XCTestCase {
    func testCopiesResolvedDesktopWallpaperIntoWorkspace() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CurrentDesktopSourceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let display = makeDisplay()
        let original = tempDirectory.appendingPathComponent("desktop.png")
        try makeSolidPNG(width: 120, height: 80, color: .blue).write(to: original)

        let source = CurrentDesktopSource(
            workspaceDirectory: tempDirectory.appendingPathComponent("workspace", isDirectory: true),
            resolver: { requestedDisplay in
                XCTAssertEqual(requestedDisplay, display)
                return original
            }
        )

        let image = try await source.makeSourceImage(for: display, settings: .default)

        XCTAssertEqual(image.imageData, try Data(contentsOf: original))
        XCTAssertEqual(image.prompt, "Current desktop wallpaper")
        let copiedURL = try XCTUnwrap(image.attribution.localFileURL)
        XCTAssertNotEqual(copiedURL, original)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedURL.path))
    }

    func testMissingDesktopWallpaperURLThrowsReadableError() async {
        let source = CurrentDesktopSource(
            workspaceDirectory: FileManager.default.temporaryDirectory,
            resolver: { _ in nil }
        )

        do {
            _ = try await source.makeSourceImage(for: makeDisplay(), settings: .default)
            XCTFail("Expected missing wallpaper error")
        } catch {
            XCTAssertEqual(error as? CurrentDesktopSourceError, .missingWallpaperURL)
        }
    }

    func testMissingResolvedDesktopWallpaperFileThrowsReadableError() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CurrentDesktopSourceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let missingURL = tempDirectory.appendingPathComponent("missing.heic")
        let source = CurrentDesktopSource(
            workspaceDirectory: tempDirectory.appendingPathComponent("workspace", isDirectory: true),
            resolver: { _ in missingURL }
        )

        do {
            _ = try await source.makeSourceImage(for: makeDisplay(), settings: .default)
            XCTFail("Expected missing wallpaper file error")
        } catch {
            XCTAssertEqual(error as? CurrentDesktopSourceError, .wallpaperFileMissing(missingURL))
        }
    }

    func testMissingResolvedDesktopWallpaperUsesNewestImageInSameDirectory() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CurrentDesktopSourceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let missingURL = tempDirectory.appendingPathComponent("deleted-wallpaper.heic")
        let olderCandidate = tempDirectory.appendingPathComponent("older.jpg")
        let newestCandidate = tempDirectory.appendingPathComponent("newest.heic")
        try makeSolidPNG(width: 80, height: 60, color: .red).write(to: olderCandidate)
        try makeSolidPNG(width: 80, height: 60, color: .green).write(to: newestCandidate)
        try "ignore".write(
            to: tempDirectory.appendingPathComponent("notes.txt"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: olderCandidate.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 200)],
            ofItemAtPath: newestCandidate.path
        )

        let source = CurrentDesktopSource(
            workspaceDirectory: tempDirectory.appendingPathComponent("workspace", isDirectory: true),
            resolver: { _ in missingURL }
        )

        let image = try await source.makeSourceImage(for: makeDisplay(), settings: .default)

        XCTAssertEqual(image.imageData, try Data(contentsOf: newestCandidate))
        XCTAssertEqual(image.prompt, "Current desktop wallpaper fallback: newest.heic")
        let copiedURL = try XCTUnwrap(image.attribution.localFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedURL.path))
        guard case .localDesktop(let attribution) = image.attribution else {
            return XCTFail("Expected local desktop attribution")
        }
        XCTAssertEqual(
            attribution.originalURL.resolvingSymlinksInPath(),
            newestCandidate.resolvingSymlinksInPath()
        )
    }

    private func makeDisplay() -> DisplayTarget {
        DisplayTarget(
            id: "display-main",
            frame: CoreRect(x: 0, y: 0, width: 120, height: 80),
            pixelSize: PixelSize(width: 120, height: 80),
            scale: 1,
            colorSpace: "sRGB",
            isMain: true,
            friendlyName: "Main Display"
        )
    }

    private func makeSolidPNG(width: Int, height: Int, color: NSColor) throws -> Data {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let bitmap = NSBitmapImageRep(cgImage: image)
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
