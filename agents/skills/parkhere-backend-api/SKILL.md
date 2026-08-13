---
name: parkhere-backend-api
description: Backend development skill for ParkHere's FastAPI, SQLAlchemy, Alembic, MySQL, auth, multi-tenant parking, reservations, add-on services, payments, and check-in/checkout APIs. Use when creating or reviewing backend modules, API contracts, migrations, schemas, services, tests, security, tenant isolation, or integration points for the Flutter app.
---

# ParkHere Backend API

## Overview

Use this skill to evolve the ParkHere backend without losing the product model: parking tenants manage inventory and operations; drivers reserve and check in/out; add-on services attach to reservations.

## Workflow

1. Read `references/backend-patterns.md` before creating or changing backend modules.
2. Check current modules under `parkhere_backend/app/modules`.
3. Define or update SQLAlchemy models, Pydantic schemas, service functions, routers, and Alembic migrations together.
4. Preserve tenant isolation for parking-admin/operator flows.
5. Keep app-facing response models stable and documented.
6. Validate with tests or import/runtime checks.

## Module Direction

Add MVP modules in this order when requested:

- `parkings`
- `pricing`
- `services`
- `reservations`
- `sessions`
- `payments`
- `incidents`

## Guardrails

- Do not implement plate/facial automation in MVP unless explicitly requested; create enum-ready validation methods instead.
- Avoid hard-coded tenant IDs.
- Prefer explicit status enums for reservations, sessions, payments, and tenants.
- Do not trust client-side price totals; recalculate on the backend.
- Treat reservations and sessions as auditable records.
- Add migration notes for renames such as `firt_name` to `first_name`.

## Output Shape

For backend implementation tasks, include:

- changed files
- API contracts
- migration impact
- tenant/security considerations
- validation command results
