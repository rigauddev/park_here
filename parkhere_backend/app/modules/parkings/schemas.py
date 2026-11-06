from pydantic import BaseModel, Field, field_validator


class ParkingServiceInput(BaseModel):
    code: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    price: float = Field(ge=0, allow_inf_nan=False)
    is_active: bool = True

    @field_validator("code", "name", "description", mode="before")
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
    coveredDailyPrice: float = 0
    uncoveredDailyPrice: float = 0
    coveredFirstHourPrice: float = 0
    uncoveredFirstHourPrice: float = 0


class ParkingAreaPricing(BaseModel):
    first_hour_price: float = Field(default=0, ge=0, allow_inf_nan=False)
    additional_hour_price: float = Field(default=0, ge=0, allow_inf_nan=False)
    daily_price: float = Field(default=0, ge=0, allow_inf_nan=False)
    weekly_price: float = Field(default=0, ge=0, allow_inf_nan=False)
    monthly_price: float = Field(default=0, ge=0, allow_inf_nan=False)


class ParkingManagementRequest(BaseModel):
    arrival_tolerance_minutes: int = Field(default=15, ge=1, le=120)
    name: str
    address: str
    street: str | None = None
    number: str | None = None
    neighborhood: str | None = None
    postal_code: str | None = None
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
    moto_home_spots: int = 0
    available_spots: int | None = None
    has_vip_spots: bool = False
    has_24h_gate: bool = False
    work_regime: str = "commercial"
    operating_hours: dict[str, dict[str, object] | None] = Field(default_factory=dict)
    has_security_system: bool = False
    wants_automatic_access: bool = False
    has_automatic_access: bool = False
    uncovered_pricing: ParkingAreaPricing
    covered_pricing: ParkingAreaPricing | None = None
    category_pricing: dict[str, ParkingAreaPricing] = Field(default_factory=dict)
    services: list[ParkingServiceInput] = Field(default_factory=list)
    is_active: bool = True


    @field_validator("services")
    @classmethod
    def unique_service_codes(cls, services):
        codes = [service.code for service in services]
        if len(codes) != len(set(codes)):
            raise ValueError("Service codes must be unique per parking")
        return services

    @field_validator("work_regime")
    @classmethod
    def valid_work_regime(cls, value):
        allowed = {"commercial", "three_shifts", "24h_on_3off", "administrative_8h"}
        if value not in allowed:
            raise ValueError("Invalid unit work regime")
        return value


class ParkingManagementResponse(BaseModel):
    arrival_tolerance_minutes: int = 15
    id: str
    tenant_id: str
    name: str
    address: str
    street: str | None = None
    number: str | None = None
    neighborhood: str | None = None
    postal_code: str | None = None
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
    moto_home_spots: int = 0
    has_covered_area: bool
    has_vip_spots: bool
    has_24h_gate: bool
    work_regime: str = "commercial"
    operating_hours: dict[str, dict[str, str] | None] = Field(default_factory=dict)
    has_security_system: bool
    wants_automatic_access: bool
    has_automatic_access: bool
    is_active: bool
    accepts_guide_affiliates: bool = False
    uncovered_pricing: ParkingAreaPricing
    covered_pricing: ParkingAreaPricing
    category_pricing: dict[str, ParkingAreaPricing] = Field(default_factory=dict)
    blocked_spots: list[str] = Field(default_factory=list)
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
    category_pricing: dict[str, ParkingAreaPricing] = Field(default_factory=dict)
    hasCarWash: bool
    hasTourGuide: bool
    hasTransportService: bool
    hasCoveredArea: bool
    hasVipSpots: bool
    coveredSpots: int = 0
    uncoveredSpots: int = 0
    vipSpots: int = 0
    largeSpots: int = 0
    busSpots: int = 0
    pickupSpots: int = 0
    motoHomeSpots: int = 0
    coveredDailyPrice: float = 0
    uncoveredDailyPrice: float = 0
    vipDailyPrice: float = 0
    largeDailyPrice: float = 0
    busDailyPrice: float = 0
    pickupDailyPrice: float = 0
    carWashPrice: float
    tourGuidePrice: float
    transportPrice: float
    isOpen: bool = True
    operating_hours: dict[str, dict[str, str] | None] = Field(default_factory=dict)
