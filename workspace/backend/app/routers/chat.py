"""Чат клиент↔оператор поддержки по заказу, плюс чат-бот с FAQ.

`WS /ws/chat/{order_id}?token=JWT` — двусторонний канал: и клиент, и
оператор подключаются к одному и тому же order_id и видят сообщения друг
друга в реальном времени. Комнаты держим в памяти процесса (единственный
воркер uvicorn, без Redis) — тот же принцип простоты, что и у остального
бэкенда.

Курьерский чат с клиентом (отдельный деливерабл курьерского приложения)
сюда не входит: это чат клиент↔оператор/бот, курьер доступа к нему не
получает.
"""

import json

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.core.rbac import STAFF_ROLES
from app.core.security import InvalidTokenError, decode_token
from app.db.session import get_session
from app.models.bot_response import BotResponse
from app.models.chat_message import ChatMessage
from app.models.order import Order
from app.models.user import User
from app.schemas.chat import ChatMessageOut

router = APIRouter(tags=["chat"])

_FALLBACK_ANSWER = (
    "Спасибо за сообщение! Мы скоро ответим — а пока посмотрите частые "
    "вопросы: оплата, доставка, минимальная сумма заказа."
)


def _can_access_chat(user: User, order: Order) -> bool:
    """Клиент видит чат своего заказа, персонал (`STAFF_ROLES`) — любого.

    Курьер сюда намеренно не включён: его чат с клиентом — отдельная
    функциональность курьерского приложения, а не эта задача.
    """
    if user.role.code in STAFF_ROLES:
        return True
    return order.user_id == user.id


async def _authenticate_ws(token: str, session: AsyncSession) -> User | None:
    try:
        payload = decode_token(token, expected_type="access")
        user_id = int(payload["sub"])
    except (InvalidTokenError, KeyError, TypeError, ValueError):
        return None

    result = await session.execute(
        select(User).options(selectinload(User.role)).where(User.id == user_id)
    )
    user = result.scalar_one_or_none()
    # Удалённый гость / отключённый сотрудник — как в REST (`get_current_user`).
    return user if user is not None and user.is_active else None


def _extract_body(raw: str) -> str:
    """Клиент может прислать `{"body": "..."}` или голый текст — оба валидны."""
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return raw.strip()
    if isinstance(data, dict):
        return str(data.get("body", "")).strip()
    return raw.strip()


def _serialize(message: ChatMessage) -> dict:
    return {
        "id": message.id,
        "order_id": message.order_id,
        "sender_id": message.sender_id,
        "is_bot": message.is_bot,
        "body": message.body,
        "created_at": message.created_at.isoformat(),
    }


async def _bot_reply(session: AsyncSession, text: str) -> str:
    """Ищет FAQ по вхождению ключевых слов в текст сообщения, побеждает
    ответ с наибольшим числом совпавших ключевых слов. Нет совпадений —
    честный fallback вместо тишины."""
    normalized = text.lower()
    result = await session.execute(select(BotResponse))

    best_answer: str | None = None
    best_score = 0
    for response in result.scalars().all():
        keywords = [k.strip() for k in response.keywords.lower().split(",") if k.strip()]
        score = sum(1 for keyword in keywords if keyword in normalized)
        if score > best_score:
            best_score = score
            best_answer = response.answer

    return best_answer if best_answer is not None else _FALLBACK_ANSWER


class _ChatRoomManager:
    """Реестр открытых WS-соединений по order_id, в памяти процесса."""

    def __init__(self) -> None:
        self._rooms: dict[int, set[WebSocket]] = {}

    async def connect(self, order_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._rooms.setdefault(order_id, set()).add(websocket)

    def disconnect(self, order_id: int, websocket: WebSocket) -> None:
        room = self._rooms.get(order_id)
        if room is None:
            return
        room.discard(websocket)
        if not room:
            self._rooms.pop(order_id, None)

    async def broadcast(self, order_id: int, payload: dict) -> None:
        for websocket in list(self._rooms.get(order_id, ())):
            try:
                await websocket.send_json(payload)
            except Exception:
                self.disconnect(order_id, websocket)


_manager = _ChatRoomManager()


@router.websocket("/ws/chat/{order_id}")
async def chat_websocket(
    websocket: WebSocket,
    order_id: int,
    token: str = Query(...),
    session: AsyncSession = Depends(get_session),
) -> None:
    user = await _authenticate_ws(token, session)
    if user is None:
        await websocket.close(code=4401)
        return

    order = await session.get(Order, order_id)
    if order is None:
        await websocket.close(code=4404)
        return

    if not _can_access_chat(user, order):
        await websocket.close(code=4403)
        return

    await _manager.connect(order_id, websocket)
    try:
        while True:
            raw = await websocket.receive_text()
            body = _extract_body(raw)
            if not body:
                continue

            # Бот отвечает на ПЕРВОЕ сообщение именно клиента-владельца
            # заказа, а не на первое сообщение в чате вообще — иначе
            # реплика оператора тоже запускала бы автоответ.
            is_first_client_message = False
            if user.id == order.user_id:
                count_result = await session.execute(
                    select(func.count())
                    .select_from(ChatMessage)
                    .where(ChatMessage.order_id == order_id, ChatMessage.sender_id == user.id)
                )
                is_first_client_message = count_result.scalar_one() == 0

            message = ChatMessage(order_id=order_id, sender_id=user.id, body=body)
            session.add(message)
            await session.commit()
            await session.refresh(message)
            await _manager.broadcast(order_id, _serialize(message))

            if is_first_client_message:
                answer = await _bot_reply(session, body)
                bot_message = ChatMessage(order_id=order_id, sender_id=None, body=answer)
                session.add(bot_message)
                await session.commit()
                await session.refresh(bot_message)
                await _manager.broadcast(order_id, _serialize(bot_message))
    except WebSocketDisconnect:
        pass
    finally:
        _manager.disconnect(order_id, websocket)


@router.get("/chat/{order_id}/messages", response_model=list[ChatMessageOut])
async def get_chat_messages(
    order_id: int,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> list[ChatMessage]:
    order = await session.get(Order, order_id)
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="заказ не найден")
    if not _can_access_chat(current_user, order):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="нет доступа к чату этого заказа",
        )

    result = await session.execute(
        select(ChatMessage).where(ChatMessage.order_id == order_id).order_by(ChatMessage.id)
    )
    return list(result.scalars().all())
