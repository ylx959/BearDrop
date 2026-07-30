# BearDrop.

ParaBear is a native macOS desktop companion designed to keep your schedule out of your mind and in your workspace. A parachuting teddy bear appears only when it’s time to remind you of an upcoming event, then quietly drifts away with natural, physics-inspired motion. Stay focused on the present—ParaBear takes care of what’s next.

## Function
The menu bar control follows the compact utility pattern:

![menu_bar function](/Users/yanglinxuan/Documents/BearDrop/Sources/ParaBear/Assets/menu_bar.jpg)

- Calendar connection status
- Dropped speed: Slow / Normal / Fast
- Appearence: Bright/Dark mode
- Test ParaBear
- Quit ParaBear

Calendar updates are intentionally simple: ParaBear polls Apple Calendar every 60 seconds, reads only events in the next hour, and keeps an in-memory reminder key set so the same milestone does not fire twice.

The app is designed as a native macOS utility for Sequoia-era systems. Google Calendar support is intentionally routed through Apple Calendar via EventKit, so users can connect Google once in System Settings and ParaBear can read the unified local calendar store.

## Architecture

```text
Sources/ParaBear
├─ App
│  ├─ ParaBearApp.swift
│  ├─ AppDelegate.swift
│  └─ MenuBarController.swift
├─ Domain
│  ├─ BearMood.swift
│  └─ CalendarEvent.swift
├─ Services
│  └─ CalendarService.swift
├─ Overlay
│  └─ BearOverlayWindowController.swift
├─ Features
│  ├─ BearOverlayView.swift
│  ├─ BearCharacterView.swift
│  ├─ ParachuteEventCard.swift
│  ├─ TodayEventsPanel.swift
│  └─ EventTimelineViewModel.swift
├─ Animation
│  └─ FloatingMotion.swift
└─ Settings
   ├─ SettingsStore.swift
   └─ SettingsView.swift
```

Each folder owns one reason to change:

- `Domain`: small pure models shared by the app.
- `Services`: system integrations such as EventKit.
- `Overlay`: AppKit window behavior for the desktop widget.
- `Features`: SwiftUI views and view models for ParaBear's visible product behavior.
- `Animation`: reusable motion math.
- `Settings`: user preferences and the Settings scene.

## Build

```bash
swift build
swift run ParaBear
```

Calendar access requires the app to be run as a bundled macOS app for a polished release, with `NSCalendarsFullAccessUsageDescription` in the bundle Info.plist. The current Swift package is a development scaffold for fast iteration.
