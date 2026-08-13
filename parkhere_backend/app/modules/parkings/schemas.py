from pydantic import BaseModel


class ParkingPricingResponse(BaseModel):
    firstHourPrice: float
    additionalHourPrice: float
    dailyPrice: float
    monthlyPrice: float


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
