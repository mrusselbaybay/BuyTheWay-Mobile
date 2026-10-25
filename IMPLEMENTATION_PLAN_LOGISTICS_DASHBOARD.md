# Buytheway Logistics Dashboard — Implementation Plan

**Design reference:** Superdesign project `1a6a904a-0d13-4638-8977-0d73de6ee78c`, draft `a1b933be-8df4-45a1-9d9d-2ebc82fea490` (“Buytheway Logistics - Compact Premium Dashboard”).

**Status:** Reference supplied as pasted HTML. The dashboard implementation below adapts its composition and visual direction to the existing Flutter mobile app and live data model.

## Target and existing behavior

The target is the existing logistics home dashboard in `lib/screens/logistics/dashboard/logistics_dashboard_screen.dart`, rendered within the logistics shell in `lib/screens/logistics/logistics_shell.dart`.

The screen currently receives the logistics account, pending and scanned inventory parcels, loading/error state, refresh and inventory callbacks, and notification count/callback. It derives pickup, transfer-in, and transfer-out counts from pending parcel origins. Existing interactions include pull-to-refresh, opening the inventory queue, opening notifications, and viewing route counts. Preserve these behaviors and their source data.

## Implemented

In `lib/screens/logistics/dashboard/logistics_dashboard_screen.dart`:

- Recreated the reference’s teal receiving hero, status monitor, route breakdown, and secure-handover note with Flutter widgets.
- Kept the company identity, Buytheway logo, unread notification badge, refresh behavior, and existing inventory navigation callbacks.
- Bound all figures to current app data: pending parcels, scanned inventory, seller pickups, transfer receipts, and transfer departures. The reference’s hard-coded sample totals were not copied.
- Kept the existing logistics bottom navigation in `LogisticsShell` and `LogisticsNavBar`; the HTML desktop sidebar/header and mobile nav are not duplicated inside the dashboard.
- Added a wide-screen arrangement with the hero beside the status monitor and three route cards; narrow screens stack the sections and use a compact route list.
- Preserved loading placeholders (`—`), error display, scroll behavior, and pull-to-refresh.

## Reference adaptations

- Search, profile menu, scan/manual-entry actions, reporting, time filters, and dispatch totals in the HTML have no matching dashboard callbacks or live data in the current mobile feature, so they were not added as nonfunctional controls.
- The Android/iOS dashboard keeps the app’s existing bottom navigation rather than duplicating the HTML’s responsive web navigation.
- The supplied HTML references Plus Jakarta Sans and Space Grotesk from Google Fonts. This implementation uses Flutter’s bundled/default font stack to avoid runtime network font loading and new dependencies.

## Follow-up verification

- Review the rendered screen on a narrow phone and a wide/tablet viewport for clipping and visual hierarchy.
- Verify notification and inventory taps, pull-to-refresh, loading/error states, and zero route counts in the running app.
- Run Flutter static analysis after implementation if requested.

## Data and behavior constraints

- Do not add backend fields, API calls, or fabricated dashboard statistics to satisfy a visual element. If the draft includes a metric the current screen cannot supply, identify the data gap before adding it.
- Preserve the meanings of pickup, transfer receipt, and transfer departure counts based on `InventoryOrigin`.
- Keep refresh and navigation ownership with the existing callbacks.
- Keep notification unread count sourced from the existing parent/controller flow.

## Files likely involved

- `lib/screens/logistics/dashboard/logistics_dashboard_screen.dart` — primary dashboard composition and local presentation widgets.
- `lib/screens/logistics/logistics_shell.dart` — only if the design changes shell-level dashboard chrome or the way dashboard callbacks/data are wired.
- `lib/screens/logistics/widgets/logistics_nav_bar.dart` — only if visible navigation in the reference requires an adjustment.

