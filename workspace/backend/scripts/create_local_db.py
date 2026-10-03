"""Локальная разработка без Docker: создать роль и базы проекта в уже
установленном PostgreSQL (суперпользователь postgres).

Базы создаются явно в UTF-8 из template0: на Windows кодировка по умолчанию
берётся из локали (WIN1251), и символ «₽» в данных миграций в неё не влезает.

    python scripts/create_local_db.py [--admin-url postgresql://postgres:postgres@localhost:5432/postgres] [--recreate]
"""

import argparse
import asyncio

import asyncpg

DATABASES = ("turtuk", "turtuk_test")


async def main(admin_url: str, recreate: bool) -> None:
    conn = await asyncpg.connect(admin_url)
    try:
        if not await conn.fetchval("select 1 from pg_roles where rolname = 'tur_tuk'"):
            await conn.execute("create role tur_tuk login password 'tur_tuk'")
        for db in DATABASES:
            exists = await conn.fetchval("select 1 from pg_database where datname = $1", db)
            if exists and recreate:
                await conn.execute(f'drop database "{db}" with (force)')
                exists = False
            if not exists:
                # ICU, а не libc-локаль «C»: в «C» функция lower() не трогает
                # кириллицу, и поиск отеля по названию без учёта регистра ломается.
                await conn.execute(
                    f'create database "{db}" owner tur_tuk encoding \'UTF8\' '
                    f"locale_provider icu icu_locale 'und' locale 'C' template template0"
                )
        print("ok: role tur_tuk, databases " + ", ".join(DATABASES))
    finally:
        await conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--admin-url", default="postgresql://postgres:postgres@localhost:5432/postgres")
    parser.add_argument("--recreate", action="store_true")
    args = parser.parse_args()
    asyncio.run(main(args.admin_url, args.recreate))
