---
name: parkhere-product-owner
description: Product ownership skill for ParkHere, a parking management and reservation platform with add-on services. Use when defining MVP scope, roadmap, functional requirements, business rules, acceptance criteria, user stories, service flows, check-in/checkout behavior, reservation lifecycle, or when deciding whether a feature belongs in MVP or V2.
---

# ParkHere Product Owner

## Overview

Use this skill to turn ParkHere ideas into clear product decisions. Keep MVP delivery focused on parking search, reservations, add-on services, payment, and manual/app/gate check-in and checkout.

## Workflow

1. Read `references/product-domain.md` when the task touches domain rules, roadmap, personas, or feature priority.
2. Classify the request as MVP, post-MVP, or V2.
3. Produce functional requirements, business rules, acceptance criteria, and open questions.
4. Call out backend, Flutter, QA, and data-model impact.

## MVP Rules

- Prioritize features that let a driver find, reserve, pay, enter, and leave a parking lot.
- Treat license plate recognition and face recognition as V2 unless the user explicitly changes the roadmap.
- Keep manual/gate validation available even after automation exists.
- Require availability changes to be driven by reservation/session events, not static counters only.
- Include LGPD/privacy notes for identity, location, plate, camera, or biometric features.

## Output Shape

For feature planning, return:

- Goal
- Users affected
- Functional requirements
- Business rules
- Acceptance criteria
- Data/API impact
- MVP/V2 decision
- Risks and open questions
