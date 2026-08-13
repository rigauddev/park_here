from enum import Enum


class UserRoleEnum(str, Enum):
    CUSTOMER = "customer"
    PARKING_ADMIN = "parking_admin"
    OPERATOR = "operator"
    TOUR_GUIDE = "tour_guide"
    SUPER_ADMIN = "super_admin"


class CommissionType(str, Enum):

    PERCENTAGE = "percentage"
    FIXED = "fixed"