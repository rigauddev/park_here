# ParkHere Product Domain

## MVP Boundary

MVP includes parking search, availability, reservation, add-on services, payment, and manual/app/gate check-in and checkout.

V2 includes license plate recognition, face recognition, camera integrations, and automatic validation.

## Reservation Lifecycle

- `draft`: user is selecting parking, plan, time, and services.
- `pre_reserved`: temporary hold while user is going to the parking lot.
- `confirmed`: payment/confirmation complete.
- `checked_in`: vehicle/user entered.
- `checked_out`: vehicle/user left and final amount is calculated.
- `expired`: hold expired before confirmation/check-in.
- `cancelled`: user or parking cancelled.

## Business Rules

- Availability decreases when a reservation is confirmed or check-in is validated, depending on the final MVP policy.
- Availability increases on checkout or cancellation when applicable.
- The backend is source of truth for price and availability.
- Add-on services must be stored with reservation snapshot price.
- Manual validation remains mandatory as fallback.

