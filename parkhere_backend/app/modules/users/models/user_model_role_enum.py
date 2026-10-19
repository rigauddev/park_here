from enum import Enum


class UserRoleEnum(str, Enum):
    CUSTOMER = "customer"
    PARTNER_MANAGER = "partner_manager"
    PARKING_ADMIN = "parking_admin"
    OPERATOR = "operator"
    TOUR_GUIDE = "tour_guide"
    SUPER_ADMIN = "super_admin"
    SYSTEM_ADMIN_OPERATOR = "system_admin_operator"


class CommissionType(str, Enum):

    PERCENTAGE = "percentage"
    FIXED = "fixed"
