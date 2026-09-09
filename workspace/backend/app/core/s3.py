from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from aiobotocore.session import get_session

from app.core.config import get_settings


@asynccontextmanager
async def s3_client() -> AsyncIterator:
    """Async S3-compatible client, configured entirely from env vars.

    Credentials and endpoint never come from anywhere else — the storage
    provider is not chosen yet (see stack notes), so nothing here may assume
    a specific one (AWS vs Yandex vs Selectel etc).
    """
    settings = get_settings()
    session = get_session()
    async with session.create_client(
        "s3",
        endpoint_url=settings.s3_endpoint_url,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key_id,
        aws_secret_access_key=settings.s3_secret_access_key,
    ) as client:
        yield client
