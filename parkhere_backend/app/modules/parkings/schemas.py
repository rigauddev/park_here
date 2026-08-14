from pydantic import BaseModel, Field


class ParkingServiceInput(BaseModel):
    code: str
    name: str
    price: float
    is_active: bool = True


class ParkingServiceResponse(ParkingServiceInput):
    id: str


class ParkingPricingResponse(BaseModel):
    firstHourPrice: float
    additionalHourPrice: float
    dailyPrice: float
    weeklyPrice: float = 0
    monthlyPrice: float


class ParkingAreaPricing(BaseModel):
    first_hour_price: float = 0
    additional_hour_price: float = 0
    daily_price: float = 0
    weekly_price: float = 0
    monthly_price: float = 0


class ParkingManagementRequest(BaseModel):
    name: str
    address: str
    lat: float
    lng: float
    total_spots: int
    covered_spots: int = 0
    uncovered_spots: int = 0
    available_spots: int | None = None
    has_vip_spots: bool = False
    has_24h_gate: bool = False
    has_security_system: bool = False
    wants_automatic_access: bool = False
    has_automatic_access: bool = False
    uncovered_pricing: ParkingAreaPricing
    covered_pricing: ParkingAreaPricing | None = None
    services: list[ParkingServiceInput] = Field(default_factory=list)
    is_active: bool = True


class ParkingManagementResponse(BaseModel):
    id: str
    tenant_id: str
    name: str
    address: str
    lat: float
    lng: float
    total_spots: int
    available_spots: int
    covered_spots: int
    uncovered_spots: int
    has_covered_area: bool
    has_vip_spots: bool
    has_24h_gate: bool
    has_security_system: bool
    wants_automatic_access: bool
    has_automatic_access: bool
    is_active: bool
    uncovered_pricing: ParkingAreaPricing
    covered_pricing: ParkingAreaPricing
    services: list[ParkingServiceResponse]


class ParkingResponse(BaseModel):
    id: str
    name: str
    lat: float
    lng: float
    rating: float
    availableSpots: int
    pricing: ParkingPricingResponse
    hasCarWash: bool
    hasTourGuide: bool
    hasTransportService: bool
    hasCoveredArea: bool
    hasVipSpots: bool
    carWashPrice: float
    tourGuidePrice: float
    transportPrice: float
