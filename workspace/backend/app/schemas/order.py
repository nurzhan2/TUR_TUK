from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.order import OrderStatus


class OrderItemIn(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)


class OrderCreate(BaseModel):
    hotel_name: str = Field(min_length=1)
    room_number: str = Field(min_length=1)
    items: list[OrderItemIn] = Field(min_length=1)
    promo_code: str | None = None


class OrderStatusUpdate(BaseModel):
    status: OrderStatus


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    courier_id: int | None
    status: OrderStatus
    total: float
    hotel_name: str
    room_number: str
    delivery_photo_url: str | None


class OrderHistoryItemOut(BaseModel):
    """Позиция заказа для истории — цена СНИМКОМ (`OrderItem.price`), а не
    текущей ценой каталога: тот же принцип, что уже задокументирован
    в `app/models/order_item.py`."""

    product_id: int
    product_name: str
    quantity: int
    price: float


class OrderHistoryOut(OrderOut):
    created_at: datetime
    items: list[OrderHistoryItemOut]


class RepeatSkippedItem(BaseModel):
    product_id: int
    product_name: str


class RepeatOrderOut(BaseModel):
    """Ответ на повтор заказа. Если недоступен ХОТЯ БЫ ОДИН товар, `order` —
    новый заказ из оставшихся позиций, `skipped_items`/`warning` объясняют,
    что не попало в повтор. Если недоступны ВСЕ товары или доступных не
    хватает на минимальную сумму — эндпоинт отвечает 422, а не пустым
    `order` (см. `app/api/orders.py`): различать эти случаи по HTTP-статусу
    надёжнее, чем по `null` в теле."""

    order: OrderOut
    skipped_items: list[RepeatSkippedItem]
    warning: str | None
