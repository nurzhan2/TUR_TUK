from datetime import date, datetime, timezone

from pydantic import BaseModel, ConfigDict, Field, field_validator

PHONE_PATTERN = r"^\+?[0-9]{7,15}$"


class SendCodeRequest(BaseModel):
    phone: str = Field(..., pattern=PHONE_PATTERN)


class SendCodeResponse(BaseModel):
    status: str = "sent"
    expires_in: int


class VerifyCodeRequest(BaseModel):
    phone: str = Field(..., pattern=PHONE_PATTERN)
    code: str = Field(..., pattern=r"^[0-9]{4,8}$")


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    # Необязательна: в приложении поле не обязательное (ТЗ — nice-to-have),
    # и требование её здесь давало 422 каждому гостю, кто её не указал.
    dob: date | None = None
    hotel_name: str = Field(..., min_length=1, max_length=255)
    room_number: str = Field(..., min_length=1, max_length=50)

    @field_validator("dob")
    @classmethod
    def _dob_not_in_future(cls, value: date | None) -> date | None:
        if value is None:
            return value
        if value > datetime.now(timezone.utc).date():
            raise ValueError("дата рождения не может быть в будущем")
        return value

    @field_validator("name", "hotel_name", "room_number")
    @classmethod
    def _strip(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("поле не может быть пустым")
        return value


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    phone: str
    name: str | None
    dob: date | None
    hotel_name: str | None
    room_number: str | None
