from __future__ import annotations

import abc

import httpx

from app.core.config import Settings, get_settings


class SmsSendError(RuntimeError):
    """Провайдер отказал или не настроен — код клиенту не ушёл."""


class SmsProvider(abc.ABC):
    @abc.abstractmethod
    async def send(self, phone: str, code: str) -> None: ...


class SmsRuProvider(SmsProvider):
    """https://sms.ru/api/send — плоское GET API, отдельный SDK не нужен."""

    def __init__(self, api_id: str) -> None:
        self._api_id = api_id

    async def send(self, phone: str, code: str) -> None:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                "https://sms.ru/sms/send",
                params={
                    "api_id": self._api_id,
                    "to": phone,
                    "msg": f"TUR TUK: код подтверждения {code}",
                    "json": 1,
                },
            )
        resp.raise_for_status()
        data = resp.json()
        if str(data.get("status")) != "OK":
            raise SmsSendError(f"sms.ru: {data.get('status_text') or data}")


class TwilioProvider(SmsProvider):
    """REST API Twilio через httpx с Basic Auth — без пакета twilio."""

    def __init__(self, account_sid: str, auth_token: str, from_number: str) -> None:
        self._account_sid = account_sid
        self._auth_token = auth_token
        self._from_number = from_number

    async def send(self, phone: str, code: str) -> None:
        url = f"https://api.twilio.com/2010-04-01/Accounts/{self._account_sid}/Messages.json"
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                url,
                auth=(self._account_sid, self._auth_token),
                data={
                    "To": phone,
                    "From": self._from_number,
                    "Body": f"TUR TUK: код подтверждения {code}",
                },
            )
        if resp.status_code >= 300:
            raise SmsSendError(f"twilio: {resp.status_code} {resp.text}")


def get_sms_provider(settings: Settings | None = None) -> SmsProvider:
    settings = settings or get_settings()
    if settings.sms_provider == "twilio":
        if not (settings.twilio_account_sid and settings.twilio_auth_token and settings.twilio_from_number):
            raise SmsSendError(
                "Twilio выбран, но не настроен: нужны TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN/TWILIO_FROM_NUMBER"
            )
        return TwilioProvider(settings.twilio_account_sid, settings.twilio_auth_token, settings.twilio_from_number)

    if settings.sms_provider != "sms_ru":
        raise SmsSendError(f"неизвестный SMS_PROVIDER={settings.sms_provider!r}")
    if not settings.sms_ru_api_id:
        raise SmsSendError("SMS.ru выбран, но не настроен: нужен SMS_RU_API_ID")
    return SmsRuProvider(settings.sms_ru_api_id)
