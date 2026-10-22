import XCTest
@testable import Toolbelt

final class CrashReportParsingTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testTurnsAToolbeltCrashIntoARadarErrorEvent() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let report = try write(header: header(), body: body(sourceFile: "\(home)/projects/toolbelt/Sources/Toolbelt/AppController.swift"))

        let crash = try XCTUnwrap(CrashReporter.parseCrashReport(report))

        XCTAssertEqual(crash.id, "6D5F2A3C-0000-4000-8000-000000000001")
        XCTAssertEqual(crash.kind, .crash)
        XCTAssertEqual(crash.release, "0.2.0+27")
        XCTAssertEqual(crash.event.type, "error")
        XCTAssertEqual(crash.event.level, "fatal")
        XCTAssertEqual(crash.event.handled, false)
        XCTAssertEqual(crash.event.exception?.type, "EXC_BAD_ACCESS (SIGSEGV)")
        XCTAssertEqual(crash.event.exception?.message, "KERN_INVALID_ADDRESS at 0x0000000000000010")
        XCTAssertEqual(crash.event.runtime?.name, "macos")
        XCTAssertEqual(crash.event.runtime?.version, "14.6.1")
        XCTAssertEqual(crash.event.runtime?.host, "MacBookPro18,3")

        let frames = try XCTUnwrap(crash.event.exception?.frames)
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].fn, "AppController.start()")
        XCTAssertEqual(frames[0].file, "~/projects/toolbelt/Sources/Toolbelt/AppController.swift")
        XCTAssertEqual(frames[0].line, 42)
        XCTAssertTrue(frames[0].inApp)
        XCTAssertEqual(frames[1].fn, "AppKit + 4096")
        XCTAssertFalse(frames[1].inApp)
    }

    func testIgnoresReportsOfOtherApps() throws {
        var otherApp = header()
        otherApp["bundleID"] = "com.example.Other"
        let report = try write(header: otherApp, body: body(sourceFile: "/tmp/Other.swift"))
        XCTAssertNil(CrashReporter.parseCrashReport(report))
    }

    func testIgnoresReportsThatAreNotCrashes() throws {
        var diagnostic = header()
        diagnostic["bug_type"] = "211"
        let report = try write(header: diagnostic, body: body(sourceFile: "/tmp/AppController.swift"))
        XCTAssertNil(CrashReporter.parseCrashReport(report))
    }

    func testIgnoresUnreadableFiles() throws {
        let report = directory.appendingPathComponent("Toolbelt-broken.ips")
        try Data("not a crash report".utf8).write(to: report)
        XCTAssertNil(CrashReporter.parseCrashReport(report))
    }

    private func header() -> [String: Any] {
        [
            "app_name": "Toolbelt",
            "bug_type": "309",
            "bundleID": "dev.oconde.toolbelt",
            "app_version": "0.2.0",
            "build_version": "27",
            "timestamp": "2026-10-22 19:45:16.00 -0300",
            "incident_id": "6D5F2A3C-0000-4000-8000-000000000001"
        ]
    }

    private func body(sourceFile: String) -> [String: Any] {
        [
            "exception": ["type": "EXC_BAD_ACCESS", "signal": "SIGSEGV", "subtype": "KERN_INVALID_ADDRESS at 0x0000000000000010"],
            "faultingThread": 0,
            "threads": [
                [
                    "triggered": true,
                    "frames": [
                        ["imageIndex": 0, "imageOffset": 1234, "symbol": "AppController.start()", "sourceFile": sourceFile, "sourceLine": 42],
                        ["imageIndex": 1, "imageOffset": 4096]
                    ]
                ]
            ],
            "usedImages": [["name": "Toolbelt"], ["name": "AppKit"]],
            "osVersion": ["train": "macOS 14.6.1", "build": "23G93"],
            "modelCode": "MacBookPro18,3",
            "pid": 4242
        ]
    }

    private func write(header: [String: Any], body: [String: Any]) throws -> URL {
        var data = try JSONSerialization.data(withJSONObject: header)
        data.append(0x0A)
        data.append(try JSONSerialization.data(withJSONObject: body))
        let url = directory.appendingPathComponent("Toolbelt-2026-10-22-194516.ips")
        try data.write(to: url)
        return url
    }
}
