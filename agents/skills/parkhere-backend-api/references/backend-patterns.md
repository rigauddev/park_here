# Backend Patterns

## Current Stack

- FastAPI app in `parkhere_backend/app/main.py`.
- Modules in `parkhere_backend/app/modules/<domain>`.
- SQLAlchemy models use `app.db.base.BaseModel`.
- Alembic migrations live in `parkhere_backend/alembic/versions`.
- MySQL runs through `parkhere_backend/docker-compose.yml`.

## Module Shape

Prefer:

```text
app/modules/<domain>/
  router.py
  service.py
  schemas.py
  models/
    <domain>_model.py
    <domain>_status_enum.py
```

## API Rules

- Use response models for public endpoints.
- Recalculate totals server-side.
- Include `tenant_id` on parking-owned resources.
- Never expose another tenant's reservations, users, services, or sessions.
- Use explicit status enums rather than free strings.
- Add timestamps for auditable lifecycle records.

## Known Fix Targets

- Align `AuthService.verify_mfa` with router schema.
- Add missing imports and token helpers in auth service.
- Replace `firt_name` with `first_name` through a planned migration.
- Avoid comparing enum roles to raw strings.

