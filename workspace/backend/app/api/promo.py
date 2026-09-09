"""Промокоды: `POST /promo/validate` проверяет код и считает скидку.

Только проверка, без побочных эффектов — `used_count` не увеличивается
здесь. Клиент может свободно применять/менять промокод в корзине до
оформления заказа, и не каждая проверка должна расходовать лимит
использований; списание — дело `POST /orders` (см. `app/api/orders.py`),
который переиспользует `get_valid_promo`/`compute_discount` отсюда, чтобы
правила «код существует, активен, не истёк, не исчерпан» и подсчёт скидки
не разъезжались между проверкой в корзине и настоящим оформлением заказа.
"""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.promo_code import PromoCode
from app.schemas.promo import PromoValidateRequest, PromoValidateResponse

router = APIRouter(prefix="/promo", tags=["promo"])


async def get_valid_promo(session: AsyncSession, code: str) -> PromoCode:
    """Код существует и применим сейчас, иначе 404/422 — те же коды, что были
    у `validate_promo` до выделения этой функции."""
    result = await session.execute(
        select(PromoCode).where(func.lower(PromoCode.code) == code.lower())
    )
    promo = result.scalar_one_or_none()
    if promo is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="промокод не найден")

    if not promo.is_active:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="промокод не активен"
        )

    if promo.valid_until is not None and promo.valid_until < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="срок действия промокода истёк"
        )

    if promo.max_uses is not None and promo.used_count >= promo.max_uses:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="лимит использований промокода исчерпан",
        )

    return promo


def compute_discount(promo: PromoCode, cart_total: float) -> float:
    if promo.discount_percent is not None:
        discount = cart_total * float(promo.discount_percent) / 100
    elif promo.discount_amount is not None:
        discount = float(promo.discount_amount)
    else:
        discount = 0.0
    # скидка не может увести итог в минус, даже у фиксированной суммы больше total
    return min(discount, cart_total)


@router.post("/validate", response_model=PromoValidateResponse)
async def validate_promo(
    payload: PromoValidateRequest,
    session: AsyncSession = Depends(get_session),
) -> PromoValidateResponse:
    promo = await get_valid_promo(session, payload.code)
    discount_amount = compute_discount(promo, payload.cart_total)
    return PromoValidateResponse(
        code=promo.code,
        discount_amount=discount_amount,
        total_after_discount=payload.cart_total - discount_amount,
    )
