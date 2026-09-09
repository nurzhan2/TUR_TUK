from pydantic import BaseModel, ConfigDict

from app.schemas.product import ProductOut


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    children: list["CategoryOut"] = []


CategoryOut.model_rebuild()


class ProductPage(BaseModel):
    items: list[ProductOut]
    page: int
    limit: int
    total: int
