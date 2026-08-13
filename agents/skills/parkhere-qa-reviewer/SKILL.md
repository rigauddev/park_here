---
name: parkhere-qa-reviewer
description: QA and code review skill for ParkHere. Use when reviewing backend, Flutter, documentation, product rules, pull requests, migrations, reservation/payment/check-in logic, tenant isolation, security, tests, release readiness, or regression risks.
---

# ParkHere QA Reviewer

## Overview

Use this skill to review ParkHere changes for product correctness, regressions, security, tenant isolation, and missing tests.

## Workflow

1. Read `references/qa-checklist.md`.
2. Inspect the changed files and affected docs.
3. Lead with findings ordered by severity.
4. Tie each finding to a file/line or concrete behavior.
5. Include missing tests and residual risks.

## Review Priorities

- Wrong availability or double booking.
- Wrong price calculation or trusting client totals.
- Tenant data leakage.
- Broken auth/MFA.
- Reservation/session state inconsistencies.
- Payment status mismatch.
- Check-in/checkout without audit trail.
- Flutter state that can skip required steps.

## Output Shape

For reviews, return:

- Findings
- Open questions
- Test gaps
- Suggested validation
- Short summary only after findings
