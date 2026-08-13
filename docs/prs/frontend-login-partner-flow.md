# PR Frontend: Redesign Login And Partner Registration Flow

## Title

`feat(frontend): redesign login and add partner registration form`

## Scope

- Redesign login screen using RigaudTech-inspired palette.
- Move language selector to the top-right outside the login card.
- Add PT-BR/EN language toggle.
- Improve "access as" selection for Cliente and Parceiro.
- Add animated login background with map, pins, cars, motorcycles and bikes.
- Add ParkHere logo mark with parking/location elements.
- Separate customer and partner registration UI.
- Add partner registration fields:
  - service type
  - company name
  - CNPJ
  - registration status
  - legal responsible person
  - insurance flag and provider for parking/car wash
  - Instagram
  - website
  - social links
- Add Instagram integration note as a future official integration block.

## Validation

```bash
cd parkhere_user_app
dart format lib/features/auth/pages/login_page.dart lib/features/auth/pages/register_page.dart
flutter analyze
flutter build ios --simulator
```

Known: `flutter analyze` still reports existing info-level lint/deprecation items.

## Suggested Branch

```bash
git checkout -b feature/frontend-login-partner-flow
git add parkhere_user_app/lib/features/auth/pages/login_page.dart \
        parkhere_user_app/lib/features/auth/pages/register_page.dart \
        docs/prs/frontend-login-partner-flow.md
git commit -m "feat(frontend): redesign login and partner registration"
git push -u origin feature/frontend-login-partner-flow
```

