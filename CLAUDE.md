# Project Architecture

This project strictly follows **Clean Architecture** with MVVM (ViewModels & Managers in `Presentation/`, SwiftUI views in `UI/`), organized as **feature-first vertical slices**. Swift 6 concurrency with `@MainActor`.

## Directory Structure

```
CheatKey/
├── CheatKeyApp.swift              # @main entry point
├── ContentView.swift              # AX permission onboarding window
├── Features/
│   ├── Settings/
│   │   └── Presentation/
│   │       ├── UI/
│   │       │   └── SettingsView.swift         # Login item, hold duration, update check
│   │       └── Managers/
│   │           └── SettingsWindowManager.swift # Settings NSWindow lifecycle (decoupled from overlay)
│   └── ShortcutOverlay/
│       ├── Domain/
│       │   ├── Entities/
│       │   │   └── Shortcut.swift           # ModifierKey, ShortcutItem, ShortcutGroup
│       │   ├── Interfaces/
│       │   │   ├── KeyMonitorRepository.swift      # Keyboard event monitoring protocol
│       │   │   ├── AppTrackerRepository.swift      # Frontmost app tracking protocol
│       │   │   └── OverlayPanelRepository.swift    # Floating panel lifecycle protocol
│       │   └── UseCases/
│       │       ├── OverlayUseCase.swift             # Business logic protocol
│       │       └── OverlayUseCaseImpl.swift         # Hold timer, show/hide, refresh
│       ├── Data/
│       │   └── Repositories/
│       │       ├── KeyMonitorRepositoryImpl.swift   # NSEvent global/local monitors
│       │       ├── AppTrackerRepositoryImpl.swift   # NSWorkspace frontmost app tracking
│       │       ├── OverlayPanelRepositoryImpl.swift # NSPanel lifecycle management
│       │       ├── MenuBarManager.swift             # NSStatusItem menu bar icon
│       │       ├── MenuBarShortcutReader.swift      # AX API / NSMenu shortcut reading
│       │       ├── ShortcutExecutor.swift           # CGEvent keyboard synthesis
│       │       └── AccessibilityService.swift       # AX permission check & request
│       └── Presentation/
│           ├── UI/
│           │   ├── Components/
│           │   │   └── ShortcutTileView.swift
│           │   └── OverlayView.swift         # Main floating card
│           └── OverlayViewModel.swift    # Bridge between UseCase and Views
├── Infrastructure/
│   └── DependencyInjection/
│       └── FeatureAssembly.swift         # Composition root — wires all dependencies
```

## Dependency Rules

```
View (SwiftUI) → ViewModel → UseCase (protocol)
                                  ↑
                          UseCaseImpl
                                  ↓
                  Domain Interfaces ← Data/Repositories (implementations)
```

- **Domain** depends on nothing (pure Swift). CGEvent/Carbon types are NOT allowed here.
- **UseCases** depend only on Domain protocols.
- **Presentation** depends only on UseCase protocol (not implementations).
- **Data/Repositories** implement Domain interfaces.
- **FeatureAssembly** is the ONLY place that instantiates concrete types.

## Naming Conventions

| Layer | Protocol | Implementation |
|---|---|---|
| UseCase | `OverlayUseCase` | `OverlayUseCaseImpl` |
| Repository | `KeyMonitorRepository` | `KeyMonitorRepositoryImpl` |

## Key Design Decisions

1. **Static enums stay as-is** — `MenuBarShortcutReader`, `ShortcutExecutor`, `AccessibilityService` are pure functions with no state. Wrapping them in protocols would be over-engineering.

2. **`ShortcutExecutor.cgEventFlags` uses switch, not reduce** — `CGEventFlags(rawValue:)` construction behaves differently from `.insert()`. The explicit switch is required for correct modifier flag behavior.

3. **`pid_t` flows through the entire chain** — `ActiveApp.current().pid` → UseCase → PanelRepository → ViewModel → TileView → ShortcutExecutor. Never query `frontmostApplication` at execution time (it returns CheatKey because the floating panel receives the click).

4. **`@MainActor` on implementations, not protocols** — Protocols stay actor-agnostic. Implementations are `@MainActor` since they interact with AppKit.

5. **No `import UIKit`** — macOS-only project. Use `Cocoa` (AppKit), `SwiftUI`, `Combine`, `Carbon` (for CGEvent).

## How the App Works

1. **Startup**: `FeatureAssembly.makeOverlayViewModel()` wires all dependencies.
2. **Menu bar**: `MenuBarManager` puts a ⌘ icon in the system menu bar (toggle, show shortcuts, settings, quit).
3. **Trigger**:
   - **Hold ⌘**: User holds ⌘ for N seconds (configurable: 0.7s / 1s / 2s) → overlay shows the frontmost app's shortcuts.
   - **Menu bar**: User clicks "Show Shortcuts…" → overlay shows with a close button in the top‑right. Switching apps dismisses it.
4. **Detection**: `KeyMonitorRepositoryImpl` uses both global and local NSEvent monitors.
5. **Reading**: `MenuBarShortcutReader` reads the frontmost app's menu bar via Accessibility API.
6. **Display**: `OverlayPanelRepositoryImpl` creates a non-activating NSPanel with SwiftUI content.
7. **Execution**: Tapping a tile calls `ShortcutExecutor.execute(item, targetPID:)` which posts CGEvent keyDown/keyUp to the target app.
8. **Hide**: Releasing ⌘ hides the panel. Switching apps while holding ⌘ refreshes shortcuts. Menu‑triggered overlay hides on app switch.

## Settings

The settings window is managed by `SettingsWindowManager`, a standalone class completely decoupled from the shortcut overlay. It is created inside `MenuBarManager` directly — no use‑case or repository layer needed. `OverlayViewModel` has no knowledge of settings.
