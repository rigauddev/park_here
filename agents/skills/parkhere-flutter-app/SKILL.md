---
name: parkhere-flutter-app
description: Flutter app development skill for ParkHere's driver experience. Use when building or reviewing Flutter screens, Riverpod providers, models, services, routing, map/search UX, reservations, add-on services, payment, check-in/checkout, API integration, state management, or mobile validation flows.
---

# ParkHere Flutter App

## Overview

Use this skill to build the ParkHere user app with clear feature boundaries, predictable Riverpod state, and flows that match the backend contracts.

## Workflow

1. Read `references/flutter-patterns.md` before changing app architecture or feature flows.
2. Locate the target feature under `parkhere_user_app/lib/features`.
3. Keep models, providers, services, and pages separated.
4. Move calculations and API work out of widgets.
5. Preserve the user's journey: search, select, reserve, pay, route, check in, check out.
6. Run `dart format`, `flutter analyze`, and focused tests when available.

## UX Guardrails

- The first screen after auth should help the driver find parking quickly.
- Show availability, plan price, distance/route context, and services before reservation confirmation.
- Make reservation expiry visible when pre-reservation is active.
- Treat payment and check-in states as explicit, not implied by navigation.
- For V2 automation, surface status and fallback manual actions.

## Output Shape

For Flutter tasks, include:

- changed screens/providers/services
- API assumptions
- state transitions
- validation commands
- screenshots or manual test notes when UI changed
