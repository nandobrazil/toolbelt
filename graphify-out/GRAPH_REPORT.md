# Graph Report - /Users/conde/projects/toolbelt  (2026-10-22)

## Corpus Check
- Corpus is ~41,663 words - fits in a single context window. You may not need a graph.

## Summary
- 921 nodes · 2242 edges · 37 communities (28 shown, 9 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 172 edges (avg confidence: 0.76)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Clipboard History and Storage
- Macscan System Diagnostic Tool
- App Controller Panel Management
- Claude Accounts Menu Management
- Global Hotkey Event Center
- Settings User Interface Views
- Application Auto Update System
- Custom UI Components and Icons
- Menu Bar Extras Management
- System Resource Metrics Monitoring
- Claude Accounts CLI Utility
- App Switcher Navigation Module
- Window Layout and Positioning
- App Switcher Selection Controller
- Switchable Window Application Catalog
- Window Thumbnail Screen Capture
- Architecture and System Documentation
- System Diagnostics Report Window
- Panel Themes and Display Enums
- Status Icon and Login Configuration
- Window Snapping Layout Presets
- Screenshot Directory File Watcher
- Application Settings Configuration Models
- File System Event Watcher
- Data Decoding Initializers
- Landing Page Frontend Scripts
- Keyboard Shortcut Key Combos
- Deployment and CI Workflows
- Application Release Notarization Script
- Content Item Kind Types
- Server Deployment Shell Script
- Swift Package Manager Definition
- Application Bundle Assembly Script
- Code Signing Identity Generator
- Local Application Installation Script
- GitHub Release Publishing Script
- Initial Version Release Notes

## God Nodes (most connected - your core abstractions)
1. `ClaudeAccountsModule` - 41 edges
2. `AppSwitcherModule` - 37 edges
3. `AppUpdater` - 37 edges
4. `AppController` - 36 edges
5. `ClipboardPicker` - 33 edges
6. `AppKit` - 28 edges
7. `ClipboardModule` - 27 edges
8. `SystemMonitorModule` - 27 edges
9. `KeyCombo` - 26 edges
10. `WindowLayout` - 26 edges

## Surprising Connections (you probably didn't know these)
- `Toolbelt Public Landing Page` --semantically_similar_to--> `Toolbelt Overview & Features`  [INFERRED] [semantically similar]
  site/index.html → README.md
- `Deploy na VPS` --references--> `Toolbelt Landing Kubernetes Deployment`  [INFERRED]
  .github/workflows/deploy-site.yml → infra/toolbelt.yaml
- `Toolbelt 0.2.0 Release Notes` --references--> `Auto-Update Verification & Replacement Flow`  [INFERRED]
  CHANGELOG.md → docs/releasing.md
- `Toolbelt Overview & Features` --references--> `Toolbelt 0.2.0 Release Notes`  [EXTRACTED]
  README.md → CHANGELOG.md
- `Toolbelt Overview & Features` --references--> `Clipboard Module (clipboard)`  [EXTRACTED]
  README.md → docs/architecture.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Toolbelt Core Utilities & Modules** — docs_architecture_menubar_overflow, docs_architecture_app_switcher, docs_architecture_clipboard, docs_architecture_window_layout, docs_architecture_system_monitor, docs_architecture_claude_accounts [EXTRACTED 1.00]
- **Toolbelt Auto-Update and Distribution Architecture** — docs_architecture_app_updater, docs_releasing_auto_update_flow, docs_releasing_process [EXTRACTED 1.00]

## Communities (37 total, 9 thin omitted)

### Community 0 - "Clipboard History and Storage"
Cohesion: 0.05
Nodes (41): CryptoKit, DateFormatter, NSTableColumn, NSTableView, NSTableViewDataSource, NSTableViewDelegate, ClipboardArchive, Data (+33 more)

### Community 1 - "Macscan System Diagnostic Tool"
Cohesion: 0.10
Nodes (50): apfs_volume_usage(), application_name(), assess(), code_sign_clones(), collect_activity(), collect_battery(), collect_disk_usage(), collect_hardware() (+42 more)

### Community 2 - "App Controller Panel Management"
Cohesion: 0.07
Nodes (31): AnyCancellable, AnyObject, NSAttributedString, NSPanel, NSSize, AppController, Bool, Double (+23 more)

### Community 3 - "Claude Accounts Menu Management"
Cohesion: 0.08
Nodes (28): AccountBadge, ClaudeAccountsModule, ClaudeAccountSummary, ClaudeUsageWindow, LatestSession, StatusReport, Bool, CGFloat (+20 more)

### Community 4 - "Global Hotkey Event Center"
Cohesion: 0.06
Nodes (25): AppKit, Carbon, Combine, DispatchSourceSignal, EventHotKeyRef, HotKeyCenter, Registration, NSEvent (+17 more)

### Community 5 - "Settings User Interface Views"
Cohesion: 0.07
Nodes (42): Binding, ClosedRange, NSObject, NSWindowDelegate, ObservableObject, AppSettings, AboutPage, AppSwitcherSettingsPage (+34 more)

### Community 6 - "Application Auto Update System"
Cohesion: 0.09
Nodes (29): Error, Result, Security, AppUpdater, Bool, Date, Int, NSObjectProtocol (+21 more)

### Community 7 - "Custom UI Components and Icons"
Cohesion: 0.11
Nodes (25): NSButton, NSGradient, NSImageView, NSStackView, color(), drawIcon(), gradient(), CGFloat (+17 more)

### Community 8 - "Menu Bar Extras Management"
Cohesion: 0.09
Nodes (22): CFTypeRef, MenuBarExtra, MenuBarExtras, AXUIElement, Bool, CGFloat, CGRect, Float (+14 more)

### Community 9 - "System Resource Metrics Monitoring"
Cohesion: 0.10
Nodes (21): NSMenuDelegate, ByteFormat, Double, Int, String, SystemMetrics, SystemSnapshot, Alert (+13 more)

### Community 10 - "Claude Accounts CLI Utility"
Cohesion: 0.19
Nodes (34): account_env(), account_json_path(), account_summary(), accounts(), active_account(), command_add(), command_dir(), command_login() (+26 more)

### Community 11 - "App Switcher Navigation Module"
Cohesion: 0.14
Nodes (17): NSView, Bool, CGFloat, CGWindowID, Int, Never, NSCoder, NSEvent (+9 more)

### Community 12 - "Window Layout and Positioning"
Cohesion: 0.14
Nodes (10): CGPoint, NSScreen, FocusedWindow, AXUIElement, CGFloat, CGRect, CGSize, NSMenuItem (+2 more)

### Community 13 - "App Switcher Selection Controller"
Cohesion: 0.18
Nodes (6): AppSwitcherModule, Any, DispatchWorkItem, NSObjectProtocol, pid_t, UInt32

### Community 14 - "Switchable Window Application Catalog"
Cohesion: 0.15
Nodes (13): AXUIElement, Bool, CGFloat, CGRect, CGWindowID, Float, Int, NSImage (+5 more)

### Community 15 - "Window Thumbnail Screen Capture"
Cohesion: 0.13
Nodes (14): ScreenCaptureKit, SCWindow, Notification, ScreenRecordingPermission, Bool, CGFloat, CGSize, CGWindowID (+6 more)

### Community 16 - "Architecture and System Documentation"
Cohesion: 0.14
Nodes (20): Toolbelt 0.2.0 Release Notes, Toolbelt Agent Guidelines & Rules, Event-driven Lightweight Footprint Requirement, AppController Coordinator, App Switcher Module (appSwitcher), AppUpdater Component, cca CLI Tool, Claude Accounts Module (claudeAccounts) (+12 more)

### Community 17 - "System Diagnostics Report Window"
Cohesion: 0.23
Nodes (15): Decodable, Hashable, FindingsView, MacscanFinding, MacscanReport, MacscanRow, MacscanSection, SectionCard (+7 more)

### Community 18 - "Panel Themes and Display Enums"
Cohesion: 0.12
Nodes (19): CaseIterable, Identifiable, InlineInfo, claudeAccount, claudeUsage, disk, memory, swap (+11 more)

### Community 19 - "Status Icon and Login Configuration"
Cohesion: 0.15
Nodes (10): ChevronStyle, belt, chevron, dots, toolbox, LaunchAtLogin, Bool, NSImage (+2 more)

### Community 20 - "Window Snapping Layout Presets"
Cohesion: 0.11
Nodes (18): WindowLayout, bottomHalf, bottomLeft, bottomRight, center, centerThird, firstThird, firstTwoThirds (+10 more)

### Community 21 - "Screenshot Directory File Watcher"
Cohesion: 0.20
Nodes (9): ScreenshotWatcher, Bool, DispatchSourceFileSystemObject, DispatchWorkItem, Set, String, TimeInterval, URL (+1 more)

### Community 22 - "Application Settings Configuration Models"
Cohesion: 0.50
Nodes (11): Codable, Equatable, ServiceManagement, AppSwitcherSettings, ClaudeSettings, ClipboardPanelAppearance, ClipboardSettings, MenuBarSettings (+3 more)

### Community 23 - "File System Event Watcher"
Cohesion: 0.26
Nodes (7): Foundation, FileWatcher, DispatchSourceFileSystemObject, DispatchWorkItem, String, TimeInterval, Void

### Community 25 - "Landing Page Frontend Scripts"
Cohesion: 0.25
Nodes (7): belt, clock, formatClock(), months, panel, startClock(), weekdays

### Community 26 - "Keyboard Shortcut Key Combos"
Cohesion: 0.43
Nodes (4): WindowSettings, KeyCombo, Bool, String

### Community 27 - "Deployment and CI Workflows"
Cohesion: 0.40
Nodes (6): Deploy na VPS, Varredura de segredos (Gitleaks), Deploy da landing workflow, Toolbelt Landing Kubernetes Deployment, Toolbelt Landing Kubernetes Ingress, Toolbelt Landing Kubernetes Service

### Community 29 - "Content Item Kind Types"
Cohesion: 0.67
Nodes (3): Kind, image, text

## Knowledge Gaps
- **77 isolated node(s):** `PackageDescription`, `ServiceManagement`, `belt`, `chevron`, `dots` (+72 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `KeyCombo` connect `Keyboard Shortcut Key Combos` to `Clipboard History and Storage`, `Claude Accounts Menu Management`, `Global Hotkey Event Center`, `App Switcher Navigation Module`, `System Diagnostics Report Window`, `Window Snapping Layout Presets`, `Application Settings Configuration Models`?**
  _High betweenness centrality (0.190) - this node is a cross-community bridge._
- **Why does `AppKit` connect `Global Hotkey Event Center` to `Clipboard History and Storage`, `App Controller Panel Management`, `Claude Accounts Menu Management`, `Settings User Interface Views`, `Application Auto Update System`, `Custom UI Components and Icons`, `Menu Bar Extras Management`, `System Resource Metrics Monitoring`, `App Switcher Navigation Module`, `Window Layout and Positioning`, `Switchable Window Application Catalog`, `Window Thumbnail Screen Capture`, `System Diagnostics Report Window`, `Screenshot Directory File Watcher`, `Application Settings Configuration Models`?**
  _High betweenness centrality (0.158) - this node is a cross-community bridge._
- **Why does `AppController` connect `App Controller Panel Management` to `Clipboard History and Storage`, `Claude Accounts Menu Management`, `Global Hotkey Event Center`, `Settings User Interface Views`, `Application Auto Update System`, `Menu Bar Extras Management`, `System Resource Metrics Monitoring`, `Window Layout and Positioning`, `App Switcher Selection Controller`, `System Diagnostics Report Window`?**
  _High betweenness centrality (0.157) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `AppSwitcherModule` (e.g. with `AppController` and `ThumbnailCache`) actually correct?**
  _`AppSwitcherModule` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `AppController` (e.g. with `AppSwitcherModule` and `AppUpdater`) actually correct?**
  _`AppController` has 10 INFERRED edges - model-reasoned connections that need verification._
- **What connects `PackageDescription`, `ServiceManagement`, `belt` to the rest of the system?**
  _77 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Clipboard History and Storage` be split into smaller, more focused modules?**
  _Cohesion score 0.050102951269732326 - nodes in this community are weakly interconnected._