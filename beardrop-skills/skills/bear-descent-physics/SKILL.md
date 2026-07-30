---
name: bear-descent-physics
description: Use when tuning ParaBear's floating/landing motion — the window drift, broad sway, wind sway, or drag-release physics in BearOverlayWindowController or BearDragState
---

# Bear Descent Physics

## Overview

ParaBear's floating bear panel descends via layered spring-damper motions in `Sources/ParaBear/Overlay/BearOverlayWindowController.swift`. Three independent motions compose into the window's on-screen path each frame, driven by a 30fps `Timer` loop (`advanceDrift`).

## Layers

1. **Vertical descent** — constant speed from `pointsPerSecondForCurrentFlight()`, derived from `PlannedFlightSpeed.flightDuration` and screen height.
2. **Broad sway** (`inertialSwayOffset` / `inertialSwayVelocity`, `integrateBroadSway`) — slow spring-damper chasing a randomized sine target (`broadSwayTargetOffset`); this is the overall left/right drift path. Range set by `broadSwayRatio`, clamped via `smoothClamp` at `broadSwayAmplitude * broadSwayOvershootRatio`.
3. **Wind sway** (`swayOffset` / `swayVelocity`, `integrateWindSway`) — faster spring-damper for gustiness, bounded by `windSwayRatio`. Includes an **inertia-lean** term (`-inertialSwayVelocity * inertiaLeanRatio`) so the bear tilts opposite to fast broad-sway movement, and keeps ringing briefly after broad sway settles (an "inertial wobble") — governed by how underdamped `windSwaySpring` / `windSwayDamping` are.

`advanceDrift` must integrate broad sway *before* wind sway each frame so the inertia-lean term reacts to the current frame's velocity, not the previous one.

Final x-origin each frame: `baseX + inertialSwayOffset + swayOffset`, clamped to `centerTravelBounds`.

## The ordering trap in `configureBroadSway`

`baseX` is fixed for an entire flight. **All** visible left/right travel comes from the sway
amplitude — none of it from where the flight starts.

So `configureBroadSway` must size the sway FIRST, then place `baseX` in the room that remains.
The reverse (place `baseX` across the corridor, then shrink the sway to fit) looks like it
spreads flights out, but it starves the sway toward zero whenever `baseX` lands off-center:
`sideRoom = distanceToNearestBound - windBudget` hits 0 exactly at the edge of the position
range. Measured effect of that inversion: per-flight travel dropped from a consistent 892px to
a median of 540px, bottoming out at 216px.

A narrow `baseX` range is not a bug. When the sway is large it *should* collapse toward center,
because the sway then covers the whole corridor on its own.

## Never soft-clamp an integrated value every frame

`smoothClamp` is `limit * tanh(v/limit)`, and `tanh(x) < x` everywhere — it compresses at *all*
magnitudes, not just near the limit. Applying it to an accumulating offset inside the 30fps loop
compounds ~540 times per flight into a strong pull toward center, worst exactly at the extremes
where compression bites hardest. That single line cost ~65% of the swing and produced a dwell at
each turning point.

Use a hard `min/max` as a backstop inside integrators. Reserve `smoothClamp` for one-shot shaping
of a value that is *not* fed back into itself.

**Symptom to watch for:** travel far below the corridor width with no wall hits, plus stalling at
the turning points.

## Diagnosing motion complaints

Reason about this system numerically — the layers interact and eyeballing constants misleads.
Port the integrators to a throwaway script, sweep the constants, and measure per-flight span,
the fraction of frames under ~8px/s (stalling), and corridor wall hits. Tuning by intuition
repeatedly moved the wrong knob here; a 20-line simulation found the real cause in one pass.

Reference points on a 1440px screen with the 500pt window: corridor 1148px, per-flight travel
~627px median, under ~3% of frames near-motionless, zero wall hits.

## The bear's swing is a separate system from the window's drift

Two independent things move, in two different frameworks:

1. **The window** drifts via `NSPanel` origin, integrated in `BearOverlayWindowController`.
2. **The bear** rotates in SwiftUI, from `WindSwayMotion`'s own internal wind model.

`WindSwayMotion` knows nothing about the real window motion, so a request like "the bear should
lean when it drifts fast" cannot be satisfied by tuning it — the two must be coupled.
`BearDriftState` is that bridge: the controller integrates `PayloadSwingPhysics` from the true
drift acceleration and writes the angle; `BearOverlayView` adds it to the bear's `rotationEffect`.

Feed the pendulum acceleration **summed from the integrators**, never from differencing the
window position — that position is clamped and quantised, and differentiates into noise.

One driving term gives both behaviours, because a pendulum leans against acceleration:
speeding up makes it trail behind, and slowing down lets momentum carry it onward. Verified at
100% / 97% of qualifying frames. Don't special-case the two directions.

**Rotation sign:** positive degrees is clockwise, and the bear is anchored at `.top`, so
**positive degrees swings its body to the left.** Easy to invert when reasoning about lean.

## A saturated layer silently decouples everything downstream

`inertiaLeanRatio` pushes the wind sway against the drift, but its steady-state demand is
`driftSpeed * inertiaLeanRatio / windSwaySpring`. At 0.55 that came to ~190px against a ±108px
clamp, so the wind sway sat pinned at its limit ~29% of the flight.

A pinned layer stops responding while its *computed* acceleration keeps changing — which dropped
the correlation between the acceleration driving the bear's swing and the window's real motion to
**0.556**. The swing fired at moments that did not match the visible drift, which reads as the
effect being unreliable or one-sided rather than as a clamp problem. Dropping the ratio to 0.25
restored correlation to 0.996.

When a motion effect looks intermittent, check whether an upstream layer is saturating before
touching the effect itself.

## Tuning knobs

All `static let` on `BearOverlayWindowController`:

| Constant | Effect |
|---|---|
| `maxTravelFromCenterRatio` | **Master cap.** Sets the travel corridor via `centerTravelBounds`; every other horizontal term is clamped to it. If flights look stuck near screen center, raise this first — tuning the sway ratios alone cannot push past it. |
| `broadSwayRatio` | How wide the overall drift path is |
| `windSwayRatio` | Max wind-gust / inertia-lean offset |
| `broadSwayOvershootRatio` | How far broad sway can overshoot its target before clamping |
| `inertiaLeanRatio` | How strongly fast broad-sway velocity kicks the bear the opposite way |
| `windSwaySpring` / `windSwayDamping` | Lower damping = longer, more visible ring-down once movement stops |

`maxBroadSwayAmplitude` reserves room for wind sway so the combined excursion never exceeds half the travel corridor. Widening ratios can shift which term becomes the binding constraint — `Tests/ParaBearTests/BearOverlayWindowControllerTests.swift` (`broadSwayReservesRoomForWindBeforeReachingTravelBounds`, `windSwayIsOnlyASmallPartOfScreenWidth`) assert this invariant and reference the constants directly, so they stay correct across retuning.

## Related

Mid-flight drag/release is a separate system: pendulum-style rotation in `BearDragPhysics` (`Sources/ParaBear/Features/BearDragState.swift`), pure math with no AppKit dependency, covered by `Tests/ParaBearTests/BearDragPhysicsTests.swift`.
