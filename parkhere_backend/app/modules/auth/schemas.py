from pydantic import BaseModel, EmailStr

class RegisterParkingSchema(BaseModel):
    tenant_name: str
    cnpj: str
    name: str
    firt_name: str
    phone: str
    email: EmailStr
    password: str

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
