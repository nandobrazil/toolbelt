import ApplicationServices
import Carbon
import XCTest
@testable import Toolbelt

final class SupportingLogicTests: XCTestCase {
    func testSanitizeMasksHomePathEmailsAndSecrets() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let line = "\(home)/Library/x.json failed for someone@example.com with rk_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcd and eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"

        let sanitized = Diagnostics.sanitize(line)

        XCTAssertEqual(sanitized, "~/Library/x.json failed for <e-mail> with <chave> and <token>")
    }

    func testMenuBarIdentifiersNumberRepeatedItemsOfTheSameApp() {
        let element = AXUIElementCreateApplication(1)
        let extras = [
            extra(pid: 10, title: "Wi-Fi", system: "com.apple.menuextra.wifi", element: element),
            extra(pid: 20, title: "Dropbox", system: nil, element: element),
            extra(pid: 20, title: "Dropbox", system: nil, element: element)
        ]

        XCTAssertEqual(MenuBarExtras.identifiers(for: extras), ["10|com.apple.menuextra.wifi|0", "20|Dropbox|0", "20|Dropbox|1"])
    }

    func testClockAndControlCenterAreFixed() {
        let element = AXUIElementCreateApplication(1)
        XCTAssertFalse(extra(pid: 1, title: "Clock", system: "com.apple.menuextra.clock", element: element).isMovable)
        XCTAssertFalse(extra(pid: 1, title: "Control Center", system: "com.apple.menuextra.controlcenter", element: element).isMovable)
        XCTAssertTrue(extra(pid: 1, title: "Wi-Fi", system: "com.apple.menuextra.wifi", element: element).isMovable)
    }

    func testShortcutDisplayUsesMacSymbols() {
        XCTAssertEqual(KeyCombo(keyCode: 48, modifiers: KeyCombo.command).display, "⌘⇥")
        XCTAssertEqual(KeyCombo(keyCode: 48, modifiers: KeyCombo.option | KeyCombo.shift).display, "⌥⇧⇥")
        XCTAssertTrue(KeyCombo(keyCode: 9, modifiers: KeyCombo.option | KeyCombo.command).hasRequiredModifier)
        XCTAssertFalse(KeyCombo(keyCode: 9, modifiers: KeyCombo.shift).hasRequiredModifier)
    }

    func testRadarBatchFollowsProtocolVersionOne() throws {
        let event = RadarEvent.log("feedback.bug", level: "warn", attrs: ["text": .string("oi")], at: Date(timeIntervalSince1970: 1_791_504_000))
        let data = try XCTUnwrap(RadarClient.encodedBatch([event], release: "0.2.0+27"))
        let batch = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(batch["v"] as? Int, 1)
        XCTAssertEqual(batch["release"] as? String, "0.2.0+27")
        XCTAssertEqual((batch["sdk"] as? [String: String])?["name"], "toolbelt-radar")
        let events = try XCTUnwrap(batch["events"] as? [[String: Any]])
        XCTAssertEqual(events.first?["type"] as? String, "log")
        XCTAssertEqual(events.first?["message"] as? String, "feedback.bug")
        XCTAssertEqual(events.first?["ts"] as? Int, 1_791_504_000_000)
        XCTAssertNil(events.first?["exception"])
    }

    private func extra(pid: pid_t, title: String, system: String?, element: AXUIElement) -> MenuBarExtra {
        MenuBarExtra(
            element: element,
            processIdentifier: pid,
            applicationName: title,
            systemIdentifier: system,
            icon: nil,
            title: title,
            label: title,
            frame: .zero
        )
    }
}
