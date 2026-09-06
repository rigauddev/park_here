from pydantic import BaseModel, Field, field_validator


class ParkingServiceInput(BaseModel):
    code: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=120)
    price: float = Field(ge=0, allow_inf_nan=False)
    is_active: bool = True

    @field_validator("code", "name", mode="before")
    @classmethod
    def strip_text(cls, value):
        return value.strip() if isinstance(value, str) else value


class ParkingServiceResponse(ParkingServiceInput):
    id: str


class ParkingPricingResponse(BaseModel):
    firstHourPrice: float
    additionalHourPrice: float
    dailyPrice: float
    weeklyPrice: float = 0
    monthlyPrice: float


class ParkingAreaPricing(BaseModel):
    first_hour_price: float = Field(default=0, ge=0, allow_inf_nan=False)
    additional_hour_price: float = Field(default=0, ge=0, allow_inf_nan=False)
    daily_price: float = Field(default=0, ge=0, allow_inf_nan=False)
    weekly_price: float = Field(default=0, ge=0, allow_inf_nan=False)
    monthly_price: float = Field(default=0, ge=0, allow_inf_nan=False)


class ParkingManagementRequest(BaseModel):
    name: str
    address: str
    city: str = "Valenca"
    lat: float = Field(ge=-90, le=90, allow_inf_nan=False)
    lng: float = Field(ge=-180, le=180, allow_inf_nan=False)
    total_spots: int
    covered_spots: int = 0
    uncovered_spots: int = 0
    vip_spots: int = 0
    large_spots: int = 0
    bus_spots: int = 0
    pickup_spots: int = 0
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


    @field_validator("services")
    @classmethod
    def unique_service_codes(cls, services):
        codes = [service.code for service in services]
        if len(codes) != len(set(codes)):
            raise ValueError("Service codes must be unique per parking")
        return services


class ParkingManagementResponse(BaseModel):
    id: str
    tenant_id: str
    name: str
    address: str
    city: str
    lat: float
    lng: float
    total_spots: int
    available_spots: int
    covered_spots: int
    uncovered_spots: int
    vip_spots: int
    large_spots: int
    bus_spots: int
    pickup_spots: int
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
    city: str
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
