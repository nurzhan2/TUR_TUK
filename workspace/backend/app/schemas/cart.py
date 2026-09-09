from pydantic import BaseModel, ConfigDict, Field

from app.schemas.product import ProductOut


class CartItemIn(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)


class CartItemUpdate(BaseModel):
    quantity: int = Field(gt=0)


class CartItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product: ProductOut
    quantity: int
    line_total: float


class CartOut(BaseModel):
    items: list[CartItemOut]
    total: float
