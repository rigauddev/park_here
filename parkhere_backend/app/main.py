import os
import json
import logging
import time
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.modules.auth.router import router as auth_router
from app.modules.customers.router import router as customers_router
from app.modules.customer_assets.router import router as customer_assets_router
from app.modules.parkings.router import router as parkings_router
from app.modules.partners.router import router as partners_router
from app.modules.payments.router import router as payments_router
from app.modules.platform_fees.router import router as platform_fees_router
from app.modules.dashboard.router import router as dashboard_router
from app.modules.parkings.convenience_router import router as convenience_router
from app.modules.reservations.router import router as reservations_router
from app.modules.users.user_router import router as user_router

app = FastAPI(
    title="ParkHere SaaS API",
    version="1.0.0"
)

logger = logging.getLogger("parkhere.api")


@app.middleware("http")
async def structured_request_log(request, call_next):
    started = time.perf_counter()
    try:
        response = await call_next(request)
    except Exception:
        logger.exception("api_request_failed", extra={"path": request.url.path, "method": request.method})
        raise
    elapsed_ms = round((time.perf_counter() - started) * 1000, 2)
    logger.info(json.dumps({
        "event": "api_request",
        "method": request.method,
        "path": request.url.path,
        "status": response.status_code,
        "duration_ms": elapsed_ms,
    }, ensure_ascii=False))
    return response

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in os.getenv("CORS_ORIGINS", "*").split(",") if origin.strip()],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(customers_router)
app.include_router(customer_assets_router)
app.include_router(user_router)
app.include_router(parkings_router)
app.include_router(partners_router)
app.include_router(reservations_router)
app.include_router(payments_router)
app.include_router(platform_fees_router)
app.include_router(dashboard_router)
app.include_router(convenience_router)


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
    
