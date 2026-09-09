"""chat websocket bot responses

Revision ID: 53fad0634450
Revises: 6c9f1a3e7b21
Create Date: 2026-08-29 23:39:32.982574

Чат-бот отвечает от своего лица, а не от лица реального пользователя, поэтому
`chat_messages.sender_id` становится nullable: NULL = сообщение бота.
Заводить отдельную роль/пользователя-заглушку под бота не стали — это не
роль из брифа (раздел 14), а системная запись, которая в RBAC не участвует.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '53fad0634450'
down_revision: Union[str, None] = '6c9f1a3e7b21'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

bot_responses_table = sa.table(
    "bot_responses",
    sa.column("keywords", sa.String),
    sa.column("answer", sa.Text),
)

# keywords — через запятую, нижний регистр, сравнение по вхождению подстроки.
SEED = [
    {
        "keywords": "минимальная сумма,минимальный заказ,от какой суммы,сколько минимум",
        "answer": "Минимальная сумма заказа — 3000 ₽.",
    },
    {
        "keywords": "оплата,как оплатить,способ оплаты,картой,сбп",
        "answer": "Оплата принимается только онлайн: банковской картой или через СБП, в рублях. Наличные не принимаются.",
    },
    {
        "keywords": "доставка,когда привезут,время доставки,сколько ждать",
        "answer": "Курьер доставит заказ на рецепцию вашего отеля. Отследить статус можно в приложении в разделе «Мои заказы».",
    },
    {
        "keywords": "как получить заказ,забрать заказ,получение заказа,рецепция",
        "answer": "Заказ можно забрать на рецепции отеля, назвав номер заказа или последние 4 цифры номера телефона.",
    },
    {
        "keywords": "зона доставки,куда доставляете,какие отели,список отелей",
        "answer": "Мы доставляем только по отелям и гостиницам Кемера из списка в приложении. Если вашего отеля нет в списке — уточните у оператора.",
    },
    {
        "keywords": "статус заказа,где мой заказ,отследить заказ",
        "answer": "Статус заказа отображается в разделе «Мои заказы»: принят, на сборке, доставляется, доставлен.",
    },
    {
        "keywords": "промокод,скидка",
        "answer": "Промокод можно ввести при оформлении заказа в корзине.",
    },
    {
        "keywords": "язык,на английском,на турецком,change language",
        "answer": "Язык приложения можно поменять в настройках профиля: русский, английский или турецкий.",
    },
]


def upgrade() -> None:
    op.alter_column("chat_messages", "sender_id", existing_type=sa.Integer(), nullable=True)

    op.create_table(
        "bot_responses",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("keywords", sa.String(length=500), nullable=False),
        sa.Column("answer", sa.Text(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.bulk_insert(bot_responses_table, SEED)


def downgrade() -> None:
    op.drop_table("bot_responses")
    op.alter_column("chat_messages", "sender_id", existing_type=sa.Integer(), nullable=False)
