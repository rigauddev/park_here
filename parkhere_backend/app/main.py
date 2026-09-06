import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.modules.auth.router import router as auth_router
from app.modules.customers.router import router as customers_router
from app.modules.parkings.router import router as parkings_router
from app.modules.partners.router import router as partners_router
from app.modules.payments.router import router as payments_router
from app.modules.reservations.router import router as reservations_router
from app.modules.users.user_router import router as user_router

app = FastAPI(
    title="ParkHere SaaS API",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in os.getenv("CORS_ORIGINS", "*").split(",") if origin.strip()],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(customers_router)
app.include_router(user_router)
app.include_router(parkings_router)
app.include_router(partners_router)
app.include_router(reservations_router)
app.include_router(payments_router)


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
    
