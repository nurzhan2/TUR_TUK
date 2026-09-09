from pydantic import BaseModel, Field


class PromoValidateRequest(BaseModel):
    code: str = Field(min_length=1)
    cart_total: float = Field(gt=0)


class PromoValidateResponse(BaseModel):
    code: str
    discount_amount: float
    total_after_discount: float
