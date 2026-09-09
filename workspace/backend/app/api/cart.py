"""Корзина: POST/GET/PUT/DELETE над `cart_items` текущего пользователя.

Корзина приватная — доступ только владельцу, RBAC ролей не требует (любая
роль владеет только своими позициями). Обращение к чужому/несуществующему
`item_id` отвечает 404, а не 403: в отличие от `/orders` персонал корзины
чужих пользователей не смотрит, поэтому различать «не найдено» и «не твоё»
незачем, а 404 не палит факт существования чужого id.

Deliverable «скрывать товар из каталога при отсутствии в наличии» уже
реализован в `catalog._AVAILABLE`; здесь то же правило распространено на
корзину. Недоступный товар нельзя ДОБАВИТЬ (POST отвечает 404, тем же
кодом, что и каталог на скрытый товар), а уже добавленный, но ставший
недоступным позже, не удаляется из БД — просто исключается из выдачи и из
`total`, пока не появится в продаже снова.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.db.session import get_session
from app.models.cart_item import CartItem
from app.models.product import Product
from app.models.user import User
from app.schemas.cart import CartItemIn, CartItemUpdate, CartItemOut, CartOut
from app.schemas.product import ProductOut

router = APIRouter(prefix="/cart", tags=["cart"])

_AVAILABLE = Product.is_available.is_(True)


async def _load_available_items(session: AsyncSession, user_id: int) -> list[CartItem]:
    result = await session.execute(
        select(CartItem)
        .join(Product, CartItem.product_id == Product.id)
        .where(CartItem.user_id == user_id, _AVAILABLE)
        .options(selectinload(CartItem.product))
        .order_by(CartItem.id)
    )
    return list(result.scalars().all())


def _to_out(item: CartItem) -> CartItemOut:
    line_total = float(item.product.price) * item.quantity
    return CartItemOut(
        id=item.id,
        product=ProductOut.model_validate(item.product),
        quantity=item.quantity,
        line_total=line_total,
    )


async def _cart_out(session: AsyncSession, user_id: int) -> CartOut:
    out_items = [_to_out(item) for item in await _load_available_items(session, user_id)]
    return CartOut(items=out_items, total=sum((i.line_total for i in out_items), 0.0))


async def _get_own_item(session: AsyncSession, user_id: int, item_id: int) -> CartItem:
    item = (
        await session.execute(
            select(CartItem).where(CartItem.id == item_id, CartItem.user_id == user_id)
        )
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="позиция корзины не найдена"
        )
    return item


@router.get("", response_model=CartOut)
async def get_cart(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CartOut:
    return await _cart_out(session, current_user.id)


@router.post("/items", response_model=CartOut)
async def add_item(
    payload: CartItemIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CartOut:
    product = (
        await session.execute(
            select(Product).where(Product.id == payload.product_id, _AVAILABLE)
        )
    ).scalar_one_or_none()
    if product is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="товар не найден")

    existing = (
        await session.execute(
            select(CartItem).where(
                CartItem.user_id == current_user.id,
                CartItem.product_id == payload.product_id,
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        existing.quantity += payload.quantity
    else:
        session.add(
            CartItem(
                user_id=current_user.id,
                product_id=payload.product_id,
                quantity=payload.quantity,
            )
        )
    await session.commit()
    return await _cart_out(session, current_user.id)


@router.put("/items/{item_id}", response_model=CartOut)
async def update_item(
    item_id: int,
    payload: CartItemUpdate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CartOut:
    item = await _get_own_item(session, current_user.id, item_id)
    item.quantity = payload.quantity
    await session.commit()
    return await _cart_out(session, current_user.id)


@router.delete("/items/{item_id}", response_model=CartOut)
async def remove_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CartOut:
    item = await _get_own_item(session, current_user.id, item_id)
    await session.delete(item)
    await session.commit()
    return await _cart_out(session, current_user.id)


@router.delete("", response_model=CartOut)
async def clear_cart(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> CartOut:
    await session.execute(delete(CartItem).where(CartItem.user_id == current_user.id))
    await session.commit()
    return await _cart_out(session, current_user.id)
