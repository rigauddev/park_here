# Flutter Patterns

## Current Stack

- Flutter app in `parkhere_user_app`.
- Riverpod for state.
- Features under `lib/features`.
- Shared services, theme, routing, and constants under `lib/core`.

## Feature Shape

Prefer:

```text
features/<feature>/
  models/
  pages/
  providers/
  services/
  widgets/
```

## State Rules

- Keep API calls in services/providers.
- Keep calculations in pure services.
- Keep widgets focused on rendering and user input.
- Model loading, error, empty, and success states explicitly.
- Do not let navigation imply payment/check-in success.

## MVP User Journey

1. Auth gate.
2. Map/search.
3. Parking detail/selection.
4. Plan and add-on services.
5. Pre-reservation/reservation.
6. Payment.
7. Route.
8. Check-in.
9. Checkout.

