from fastapi import APIRouter, Depends, Query, File, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.modules.users.models.user_model import User
from .schemas.rental import *
from .services.rental_service import RentalService

router = APIRouter(prefix="/rentals", tags=["Rentals"])

@router.get("/companies", response_model=list[RentalCompanyOut])
async def list_companies(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_companies(db, current_user)

@router.post("/companies", response_model=RentalCompanyOut, status_code=201)
async def create_company(data: RentalCompanyCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.create_company(db, data, current_user)

@router.post("/companies/{company_id}/logo")
async def upload_company_logo(company_id: str, file: UploadFile = File(...), db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.upload_company_logo(db, company_id, file, current_user)

@router.get("/companies/{company_id}/logo/{name}")
async def read_company_logo(company_id: str, name: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    path = await RentalService.read_company_logo(db, company_id, name, current_user)
    return FileResponse(path)

@router.get("/companies/{company_id}/vehicles", response_model=list[VehicleOut])
async def list_vehicles(company_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_vehicles(db, company_id, current_user)

@router.get("/companies/{company_id}/groups", response_model=list[VehicleGroupOut])
async def list_groups(company_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_groups(db, company_id, current_user)

@router.post("/groups", response_model=VehicleGroupOut, status_code=201)
async def create_group(data: VehicleGroupCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.create_group(db, data, current_user)

@router.patch("/groups/{group_id}/block", response_model=VehicleGroupOut)
async def block_group(group_id: str, blocked: bool = Query(True), db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.set_group_blocked(db, group_id, blocked, current_user)

@router.get("/catalog/models", response_model=list[VehicleCatalogOut])
async def catalog_models(make: str, year: int, vehicle_type: str = 'car', model: str | None = None, current_user: User = Depends(get_current_user)):
    return await RentalService.catalog_models(make, year, vehicle_type, model)

@router.get("/companies/{company_id}/plans", response_model=list[RentalPlanOut])
async def list_plans(company_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_plans(db, company_id, current_user)

@router.post("/plans", response_model=RentalPlanOut, status_code=201)
async def create_plan(data: RentalPlanCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.create_plan(db, data, current_user)

@router.get("/companies/{company_id}/items", response_model=list[RentalItemOut])
async def list_items(company_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_items(db, company_id, current_user)

@router.post("/items", response_model=RentalItemOut, status_code=201)
async def create_item(data: RentalItemCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.create_item(db, data, current_user)

@router.get("/vehicles/{vehicle_id}/maintenance", response_model=list[MaintenanceOut])
async def list_maintenance(vehicle_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_maintenance(db, vehicle_id, current_user)

@router.post("/maintenance", response_model=MaintenanceOut, status_code=201)
async def create_maintenance(data: MaintenanceCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.create_maintenance(db, data, current_user)

@router.get("/reservations/{reservation_id}/contract", response_model=RentalContractOut)
async def get_contract(reservation_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.get_contract(db, reservation_id, current_user)

@router.post("/reservations/{reservation_id}/contract/accept", response_model=RentalContractOut)
async def accept_contract(reservation_id: str, data: ContractAccept, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.accept_contract(db, reservation_id, data.role, current_user)

@router.get("/fines", response_model=list[FineOut])
async def list_fines(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_fines(db, current_user)

@router.post("/fines", response_model=FineOut, status_code=201)
async def create_fine(data: FineCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.create_fine(db, data, current_user)

@router.get("/alerts", response_model=list[RentalAlertOut])
async def list_alerts(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_alerts(db, current_user)

@router.post("/vehicles", response_model=VehicleOut, status_code=201)
async def create_vehicle(data: VehicleCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.create_vehicle(db, data, current_user)

@router.patch("/vehicles/{vehicle_id}", response_model=VehicleOut)
async def update_vehicle(vehicle_id: str, data: VehicleUpdate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.update_vehicle(db, vehicle_id, data, current_user)

@router.post("/vehicles/{vehicle_id}/documents/crlv")
async def upload_crlv(vehicle_id: str, file: UploadFile = File(...), db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.upload_crlv(db, vehicle_id, file, current_user)

@router.get("/vehicles/{vehicle_id}/documents/crlv")
async def read_crlv(vehicle_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    path = await RentalService.read_crlv(db, vehicle_id, current_user)
    return FileResponse(path)

@router.post("/vehicles/{vehicle_id}/photos")
async def upload_vehicle_photo(vehicle_id: str, file: UploadFile = File(...), db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.upload_vehicle_photo(db, vehicle_id, file, current_user)

@router.get("/vehicles/{vehicle_id}/photos/{name}")
async def read_vehicle_photo(vehicle_id: str, name: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    path = await RentalService.read_vehicle_photo(db, vehicle_id, name, current_user)
    return FileResponse(path)

@router.post("/reservations", response_model=ReservationOut, status_code=201)
async def create_reservation(data: ReservationCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.create_reservation(db, data, current_user)

@router.get("/reservations", response_model=list[ReservationOut])
async def list_reservations(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.list_reservations(db, current_user)

@router.get("/reservations/{reservation_id}", response_model=ReservationOut)
async def get_reservation(reservation_id: str, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    return await RentalService.get_reservation(db, reservation_id, current_user)

@router.post("/checkin", status_code=201)
async def checkin(data: CheckinCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    row = await RentalService.checkin(db, data, current_user); return {"id": row.id, "status": "checked_in"}

@router.post("/checkout", status_code=201)
async def checkout(data: CheckoutCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    row = await RentalService.checkout(db, data, current_user); return {"id": row.id, "status": "completed"}
