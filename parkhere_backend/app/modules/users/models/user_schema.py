from pydantic import BaseModel, EmailStr
from typing import Optional
from app.modules.users.models.user_model_role_enum import UserRoleEnum


class UserCreate(BaseModel):

    name: str
    firt_name: str
    email: EmailStr
    password: str
    phone: Optional[str]

    role: UserRoleEnum

    commission_percentage: Optional[float]

class UserResponse(BaseModel):

    id: str
    name: str
    firt_name: str
    email: str
    phone: Optional[str]

    role: UserRoleEnum
    commission_percentage: Optional[float]

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):

    name: Optional[str]
    firt_name: Optional[str]
    email: Optional[EmailStr]
    password: Optional[str]
    phone: Optional[str]
    commission_percentage: Optional[float]

class CustomerSignupRequest(BaseModel):
    name: str
    firt_name: str
    email: EmailStr
    password: str
    cpf: str
    phone: str

class CustomerSignupResponse(BaseModel):

    name: str
    firt_name: str
    email: EmailStr
    password: str
    cpf: str
    phone: str
