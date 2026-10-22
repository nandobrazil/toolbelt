# Graph Report - /Users/conde/projects/toolbelt  (2026-10-22)

## Corpus Check
- Corpus is ~26,874 words - fits in a single context window. You may not need a graph.

## Summary
- 819 nodes · 2005 edges · 29 communities (22 shown, 7 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 166 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Clipboard History and Management
- Application Switcher Navigation
- Main Application Controller Panels
- MacScan System Diagnostics
- Claude Account Management Module
- Settings User Interface Views
- Menu Bar Extras Inspection
- System Resource Metrics Collection
- Core Application Lifecycle Setup
- Claude Account CLI Tool
- Panel UI Rows and Meters
- Window Layout and Positioning
- Configuration Settings Data Models
- Global Hotkey Registration System
- System Diagnostic Report Window
- Panel Theme Display Options
- Window Layout Position Presets
- Architectural Requirements and Modules
- Screenshot Directory File Watcher
- Menu Bar Icon Configuration
- Clipboard History Archive Storage
- Keyboard Shortcut Recording Controller
- Settings Backward Compatibility
- Swift Package Manifest Configuration
- Toolbelt Module Interface Protocol
- Code Signing Identity Script
- Application Installation Script
- Non-Synthetic Testing Policy
- Hotkey Center Service Reference

## God Nodes (most connected - your core abstractions)
1. `ClaudeAccountsModule` - 40 edges
2. `AppSwitcherModule` - 37 edges
3. `AppController` - 35 edges
4. `ClipboardPicker` - 33 edges
5. `ClipboardModule` - 27 edges
6. `SystemMonitorModule` - 27 edges
7. `WindowLayout` - 26 edges
8. `AppKit` - 25 edges
9. `ClipboardEntry` - 25 edges
10. `ClipboardStore` - 24 edges

## Surprising Connections (you probably didn't know these)
- `Lightness Requirement` --conceptually_related_to--> `Toolbelt`  [INFERRED]
  CLAUDE.md → README.md
- `Memcap Build Constraint` --conceptually_related_to--> `Toolbelt`  [INFERRED]
  CLAUDE.md → README.md
- `Notch Overflow Panel` --rationale_for--> `MenuBarOverflowModule`  [INFERRED]
  docs/progress.md → README.md
- `WindowCatalog AX Traversal` --rationale_for--> `AppSwitcherModule`  [INFERRED]
  docs/progress.md → README.md
- `Non-activating Clipboard Panel` --rationale_for--> `ClipboardModule`  [INFERRED]
  docs/progress.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Toolbelt Core Modules Suite** — readme_menubaroverflow, readme_appswitcher, readme_clipboard, readme_windowlayout, readme_systemmonitor, readme_claudeaccounts [EXTRACTED 1.00]
- **Zero-Polling Event-Driven Architecture** — claude_lightness_requirement, docs_progress_screencapture_xattr, docs_progress_claude_usage_tracking [INFERRED 0.85]
- **macOS Accessibility Subsystem Integration** — readme_menubaroverflow, readme_windowlayout, docs_progress_window_catalog_ax, readme_toolbelt_local_signing [INFERRED 0.85]

## Communities (29 total, 7 thin omitted)

### Community 0 - "Clipboard History and Management"
Cohesion: 0.05
Nodes (40): CryptoKit, NSTableColumn, NSTableView, NSTableViewDataSource, NSTableViewDelegate, ClipboardModule, Data, Int (+32 more)

### Community 1 - "Application Switcher Navigation"
Cohesion: 0.06
Nodes (37): NSView, AppSwitcherModule, Any, Bool, CGFloat, CGWindowID, DispatchWorkItem, Int (+29 more)

### Community 2 - "Main Application Controller Panels"
Cohesion: 0.06
Nodes (37): AnyCancellable, AnyObject, NSPanel, NSSize, AppController, Bool, Double, NSStatusItem (+29 more)

### Community 3 - "MacScan System Diagnostics"
Cohesion: 0.10
Nodes (50): apfs_volume_usage(), application_name(), assess(), code_sign_clones(), collect_activity(), collect_battery(), collect_disk_usage(), collect_hardware() (+42 more)

### Community 4 - "Claude Account Management Module"
Cohesion: 0.08
Nodes (29): DateFormatter, Foundation, NSMenuDelegate, AccountBadge, ClaudeAccountsModule, ClaudeAccountSummary, ClaudeUsageWindow, LatestSession (+21 more)

### Community 5 - "Settings User Interface Views"
Cohesion: 0.08
Nodes (42): Binding, ClosedRange, NSObject, NSWindowDelegate, ObservableObject, AppSettings, AboutPage, AppSwitcherSettingsPage (+34 more)

### Community 6 - "Menu Bar Extras Inspection"
Cohesion: 0.09
Nodes (23): CFTypeRef, NSAttributedString, MenuBarExtra, MenuBarExtras, AXUIElement, Bool, CGFloat, CGRect (+15 more)

### Community 7 - "System Resource Metrics Collection"
Cohesion: 0.10
Nodes (20): ByteFormat, Double, Int, String, SystemMetrics, SystemSnapshot, Alert, disk (+12 more)

### Community 8 - "Core Application Lifecycle Setup"
Cohesion: 0.07
Nodes (22): AppKit, Combine, ScreenCaptureKit, SCWindow, MainMenuBuilder, Void, Bool, CGFloat (+14 more)

### Community 9 - "Claude Account CLI Tool"
Cohesion: 0.19
Nodes (34): account_env(), account_json_path(), account_summary(), accounts(), active_account(), command_add(), command_dir(), command_login() (+26 more)

### Community 10 - "Panel UI Rows and Meters"
Cohesion: 0.14
Nodes (17): NSButton, NSImageView, NSStackView, NSColor, HoverRow, MeterView, PanelSections, SmallIconButton (+9 more)

### Community 11 - "Window Layout and Positioning"
Cohesion: 0.14
Nodes (10): CGPoint, NSScreen, FocusedWindow, AXUIElement, CGFloat, CGRect, CGSize, NSMenuItem (+2 more)

### Community 12 - "Configuration Settings Data Models"
Cohesion: 0.26
Nodes (11): Codable, Decoder, Equatable, AppSwitcherSettings, ClaudeSettings, ClipboardPanelAppearance, ClipboardSettings, MenuBarSettings (+3 more)

### Community 13 - "Global Hotkey Registration System"
Cohesion: 0.20
Nodes (10): Carbon, EventHotKeyRef, HotKeyCenter, KeyCombo, Registration, Bool, NSEvent, String (+2 more)

### Community 14 - "System Diagnostic Report Window"
Cohesion: 0.23
Nodes (15): Decodable, Hashable, FindingsView, MacscanFinding, MacscanReport, MacscanRow, MacscanSection, SectionCard (+7 more)

### Community 15 - "Panel Theme Display Options"
Cohesion: 0.12
Nodes (19): CaseIterable, Identifiable, InlineInfo, claudeAccount, claudeUsage, disk, memory, swap (+11 more)

### Community 16 - "Window Layout Position Presets"
Cohesion: 0.11
Nodes (18): WindowLayout, bottomHalf, bottomLeft, bottomRight, center, centerThird, firstThird, firstTwoThirds (+10 more)

### Community 17 - "Architectural Requirements and Modules"
Cohesion: 0.12
Nodes (17): Lightness Requirement, Memcap Build Constraint, Claude Usage Tracking, Non-activating Clipboard Panel, Notch Overflow Panel, Screenshot Xattr Observation, WindowCatalog AX Traversal, AppSwitcherModule (+9 more)

### Community 18 - "Screenshot Directory File Watcher"
Cohesion: 0.20
Nodes (9): ScreenshotWatcher, Bool, DispatchSourceFileSystemObject, DispatchWorkItem, Set, String, TimeInterval, URL (+1 more)

### Community 19 - "Menu Bar Icon Configuration"
Cohesion: 0.21
Nodes (9): ChevronStyle, belt, chevron, dots, toolbox, LaunchAtLogin, Bool, NSImage (+1 more)

### Community 20 - "Clipboard History Archive Storage"
Cohesion: 0.50
Nodes (3): ClipboardArchive, Data, String

### Community 21 - "Keyboard Shortcut Recording Controller"
Cohesion: 0.43
Nodes (3): ShortcutRecorder, Any, String

## Knowledge Gaps
- **62 isolated node(s):** `PackageDescription`, `belt`, `chevron`, `dots`, `toolbox` (+57 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `KeyCombo` connect `Global Hotkey Registration System` to `Clipboard History and Management`, `Application Switcher Navigation`, `Claude Account Management Module`, `Configuration Settings Data Models`, `System Diagnostic Report Window`, `Window Layout Position Presets`, `Keyboard Shortcut Recording Controller`?**
  _High betweenness centrality (0.202) - this node is a cross-community bridge._
- **Why does `AppKit` connect `Core Application Lifecycle Setup` to `Clipboard History and Management`, `Application Switcher Navigation`, `Main Application Controller Panels`, `Claude Account Management Module`, `Settings User Interface Views`, `Menu Bar Extras Inspection`, `System Resource Metrics Collection`, `Panel UI Rows and Meters`, `Window Layout and Positioning`, `Configuration Settings Data Models`, `Global Hotkey Registration System`, `System Diagnostic Report Window`, `Screenshot Directory File Watcher`, `Clipboard History Archive Storage`?**
  _High betweenness centrality (0.165) - this node is a cross-community bridge._
- **Why does `AppController` connect `Main Application Controller Panels` to `Clipboard History and Management`, `Application Switcher Navigation`, `Claude Account Management Module`, `Settings User Interface Views`, `Menu Bar Extras Inspection`, `System Resource Metrics Collection`, `Core Application Lifecycle Setup`, `Window Layout and Positioning`, `System Diagnostic Report Window`?**
  _High betweenness centrality (0.151) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `AppSwitcherModule` (e.g. with `AppController` and `ThumbnailCache`) actually correct?**
  _`AppSwitcherModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `AppController` (e.g. with `AppSwitcherModule` and `ClaudeAccountsModule`) actually correct?**
  _`AppController` has 9 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `belt`, `chevron` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Clipboard History and Management` be split into smaller, more focused modules?**
  _Cohesion score 0.05183861082737487 - nodes in this community are weakly interconnected._