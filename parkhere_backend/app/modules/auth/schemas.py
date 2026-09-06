import re

from pydantic import BaseModel, EmailStr, field_validator


def _digits(value: str, label: str, lengths: set[int]) -> str:
    value = re.sub(r'\D', '', value or '')
    if len(value) not in lengths or len(set(value)) == 1:
        raise ValueError(f'{label} invalido')
    return value


def _phone(value: str | None) -> str | None:
    if value is None:
        return value
    value = re.sub(r'\D', '', value)
    if value.startswith('55') and len(value) in {12, 13}:
        value = value[2:]
    if len(value) not in {10, 11} or (len(value) == 11 and value[2] != '9'):
        raise ValueError('Telefone brasileiro invalido')
    return value


def _cpf(value: str) -> str:
    return _digits(value, 'CPF', {11})


def _cnpj(value: str) -> str:
    return _digits(value, 'CNPJ', {14})

class RegisterParkingSchema(BaseModel):
    tenant_name: str
    cnpj: str
    name: str
    firt_name: str
    phone: str
    email: EmailStr
    password: str

    _validate_cnpj = field_validator('cnpj')(_cnpj)
    _validate_phone = field_validator('phone')(_phone)

class CreateUserRequest(BaseModel):
    name: str
    firt_name: str
    email: EmailStr
    password: str
    phone: str | None
    role: str  # operator ou tour_guide
    commission_type: str | None  # percentage ou fixed
    commission_value: float | None
class CustomerSignupRequest(BaseModel):
    name: str
    firt_name: str
    email: EmailStr
    password: str
    cpf: str
    phone: str

    _validate_cpf = field_validator('cpf')(_cpf)
    _validate_phone = field_validator('phone')(_phone)


class PartnerSignupRequest(BaseModel):
    service_type: str
    company_name: str
    cnpj: str
    registration_status: str
    responsible_name: str
    email: EmailStr
    password: str
    phone: str | None = None
    has_insurance: bool = False
    insurance_provider: str | None = None
    instagram: str | None = None
    website: str | None = None
    social_links: str | None = None

    _validate_cnpj = field_validator('cnpj')(_cnpj)
    _validate_phone = field_validator('phone')(_phone)
    
class LoginRequest(BaseModel):
    email: str
    password: str
    account_type: str | None = None

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str
    account_type: str
    tenant_id: str | None = None

class MFARequest(BaseModel):
    mfa_token: str
    code: str

class MFASendRequest(BaseModel):
    mfa_token: str
    method: str  # "email" ou "sms"

class MFAValidateRequest(BaseModel):
    mfa_token: str
    code: str

class EmailCodeRequest(BaseModel):
    email: str

class VerifyEmailCodeRequest(BaseModel):
    email_token: str
    code: str

class PasswordResetRequest(BaseModel):
    email: str

class VerifyPasswordResetCodeRequest(BaseModel):
    reset_token: str
    code: str

class CompletePasswordResetRequest(BaseModel):
    reset_token: str
    code: str
    new_password: str
