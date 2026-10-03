"""Веб-админка: сотрудники — курьеры, сборщики, поддержка, администраторы.

Персоналу админки задаётся пароль; курьеры входят в своё приложение по SMS
с тем же номером телефона, поэтому номер здесь — главный идентификатор.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.passwords import MIN_PASSWORD_LENGTH, hash_password
from app.core.rbac import ADMIN_ROLES
from app.db.session import get_session
from app.models.role import Role, RoleCode
from app.models.user import User
from app.web.admin import normalize_phone
from app.web.deps import get_admin_user
from app.web.ui import redirect, render

router = APIRouter(prefix="/admin", tags=["admin-web-staff"])

ROLE_LABELS: dict[str, str] = {
    RoleCode.OWNER.value: "Владелец",
    RoleCode.DIRECTOR.value: "Директор",
    RoleCode.ADMIN.value: "Администратор",
    RoleCode.COLLECTOR.value: "Сборщик",
    RoleCode.SUPPORT.value: "Поддержка",
    RoleCode.COURIER.value: "Курьер",
}


async def _roles(session: AsyncSession) -> dict[str, Role]:
    return {r.code: r for r in (await session.execute(select(Role))).scalars()}


@router.get("/staff")
async def staff_list(
    request: Request,
    error: str | None = None,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
):
    staff = list(
        (await session.execute(
            select(User)
            .options(selectinload(User.role))
            .join(Role, User.role_id == Role.id)
            .where(Role.code != RoleCode.CLIENT.value)
            .order_by(Role.code, User.name)
        )).scalars()
    )
    clients = (
        await session.execute(
            select(func.count(User.id)).join(Role, User.role_id == Role.id).where(Role.code == RoleCode.CLIENT.value)
        )
    ).scalar_one()
    messages = {
        "phone": "Укажите телефон",
        "exists": "Сотрудник с таким телефоном уже есть",
        "password": f"Пароль для входа в админку — от {MIN_PASSWORD_LENGTH} символов",
        "self": "Нельзя отключить самого себя",
    }
    return render(
        request, "admin/staff.html", admin, "/admin/staff",
        staff=staff, clients=clients, role_labels=ROLE_LABELS,
        admin_roles=ADMIN_ROLES, error=messages.get(error or ""),
    )


@router.post("/staff/new")
async def staff_create(
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    phone: str = Form(""),
    name: str = Form(""),
    role: str = Form(RoleCode.COURIER.value),
    password: str = Form(""),
):
    normalized = normalize_phone(phone)
    if len(normalized) < 8:
        return redirect("/admin/staff?error=phone")
    roles = await _roles(session)
    if role not in roles or role == RoleCode.CLIENT.value:
        raise HTTPException(status_code=422, detail="неизвестная роль")
    if role in ADMIN_ROLES and len(password) < MIN_PASSWORD_LENGTH:
        return redirect("/admin/staff?error=password")

    user = (await session.execute(select(User).where(User.phone == normalized))).scalar_one_or_none()
    if user is not None and user.role_id != roles[RoleCode.CLIENT.value].id:
        return redirect("/admin/staff?error=exists")
    if user is None:
        user = User(phone=normalized)
        session.add(user)
    # Гость, ставший сотрудником, сохраняет свою учётную запись — меняется роль.
    user.name = name.strip() or user.name
    user.role_id = roles[role].id
    user.is_active = True
    if password:
        user.password_hash = hash_password(password)
    await session.commit()
    return redirect("/admin/staff", "created")


@router.post("/staff/{user_id}/edit")
async def staff_edit(
    user_id: int,
    admin: User = Depends(get_admin_user),
    session: AsyncSession = Depends(get_session),
    name: str = Form(""),
    role: str = Form(...),
    password: str = Form(""),
    is_active: str | None = Form(None),
):
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="сотрудник не найден")
    roles = await _roles(session)
    if role not in roles or role == RoleCode.CLIENT.value:
        raise HTTPException(status_code=422, detail="неизвестная роль")
    if user.id == admin.id and (is_active is None or role not in ADMIN_ROLES):
        return redirect("/admin/staff?error=self")
    if password and len(password) < MIN_PASSWORD_LENGTH:
        return redirect("/admin/staff?error=password")

    user.name = name.strip() or user.name
    user.role_id = roles[role].id
    user.is_active = is_active is not None
    if password:
        user.password_hash = hash_password(password)
    await session.commit()
    return redirect("/admin/staff", "saved")
