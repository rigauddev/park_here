# PR Backend: Separate Customer And Partner Signup

## Title

`feat(api): add separated customer and partner signup endpoints`

## Scope

- Add `/customers/signup` for customer signup.
- Add `/partners/signup` for partner/business signup.
- Keep `/auth` focused on login/MFA/token flows.
- Add `PartnerSignupRequest`.
- Add `PartnerProfile` model.
- Add partner profile migration.
- Add partner profile metadata to seed table creation.
- Store partner fields:
  - service type
  - company name
  - CNPJ
  - registration status
  - legal responsible
  - insurance flag and provider
  - Instagram
  - website
  - social links
  - approval status

## Validation

```bash
cd parkhere_backend
docker compose up -d --build
docker compose exec api python -m app.scripts.seed_mvp_data
curl http://127.0.0.1:8000/openapi.json
```

Manual endpoint checks performed:

- `POST /customers/signup` returned tokens.
- `POST /partners/signup` returned `approval_status=waiting_documents`.

## Suggested Branch

```bash
git checkout -b feature/backend-separated-signup-endpoints
git add parkhere_backend/app/modules/customers \
        parkhere_backend/app/modules/partners \
        parkhere_backend/app/modules/auth/schemas.py \
        parkhere_backend/app/modules/auth/auth_service.py \
        parkhere_backend/app/main.py \
        parkhere_backend/alembic/env.py \
        parkhere_backend/alembic/versions/b2c3d4e5f6a7_add_partner_profiles.py \
        parkhere_backend/app/scripts/seed_mvp_data.py \
        docs/prs/backend-separated-signup-endpoints.md
git commit -m "feat(api): add separated customer and partner signup"
git push -u origin feature/backend-separated-signup-endpoints
```

