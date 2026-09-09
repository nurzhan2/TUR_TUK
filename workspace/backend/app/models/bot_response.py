from sqlalchemy import String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BotResponse(Base):
    """FAQ чат-бота: `keywords` — ключевые слова через запятую (нижний
    регистр), совпадение проверяется по вхождению подстроки в текст
    сообщения клиента.
    """

    __tablename__ = "bot_responses"

    id: Mapped[int] = mapped_column(primary_key=True)
    keywords: Mapped[str] = mapped_column(String(500), nullable=False)
    answer: Mapped[str] = mapped_column(Text, nullable=False)
