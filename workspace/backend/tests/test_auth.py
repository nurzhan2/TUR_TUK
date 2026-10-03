from app.core.config import get_settings
from app.core.security import decode_token

TEST_PHONE_PREFIX = "+70000"


def _phone(suffix: str) -> str:
    return f"{TEST_PHONE_PREFIX}{suffix}"


async def test_send_code_ok(client, fake_sms):
    phone = _phone("001")
    resp = await client.post("/auth/send-code", json={"phone": phone})
    assert resp.status_code == 200
    assert resp.json()["expires_in"] == 5 * 60
    assert phone in fake_sms.sent
    assert fake_sms.sent[phone].isdigit()
    assert len(fake_sms.sent[phone]) == 6


async def test_send_code_invalid_phone_is_422(client, fake_sms):
    resp = await client.post("/auth/send-code", json={"phone": "not-a-phone"})
    assert resp.status_code == 422
    assert not fake_sms.sent


async def test_verify_code_issues_tokens(client, fake_sms):
    phone = _phone("002")
    await client.post("/auth/send-code", json={"phone": phone})
    code = fake_sms.sent[phone]

    resp = await client.post("/auth/verify-code", json={"phone": phone, "code": code})
    assert resp.status_code == 200

    body = resp.json()
    assert body["token_type"] == "bearer"
    access_payload = decode_token(body["access_token"], expected_type="access")
    refresh_payload = decode_token(body["refresh_token"], expected_type="refresh")
    assert access_payload["sub"] == refresh_payload["sub"]


async def test_verify_code_wrong_code_is_400(client, fake_sms):
    phone = _phone("003")
    await client.post("/auth/send-code", json={"phone": phone})

    resp = await client.post("/auth/verify-code", json={"phone": phone, "code": "0000"})
    assert resp.status_code == 400


async def test_verify_code_without_send_is_400(client):
    resp = await client.post(
        "/auth/verify-code", json={"phone": _phone("004"), "code": "1234"}
    )
    assert resp.status_code == 400


async def test_verify_code_cannot_be_reused(client, fake_sms):
    phone = _phone("005")
    await client.post("/auth/send-code", json={"phone": phone})
    code = fake_sms.sent[phone]

    first = await client.post("/auth/verify-code", json={"phone": phone, "code": code})
    assert first.status_code == 200

    second = await client.post("/auth/verify-code", json={"phone": phone, "code": code})
    assert second.status_code == 400


async def test_new_send_code_invalidates_previous(client, fake_sms, monkeypatch):
    # Пауза между отправками здесь мешает: проверяем именно гашение кода.
    monkeypatch.setattr(get_settings(), "sms_resend_seconds", 0)
    phone = _phone("006")
    await client.post("/auth/send-code", json={"phone": phone})
    old_code = fake_sms.sent[phone]

    await client.post("/auth/send-code", json={"phone": phone})

    resp = await client.post("/auth/verify-code", json={"phone": phone, "code": old_code})
    # шанс ложного PASS — 1/10^6 (новый код случайно совпал со старым)
    assert resp.status_code == 400


async def test_resend_too_soon_is_429(client, fake_sms):
    phone = _phone("007")
    assert (await client.post("/auth/send-code", json={"phone": phone})).status_code == 200
    again = await client.post("/auth/send-code", json={"phone": phone})
    assert again.status_code == 429
    assert int(again.headers["retry-after"]) > 0


async def test_send_limit_per_phone_per_hour(client, fake_sms, monkeypatch):
    monkeypatch.setattr(get_settings(), "sms_resend_seconds", 0)
    monkeypatch.setattr(get_settings(), "sms_max_per_phone_hour", 3)
    phone = _phone("008")
    codes = [(await client.post("/auth/send-code", json={"phone": phone})).status_code for _ in range(4)]
    assert codes == [200, 200, 200, 429]


async def test_wrong_code_attempts_burn_the_code(client, fake_sms):
    phone = _phone("009")
    await client.post("/auth/send-code", json={"phone": phone})
    code = fake_sms.sent[phone]
    wrong = "000000" if code != "000000" else "111111"

    statuses = [
        (await client.post("/auth/verify-code", json={"phone": phone, "code": wrong})).status_code
        for _ in range(5)
    ]
    assert statuses == [400, 400, 400, 400, 429]
    # Даже верный код после лимита уже не работает — перебор бессмыслен.
    after = await client.post("/auth/verify-code", json={"phone": phone, "code": code})
    assert after.status_code == 400


async def test_me_returns_profile_and_fcm_token_saved(client, fake_sms):
    phone = _phone("010")
    await client.post("/auth/send-code", json={"phone": phone})
    tokens = (await client.post(
        "/auth/verify-code", json={"phone": phone, "code": fake_sms.sent[phone]}
    )).json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    me = await client.get("/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["phone"] == phone

    saved = await client.post("/auth/fcm-token", json={"token": "device-token-abcdef"}, headers=headers)
    assert saved.status_code == 204
    assert (await client.get("/auth/me")).status_code == 401


async def test_delete_account_wipes_personal_data_and_token(client, fake_sms, monkeypatch):
    monkeypatch.setattr(get_settings(), "sms_resend_seconds", 0)
    phone = _phone("011")
    await client.post("/auth/send-code", json={"phone": phone})
    tokens = (await client.post(
        "/auth/verify-code", json={"phone": phone, "code": fake_sms.sent[phone]}
    )).json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    assert (await client.delete("/auth/me", headers=headers)).status_code == 204
    # Старый токен больше не действует.
    assert (await client.get("/auth/me", headers=headers)).status_code == 401

    # Тот же номер регистрируется заново — как новый гость.
    await client.post("/auth/send-code", json={"phone": phone})
    again = await client.post("/auth/verify-code", json={"phone": phone, "code": fake_sms.sent[phone]})
    assert again.status_code == 200
    new_headers = {"Authorization": f"Bearer {again.json()['access_token']}"}
    me = (await client.get("/auth/me", headers=new_headers)).json()
    assert me["phone"] == phone
    assert me["name"] is None


async def test_verify_code_missing_fields_is_422(client):
    resp = await client.post("/auth/verify-code", json={"phone": _phone("007")})
    assert resp.status_code == 422


async def test_verify_code_get_without_body_is_422(client):
    resp = await client.get("/auth/verify-code")
    assert resp.status_code == 422
