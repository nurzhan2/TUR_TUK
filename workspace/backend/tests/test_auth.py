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
    assert len(fake_sms.sent[phone]) == 4


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


async def test_new_send_code_invalidates_previous(client, fake_sms):
    phone = _phone("006")
    await client.post("/auth/send-code", json={"phone": phone})
    old_code = fake_sms.sent[phone]

    await client.post("/auth/send-code", json={"phone": phone})

    resp = await client.post("/auth/verify-code", json={"phone": phone, "code": old_code})
    # шанс ложного PASS — 1/10000 (новый код случайно совпал со старым)
    assert resp.status_code == 400


async def test_verify_code_missing_fields_is_422(client):
    resp = await client.post("/auth/verify-code", json={"phone": _phone("007")})
    assert resp.status_code == 422


async def test_verify_code_get_without_body_is_422(client):
    resp = await client.get("/auth/verify-code")
    assert resp.status_code == 422
