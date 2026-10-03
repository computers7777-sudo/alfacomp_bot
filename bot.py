"""
Telegram-бот магазина: каталог с фото и ценами, inline-кнопки,
запрос разрешения на контакт, данные хранятся в Supabase.

Запуск:  python bot.py
"""
import asyncio
import logging
import os
import sys
import time
from html import escape

import httpx
from aiogram import Bot, Dispatcher, F, Router
from aiogram.client.default import DefaultBotProperties
from aiogram.enums import ParseMode
from aiogram.exceptions import TelegramBadRequest
from aiogram.filters import Command, CommandStart
from aiogram.types import (
    BotCommand,
    CallbackQuery,
    InlineKeyboardButton,
    KeyboardButton,
    Message,
    ReplyKeyboardMarkup,
    ReplyKeyboardRemove,
)
from aiogram.utils.keyboard import InlineKeyboardBuilder

# ════════════════════════════════════════════════════════════════
#  НАСТРОЙКИ — вставьте свои данные в три строки ниже
#  (на хостинге лучше задавать их через переменные окружения)
# ════════════════════════════════════════════════════════════════

# 1) ТОКЕН БОТА — получить у @BotFather в Telegram
BOT_TOKEN = os.getenv("BOT_TOKEN", "8977573836:AAFHi0ogLPMmm8cCb2Wv09KJpVToHkAw4R8")

# 2) SUPABASE_URL — Supabase → Project Settings → API → Project URL
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://hfmkamwoersircaijmhg.supabase.co")

# 3) SUPABASE ANON KEY — Supabase → Project Settings → API → anon / public key
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "sb_publishable_CWn2dM795G7fOiRiwpqdJw_rYb4C1kk")

# Необязательно: ваш Telegram ID (узнать у @userinfobot) — бот будет
# присылать вам уведомления о новых контактах и нажатиях «Купить».
ADMIN_CHAT_ID = int(os.getenv("ADMIN_CHAT_ID", "0") or 0)

# ── Данные магазина ─────────────────────────────────────────────
SHOP_NAME = "Alfa Comp"
CONTACT_PHONE = "+998883203333"
CONTACT_TG = "ALIBABO777"
CURRENCY = "$"
PAGE_SIZE = 8
CACHE_TTL = 300  # сек: как часто обновлять каталог из Supabase

# Порядок и значки категорий (новые категории добавятся в конец сами)
CATEGORY_EMOJI = {
    "Мониторы": "🖥",
    "Моноблоки": "💻",
    "Комплектующие": "🧩",
    "Мышки": "🖱",
    "Аксессуары": "🎧",
    "Колонки": "🔊",
    "Wi-Fi роутеры": "📡",
    "Deco": "📶",
    "Сеть": "🌐",
    "ИБП": "🔋",
    "Кронштейны": "🔩",
}

# ════════════════════════════════════════════════════════════════

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("shop-bot")
router = Router()


# ── Supabase (REST, без лишних зависимостей) ────────────────────
class Supabase:
    def __init__(self, url: str, key: str):
        self.base = url.rstrip("/") + "/rest/v1"
        headers = {"apikey": key}
        if key.startswith("eyJ"):  # старые ключи — JWT; новые sb_publishable_... без Bearer
            headers["Authorization"] = f"Bearer {key}"
        self.http = httpx.AsyncClient(headers=headers, timeout=15)

    async def products(self) -> list[dict]:
        r = await self.http.get(
            f"{self.base}/products",
            params={
                "select": "*",
                "in_stock": "eq.true",
                "order": "id.asc",
                "limit": "2000",
            },
        )
        r.raise_for_status()
        return r.json()

    async def rpc(self, fn: str, payload: dict) -> None:
        r = await self.http.post(f"{self.base}/rpc/{fn}", json=payload)
        r.raise_for_status()

    async def close(self):
        await self.http.aclose()


db: Supabase  # создаётся в main()


class Catalog:
    """Кэш каталога, чтобы не ходить в Supabase на каждое нажатие."""

    def __init__(self):
        self.items: list[dict] = []
        self.by_id: dict[int, dict] = {}
        self.ts = 0.0
        self.lock = asyncio.Lock()

    async def load(self):
        async with self.lock:
            if time.time() - self.ts < CACHE_TTL:
                return
            try:
                items = await db.products()
                self.items = items
                self.by_id = {p["id"]: p for p in items}
                self.ts = time.time()
            except Exception:
                log.exception("Не удалось загрузить каталог из Supabase")
                if not self.items:
                    raise
                self.ts = time.time() - CACHE_TTL + 30  # повтор через 30 сек

    async def categories(self) -> list[tuple[str, int]]:
        await self.load()
        counts: dict[str, int] = {}
        for p in self.items:
            counts[p["category"]] = counts.get(p["category"], 0) + 1
        order = list(CATEGORY_EMOJI)
        names = sorted(counts, key=lambda c: order.index(c) if c in order else len(order))
        return [(c, counts[c]) for c in names]

    async def in_category(self, cat: str) -> list[dict]:
        await self.load()
        return [p for p in self.items if p["category"] == cat]

    async def product(self, pid: int) -> dict | None:
        await self.load()
        return self.by_id.get(pid)


catalog = Catalog()


# ── Вспомогательное ─────────────────────────────────────────────
def fmt_price(value) -> str:
    value = float(value)
    s = f"{value:,.0f}" if value == int(value) else f"{value:,.2f}"
    return f"{CURRENCY}{s.replace(',', ' ')}"


def cat_title(cat: str) -> str:
    return f"{CATEGORY_EMOJI.get(cat, '📦')} {cat}"


def contacts_text() -> str:
    return (
        "📞 <b>Для покупки свяжитесь с нами:</b>\n"
        f"Телефон: {CONTACT_PHONE}\n"
        f"Telegram: @{CONTACT_TG}"
    )


def tg_button() -> InlineKeyboardButton:
    return InlineKeyboardButton(text="✈️ Написать в Telegram", url=f"https://t.me/{CONTACT_TG}")


async def menu_keyboard():
    kb = InlineKeyboardBuilder()
    for cat, n in await catalog.categories():
        kb.button(text=f"{cat_title(cat)} ({n})", callback_data=f"c:{cat}:0")
    kb.adjust(2)
    kb.row(
        InlineKeyboardButton(text="📞 Контакты", callback_data="contacts"),
        InlineKeyboardButton(text="📱 Оставить номер", callback_data="askcontact"),
    )
    return kb.as_markup()


async def replace(cb: CallbackQuery, text: str, kb, photo: str | None = None):
    """Обновляет сообщение: редактирует, если можно, иначе удаляет и шлёт новое."""
    chat_id = cb.from_user.id
    msg = cb.message
    if photo is None and isinstance(msg, Message) and not msg.photo:
        try:
            await msg.edit_text(text, reply_markup=kb)
            return
        except TelegramBadRequest as e:
            if "not modified" in str(e):
                return
    if msg is not None:
        try:
            await cb.bot.delete_message(chat_id, msg.message_id)
        except TelegramBadRequest:
            pass
    if photo:
        try:
            await cb.bot.send_photo(chat_id, photo, caption=text, reply_markup=kb)
            return
        except TelegramBadRequest:
            log.warning("Не удалось отправить фото %s — показываю без фото", photo)
    await cb.bot.send_message(chat_id, text, reply_markup=kb)


async def notify_admin(bot: Bot, text: str):
    if not ADMIN_CHAT_ID:
        return
    try:
        await bot.send_message(ADMIN_CHAT_ID, text)
    except Exception:
        log.exception("Не удалось отправить уведомление админу")


def user_link(u) -> str:
    handle = f" (@{u.username})" if u.username else ""
    return f'<a href="tg://user?id={u.id}">{escape(u.full_name)}</a>{handle}'


CONSENT_TEXT = (
    "📱 <b>Разрешите доступ к вашему контакту?</b>\n\n"
    "Так мы сможем связаться с вами по покупке. Номер используется только "
    "для связи по заказам и не передаётся третьим лицам. Это необязательно — "
    "можно пропустить. Удалить свои данные можно командой /forget."
)


def consent_keyboard() -> ReplyKeyboardMarkup:
    return ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="✅ Разрешить и поделиться номером", request_contact=True)],
            [KeyboardButton(text="Пропустить")],
        ],
        resize_keyboard=True,
        one_time_keyboard=True,
    )


async def send_menu(bot: Bot, chat_id: int):
    try:
        kb = await menu_keyboard()
    except Exception:
        await bot.send_message(chat_id, "⚠️ Каталог временно недоступен. Попробуйте чуть позже.")
        return
    await bot.send_message(chat_id, "🛍 <b>Выберите категорию:</b>", reply_markup=kb)


# ── Команды и согласие на контакт ───────────────────────────────
@router.message(CommandStart())
async def cmd_start(m: Message):
    await m.answer(f"👋 Здравствуйте, {escape(m.from_user.first_name)}!\nДобро пожаловать в <b>{SHOP_NAME}</b>.")
    await m.answer(CONSENT_TEXT, reply_markup=consent_keyboard())


@router.message(Command("menu"))
async def cmd_menu(m: Message):
    await send_menu(m.bot, m.chat.id)


@router.message(Command("contacts"))
async def cmd_contacts(m: Message):
    kb = InlineKeyboardBuilder()
    kb.row(tg_button())
    await m.answer(contacts_text(), reply_markup=kb.as_markup())


@router.message(Command("contact"))
async def cmd_contact(m: Message):
    await m.answer(CONSENT_TEXT, reply_markup=consent_keyboard())


@router.message(Command("forget"))
async def cmd_forget(m: Message):
    try:
        await db.rpc("forget_customer", {"p_telegram_id": m.from_user.id})
        await m.answer("🗑 Ваши данные удалены.", reply_markup=ReplyKeyboardRemove())
    except Exception:
        log.exception("forget_customer")
        await m.answer("⚠️ Не удалось удалить данные, попробуйте позже.")


@router.message(F.text == "Пропустить")
async def skip_contact(m: Message):
    await m.answer("Хорошо, без проблем 👌", reply_markup=ReplyKeyboardRemove())
    await send_menu(m.bot, m.chat.id)


@router.message(F.contact)
async def got_contact(m: Message):
    c = m.contact
    if c.user_id != m.from_user.id:  # защита: только свой номер
        await m.answer("Пожалуйста, отправьте именно свой контакт кнопкой ниже.", reply_markup=consent_keyboard())
        return
    try:
        await db.rpc(
            "register_customer",
            {
                "p_telegram_id": m.from_user.id,
                "p_first_name": m.from_user.first_name,
                "p_username": m.from_user.username,
                "p_phone": c.phone_number,
                "p_consent": True,
            },
        )
    except Exception:
        log.exception("register_customer")
    await m.answer("✅ Спасибо! Контакт получен.", reply_markup=ReplyKeyboardRemove())
    await notify_admin(m.bot, f"📱 Новый контакт: {user_link(m.from_user)}\nТелефон: {escape(c.phone_number)}")
    await send_menu(m.bot, m.chat.id)


# ── Inline-кнопки ───────────────────────────────────────────────
@router.callback_query(F.data == "menu")
async def cb_menu(cb: CallbackQuery):
    await cb.answer()
    try:
        await replace(cb, "🛍 <b>Выберите категорию:</b>", await menu_keyboard())
    except Exception:
        await replace(cb, "⚠️ Каталог временно недоступен. Попробуйте чуть позже.", None)


@router.callback_query(F.data == "contacts")
async def cb_contacts(cb: CallbackQuery):
    await cb.answer()
    kb = InlineKeyboardBuilder()
    kb.row(tg_button())
    kb.row(InlineKeyboardButton(text="🏠 Меню", callback_data="menu"))
    await replace(cb, contacts_text(), kb.as_markup())


@router.callback_query(F.data == "askcontact")
async def cb_askcontact(cb: CallbackQuery):
    await cb.answer()
    await cb.bot.send_message(cb.from_user.id, CONSENT_TEXT, reply_markup=consent_keyboard())


@router.callback_query(F.data.startswith("c:"))
async def cb_category(cb: CallbackQuery):
    await cb.answer()
    _, cat, page_s = cb.data.split(":", 2)
    page = int(page_s)
    items = await catalog.in_category(cat)
    if not items:
        await replace(cb, "В этой категории пока пусто.", InlineKeyboardBuilder().button(text="🏠 Меню", callback_data="menu").as_markup())
        return
    pages = (len(items) + PAGE_SIZE - 1) // PAGE_SIZE
    page = max(0, min(page, pages - 1))

    kb = InlineKeyboardBuilder()
    for p in items[page * PAGE_SIZE:(page + 1) * PAGE_SIZE]:
        kb.row(InlineKeyboardButton(text=f"{p['name'][:42]} — {fmt_price(p['price'])}", callback_data=f"p:{p['id']}:{page}"))
    if pages > 1:
        nav = []
        if page > 0:
            nav.append(InlineKeyboardButton(text="◀️", callback_data=f"c:{cat}:{page - 1}"))
        nav.append(InlineKeyboardButton(text=f"{page + 1}/{pages}", callback_data="noop"))
        if page < pages - 1:
            nav.append(InlineKeyboardButton(text="▶️", callback_data=f"c:{cat}:{page + 1}"))
        kb.row(*nav)
    kb.row(InlineKeyboardButton(text="🏠 Меню", callback_data="menu"))
    await replace(cb, f"<b>{cat_title(cat)}</b>\nТоваров: {len(items)}. Выберите:", kb.as_markup())


@router.callback_query(F.data == "noop")
async def cb_noop(cb: CallbackQuery):
    await cb.answer()


def product_text(p: dict) -> str:
    lines = [f"<b>{escape(p['name'])}</b>"]
    if p.get("brand"):
        lines.append(f"Бренд: {escape(p['brand'])}")
    lines.append(f"Категория: {escape(p['category'])}")
    lines.append(f"\n💰 Цена: <b>{fmt_price(p['price'])}</b>")
    lines.append("✅ В наличии" if p.get("in_stock", True) else "❌ Нет в наличии")
    return "\n".join(lines)


@router.callback_query(F.data.startswith("p:"))
async def cb_product(cb: CallbackQuery):
    await cb.answer()
    _, pid_s, page_s = cb.data.split(":")
    p = await catalog.product(int(pid_s))
    if not p:
        await replace(cb, "Этот товар больше недоступен.", InlineKeyboardBuilder().button(text="🏠 Меню", callback_data="menu").as_markup())
        return
    kb = InlineKeyboardBuilder()
    kb.row(InlineKeyboardButton(text="🛒 Купить", callback_data=f"buy:{p['id']}"))
    kb.row(
        InlineKeyboardButton(text="⬅️ К списку", callback_data=f"c:{p['category']}:{page_s}"),
        InlineKeyboardButton(text="🏠 Меню", callback_data="menu"),
    )
    await replace(cb, product_text(p), kb.as_markup(), photo=p.get("photo_url"))


@router.callback_query(F.data.startswith("buy:"))
async def cb_buy(cb: CallbackQuery):
    await cb.answer()
    p = await catalog.product(int(cb.data.split(":")[1]))
    if not p:
        return
    kb = InlineKeyboardBuilder()
    kb.row(tg_button())
    kb.row(
        InlineKeyboardButton(text="⬅️ К товару", callback_data=f"p:{p['id']}:0"),
        InlineKeyboardButton(text="🏠 Меню", callback_data="menu"),
    )
    text = f"🛒 <b>{escape(p['name'])}</b> — {fmt_price(p['price'])}\n\n{contacts_text()}\n\nНазовите товар при обращении 😊"
    await replace(cb, text, kb.as_markup())
    await notify_admin(
        cb.bot,
        f"🛒 Интерес к товару: <b>{escape(p['name'])}</b> (ID {p['id']}, {fmt_price(p['price'])})\nОт: {user_link(cb.from_user)}",
    )


# ── Запуск ──────────────────────────────────────────────────────
async def main():
    global db
    if any("ВСТАВЬТЕ" in v for v in (BOT_TOKEN, SUPABASE_URL, SUPABASE_ANON_KEY)):
        sys.exit("❌ Впишите BOT_TOKEN, SUPABASE_URL и SUPABASE_ANON_KEY в начале bot.py (или в переменные окружения).")

    db = Supabase(SUPABASE_URL, SUPABASE_ANON_KEY)
    bot = Bot(BOT_TOKEN, default=DefaultBotProperties(parse_mode=ParseMode.HTML))
    dp = Dispatcher()
    dp.include_router(router)

    await bot.set_my_commands(
        [
            BotCommand(command="menu", description="Каталог"),
            BotCommand(command="contacts", description="Контакты для покупки"),
            BotCommand(command="contact", description="Поделиться номером"),
            BotCommand(command="forget", description="Удалить мои данные"),
        ]
    )
    try:
        await dp.start_polling(bot)
    finally:
        await db.close()
        await bot.session.close()


if __name__ == "__main__":
    asyncio.run(main())
