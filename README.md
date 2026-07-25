# ParaBear

ParaBear is a small macOS desktop companion: a calm bear floating under a parachute that shows the next upcoming Calendar event.

Instead of staying on-screen all day, ParaBear appears for scheduled reminder flights: 10 minutes before a meeting, 5 minutes before, 3 minutes before, and right when the event starts. Each flight enters from the top of the screen, sways left and right while descending, then disappears at the bottom.

During a flight, the user can drag the bear/parachute panel to any position. After release, ParaBear continues the same descent from the release point. The side-to-side wind motion uses a lightweight driven, damped oscillator model: each frame applies wind force, spring-back force, and damping to create a more physical sway than a fixed sine wave.

The menu bar control follows the compact utility pattern:

- Calendar connection status
- Planned speed: Slow / Normal / Fast
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
