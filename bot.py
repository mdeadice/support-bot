import asyncio
import os
import logging
import aiosqlite
import time
from datetime import datetime

from dotenv import load_dotenv
load_dotenv()

from aiogram import Bot, Dispatcher, F
from aiogram.client.default import DefaultBotProperties
from aiogram.filters import Command, StateFilter
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.types import (
    Message,
    CallbackQuery,
    InlineKeyboardMarkup,
    InlineKeyboardButton,
    LinkPreviewOptions,
    InputMediaPhoto,
    InputMediaVideo,
    InputMediaDocument,
    InputMediaAudio
)
from aiogram.exceptions import TelegramBadRequest, TelegramForbiddenError, TelegramRetryAfter

# === НАСТРОЙКИ ===

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(name)s - %(message)s")

BOT_TOKEN = os.getenv("BOT_TOKEN", "")
SUPPORT_CHAT_ID = int(os.getenv("SUPPORT_CHAT_ID", "0"))
DB_PATH = os.getenv("DB_PATH", "bot.db")

admin_ids_str = os.getenv("ADMIN_IDS", "")
ADMIN_IDS = {int(x.strip()) for x in admin_ids_str.split(",") if x.strip().isdigit()}

# Настройки Антиспама
FLOOD_RATE_LIMIT = 4.0

if not BOT_TOKEN or not SUPPORT_CHAT_ID:
    raise RuntimeError("Нужно задать BOT_TOKEN и SUPPORT_CHAT_ID")

bot = Bot(token=BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
dp = Dispatcher(storage=MemoryStorage())

# === БАЗА ДАННЫХ ===

async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("CREATE TABLE IF NOT EXISTS tickets (id INTEGER PRIMARY KEY, user_id INTEGER, username TEXT, topic_id INTEGER, status TEXT, created_at TEXT, closed_at TEXT)")
        await db.execute("CREATE TABLE IF NOT EXISTS faq (id INTEGER PRIMARY KEY, question TEXT, answer TEXT, created_at TEXT, updated_at TEXT)")
        try: await db.execute("ALTER TABLE faq ADD COLUMN parse_mode TEXT DEFAULT 'HTML'")
        except Exception: pass
        try: await db.execute("ALTER TABLE faq ADD COLUMN sort_order INTEGER DEFAULT 0")
        except Exception: pass
        await db.execute("CREATE TABLE IF NOT EXISTS faq_media (id INTEGER PRIMARY KEY, faq_id INTEGER, file_id TEXT, type TEXT, created_at TEXT, FOREIGN KEY (faq_id) REFERENCES faq(id) ON DELETE CASCADE)")
        await db.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
        await db.execute("CREATE TABLE IF NOT EXISTS banned_users (user_id INTEGER PRIMARY KEY, reason TEXT, admin_id INTEGER, banned_at TEXT)")
        await db.commit()

async def get_setting(key: str) -> str | None:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT value FROM settings WHERE key = ?", (key,)) as cursor:
            row = await cursor.fetchone()
            return row['value'] if row else None

async def set_setting(key: str, value: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", (key, value))
        await db.commit()

# === БАН СИСТЕМА ===
async def ban_user_db(user_id: int, reason: str, admin_id: int):
    now = datetime.utcnow().isoformat()
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("INSERT OR REPLACE INTO banned_users (user_id, reason, admin_id, banned_at) VALUES (?, ?, ?, ?)", (user_id, reason, admin_id, now))
        await db.commit()

async def unban_user_db(user_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("DELETE FROM banned_users WHERE user_id=?", (user_id,))
        await db.commit()

async def get_banned_list_db():
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT user_id FROM banned_users") as cursor:
            rows = await cursor.fetchall()
            return {row[0] for row in rows}

async def get_ban_message_text():
    contact = await get_setting('ban_contact')
    msg = "<b>⛔ Вы были заблокированы администратором.</b>"
    if contact: msg += f"\n\nДля подачи жалобы на администратора обратитесь к: {contact}"
    else: msg += "\n\nДоступ к боту ограничен."
    return msg

# === TICKETS DB ===
async def create_ticket(user_id: int, username: str | None, topic_id: int) -> int:
    now = datetime.utcnow().isoformat()
    async with aiosqlite.connect(DB_PATH) as db:
        cursor = await db.execute("INSERT INTO tickets (user_id, username, topic_id, status, created_at) VALUES (?, ?, ?, 'open', ?)", (user_id, username, topic_id, now))
        await db.commit()
        return cursor.lastrowid

async def close_ticket_by_topic_db(topic_id: int):
    now = datetime.utcnow().isoformat()
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("UPDATE tickets SET status='closed', closed_at=? WHERE topic_id=? AND status='open'", (now, topic_id))
        await db.commit()

async def get_ticket_info(topic_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT id, user_id, status FROM tickets WHERE topic_id=? ORDER BY id DESC LIMIT 1", (topic_id,)) as cursor:
            return await cursor.fetchone()

async def get_last_ticket_by_user(user_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT id, topic_id FROM tickets WHERE user_id=? ORDER BY id DESC LIMIT 1", (user_id,)) as cursor:
            return await cursor.fetchone()

async def get_active_tickets_db():
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT user_id, topic_id FROM tickets WHERE status = 'open'") as cursor:
            return await cursor.fetchall()

# === FAQ DB ===
async def get_faq_list():
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT id, question, sort_order FROM faq ORDER BY sort_order ASC, id ASC") as cursor:
            return await cursor.fetchall()

async def get_faq_item(faq_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT * FROM faq WHERE id=?", (faq_id,)) as cursor:
            faq = await cursor.fetchone()
            if not faq: return None, []
        async with db.execute("SELECT * FROM faq_media WHERE faq_id=? ORDER BY id ASC", (faq_id,)) as cursor:
            media = await cursor.fetchall()
            return faq, media

async def create_faq(question_html: str, answer_html: str) -> int:
    now = datetime.utcnow().isoformat()
    async with aiosqlite.connect(DB_PATH) as db:
        async with db.execute("SELECT MAX(sort_order) as max_order FROM faq") as cursor:
            row = await cursor.fetchone()
            next_order = (row[0] or 0) + 1
        cursor = await db.execute("INSERT INTO faq (question, answer, sort_order, created_at) VALUES (?, ?, ?, ?)", (question_html, answer_html, next_order, now))
        faq_id = cursor.lastrowid
        await db.execute("DELETE FROM faq_media WHERE faq_id=?", (faq_id,))
        await db.commit()
        return faq_id

async def update_faq(faq_id: int, question: str = None, answer: str = None):
    now = datetime.utcnow().isoformat()
    async with aiosqlite.connect(DB_PATH) as db:
        if question: await db.execute("UPDATE faq SET question=?, updated_at=? WHERE id=?", (question, now, faq_id))
        if answer: await db.execute("UPDATE faq SET answer=?, updated_at=? WHERE id=?", (answer, now, faq_id))
        await db.commit()

async def delete_faq(faq_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("DELETE FROM faq_media WHERE faq_id=?", (faq_id,))
        await db.execute("DELETE FROM faq WHERE id=?", (faq_id,))
        await db.commit()

async def add_faq_media(faq_id: int, file_id: str, media_type: str):
    now = datetime.utcnow().isoformat()
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("DELETE FROM faq_media WHERE faq_id=?", (faq_id,))
        await db.execute("INSERT INTO faq_media (faq_id, file_id, type, created_at) VALUES (?, ?, ?, ?)", (faq_id, file_id, media_type, now))
        await db.commit()

async def clear_faq_media(faq_id: int):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("DELETE FROM faq_media WHERE faq_id=?", (faq_id,))
        await db.commit()

# === СОРТИРОВКА FAQ ===
async def move_faq(faq_id: int, direction: str):
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        async with db.execute("SELECT id, sort_order FROM faq WHERE id=?", (faq_id,)) as cursor:
            current = await cursor.fetchone()
            if not current: return
        if direction == "up":
            query = "SELECT id, sort_order FROM faq WHERE sort_order < ? ORDER BY sort_order DESC LIMIT 1"
        else:
            query = "SELECT id, sort_order FROM faq WHERE sort_order > ? ORDER BY sort_order ASC LIMIT 1"
        async with db.execute(query, (current['sort_order'],)) as cursor:
            neighbor = await cursor.fetchone()
        if neighbor:
            await db.execute("UPDATE faq SET sort_order=? WHERE id=?", (neighbor['sort_order'], current['id']))
            await db.execute("UPDATE faq SET sort_order=? WHERE id=?", (current['sort_order'], neighbor['id']))
            await db.commit()

async def reindex_faq_sort():
    async with aiosqlite.connect(DB_PATH) as db:
        rows = await db.execute_fetchall("SELECT id FROM faq ORDER BY sort_order ASC, id ASC")
        for index, row in enumerate(rows, start=1):
            await db.execute("UPDATE faq SET sort_order=? WHERE id=?", (index, row[0]))
        await db.commit()

# === ПАМЯТЬ ===
user_states: dict[int, dict] = {}
topic_users: dict[int, int] = {}
user_topics: dict[int, int] = {}
user_to_topic_from_operator: dict[int, int] = {}
topic_to_user_from_operator: dict[int, int] = {}
user_to_topic_from_user: dict[int, int] = {}
topic_to_user_from_user: dict[int, int] = {}

BANNED_USERS_CACHE: set[int] = set()
FLOOD_CACHE: dict[int, dict] = {}
ALBUM_CACHE: dict[str, dict] = {} # {media_group_id: {messages: [], task: Task}}

# === FSM ===
class AdminStates(StatesGroup):
    add_question = State(); add_answer = State(); add_media = State()
    edit_question = State(); edit_answer = State(); edit_media = State()
    set_panel_url = State(); edit_main_menu_text = State(); edit_main_menu_photo = State()
    set_ban_contact = State()

# === КЛАВИАТУРЫ ===
def admin_main_keyboard():
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="✏️ Ред. меню", callback_data="admin_edit_main_menu")],
        [InlineKeyboardButton(text="🔗 Панель", callback_data="admin_set_panel")],
        [InlineKeyboardButton(text="📋 FAQ", callback_data="admin_manage_faq")],
        [InlineKeyboardButton(text="👤 Меню юзера", callback_data="admin_show_user_menu")]
    ])
def admin_cancel_keyboard(back_location: str = "admin_main"):
    return InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="❌ Отмена", callback_data=f"admin_cancel_to_{back_location}")]])
async def faq_main_keyboard():
    rows = await get_faq_list()
    kb = [[InlineKeyboardButton(text=row["question"][:37] + "..." if len(row["question"]) > 40 else row["question"], callback_data=f"faq_q_{row['id']}")] for row in rows]
    kb.append([InlineKeyboardButton(text="🙋‍♂️ Нет моего вопроса", callback_data="faq_no_answer")])
    kb.append([InlineKeyboardButton(text="⬅ Вернуться в меню", callback_data="faq_back_to_menu")])
    return InlineKeyboardMarkup(inline_keyboard=kb)
def faq_back_keyboard():
    return InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="⬅ Назад", callback_data="faq_back")]])
def admin_faq_keyboard():
    return InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="➕ Добавить", callback_data="admin_add_faq")],[InlineKeyboardButton(text="✏️ Список", callback_data="admin_manage_faq_list")],[InlineKeyboardButton(text="⬅ Назад", callback_data="admin_cancel_to_admin_main")]])
async def admin_manage_faq_list_keyboard():
    rows = await get_faq_list()
    kb_rows = [[InlineKeyboardButton(text=row["question"][:37] + "..." if len(row["question"]) > 40 else row["question"], callback_data=f"admin_open_faq_{row['id']}")] for row in rows]
    kb_rows.append([InlineKeyboardButton(text="⬅ Назад", callback_data="admin_manage_faq")])
    return InlineKeyboardMarkup(inline_keyboard=kb_rows)
def admin_edit_faq_keyboard(faq_id: int):
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="⬆️ Вверх", callback_data=f"admin_move_faq_up_{faq_id}"), InlineKeyboardButton(text="⬇️ Вниз", callback_data=f"admin_move_faq_down_{faq_id}")],
        [InlineKeyboardButton(text="✏️ Вопрос", callback_data=f"admin_edit_faq_q_{faq_id}"), InlineKeyboardButton(text="📝 Ответ", callback_data=f"admin_edit_faq_a_{faq_id}")],
        [InlineKeyboardButton(text="🖼 Медиа", callback_data=f"admin_edit_faq_m_{faq_id}")],
        [InlineKeyboardButton(text="🗑 Удалить", callback_data=f"admin_del_faq_{faq_id}")],
        [InlineKeyboardButton(text="⬅ Назад", callback_data="admin_manage_faq_list")]
    ])
def admin_edit_main_menu_keyboard():
    return InlineKeyboardMarkup(inline_keyboard=[
        [InlineKeyboardButton(text="📝 Текст", callback_data="admin_edit_mm_text"), InlineKeyboardButton(text="🖼 Фото", callback_data="admin_edit_mm_photo")],
        [InlineKeyboardButton(text="📞 Контакт для разбана", callback_data="admin_set_ban_contact")],
        [InlineKeyboardButton(text="⬅ Назад", callback_data="admin_cancel_to_admin_main")]
    ])

# === ХЕЛПЕР ===
async def send_autodelete_warning(message: Message, text: str):
    try:
        msg = await message.reply(text)
        await asyncio.sleep(3)
        await msg.delete()
    except: pass

# === ПРОВЕРКИ ===
async def check_access(msg_or_call) -> bool:
    user_id = msg_or_call.from_user.id
    if user_id in BANNED_USERS_CACHE:
        ban_text = await get_ban_message_text()
        try:
            if isinstance(msg_or_call, Message): await msg_or_call.answer(ban_text)
            elif isinstance(msg_or_call, CallbackQuery):
                await msg_or_call.answer("⛔ Вы заблокированы.", show_alert=True)
                try: await msg_or_call.message.delete()
                except: pass
                await msg_or_call.message.answer(ban_text)
        except: pass
        return False
    
    if user_id in ADMIN_IDS: return True
    if isinstance(msg_or_call, CallbackQuery): return True

    if isinstance(msg_or_call, Message):
        now = time.time()
        user_flood = FLOOD_CACHE.get(user_id, {})
        last_time = user_flood.get('time', 0)
        last_mg = user_flood.get('mg_id')
        curr_mg = msg_or_call.media_group_id

        if curr_mg and last_mg == curr_mg:
            FLOOD_CACHE[user_id] = {'time': now, 'mg_id': curr_mg}
            return True

        if now - last_time < FLOOD_RATE_LIMIT:
            asyncio.create_task(send_autodelete_warning(msg_or_call, f"⏳ Вы пишете слишком часто! Подождите {int(FLOOD_RATE_LIMIT)} сек."))
            return False 

        FLOOD_CACHE[user_id] = {'time': now, 'mg_id': curr_mg}
        
    return True

# === УТИЛИТЫ ===
async def create_new_topic_for_user(user_id: int, username: str | None) -> int | None:
    try:
        created = await bot.create_forum_topic(chat_id=SUPPORT_CHAT_ID, name="Временное имя")
        topic_id = created.message_thread_id
        ticket_id = await create_ticket(user_id, username, topic_id)
        await bot.edit_forum_topic(chat_id=SUPPORT_CHAT_ID, message_thread_id=topic_id, name=f"🔴 #ID{ticket_id} — @{username or 'user'} — {user_id}")
        topic_users[topic_id] = user_id
        user_topics[user_id] = topic_id
        return topic_id
    except Exception as e:
        logging.error(f"Error creating topic: {e}")
        return None

async def copy_message_any_type(msg: Message, dest_chat_id: int, thread_id: int | None = None, reply_to: int | None = None) -> Message | None:
    try:
        return await msg.copy_to(chat_id=dest_chat_id, message_thread_id=thread_id, reply_to_message_id=reply_to)
    except TelegramRetryAfter: raise 
    except Exception as e:
        logging.warning(f"Error copying: {e}")
        return None

# === ОБРАБОТКА АЛЬБОМОВ ===
async def process_album(media_group_id: str, is_operator: bool, extra_data: dict):
    await asyncio.sleep(1.0) # Ждем сбора всех частей
    
    if media_group_id not in ALBUM_CACHE: return
    messages = ALBUM_CACHE[media_group_id]['messages']
    del ALBUM_CACHE[media_group_id]
    
    # Сортируем по ID (по порядку)
    messages.sort(key=lambda m: m.message_id)
    
    media_group = []
    caption_set = False
    
    # Конвертируем сообщения в InputMedia
    for m in messages:
        caption = m.caption or m.text
        # Telegram разрешает caption только для первого элемента в send_media_group (обычно) или дублирует
        # Мы берем первый попавшийся caption
        if m.photo:
            media_group.append(InputMediaPhoto(media=m.photo[-1].file_id, caption=caption if not caption_set else None))
            if caption: caption_set = True
        elif m.video:
            media_group.append(InputMediaVideo(media=m.video.file_id, caption=caption if not caption_set else None))
            if caption: caption_set = True
        elif m.document:
            media_group.append(InputMediaDocument(media=m.document.file_id, caption=caption if not caption_set else None))
            if caption: caption_set = True
        elif m.audio:
            media_group.append(InputMediaAudio(media=m.audio.file_id, caption=caption if not caption_set else None))
            if caption: caption_set = True

    if not media_group: return

    # ОТПРАВКА
    if is_operator:
        # Оператор -> Пользователь
        user_id = extra_data.get('user_id')
        reply_to = extra_data.get('reply_to')
        if user_id:
            try: await bot.send_media_group(chat_id=user_id, media=media_group, reply_to_message_id=reply_to)
            except Exception as e: logging.error(f"Failed to send album to user: {e}")
    else:
        # Пользователь -> Оператор
        user_id = messages[0].from_user.id
        username = messages[0].from_user.username
        
        # 1. Проверяем, нужно ли создать тикет
        topic_id = user_topics.get(user_id)
        current_user_state = user_states.get(user_id, {})
        status = current_user_state.get("status")
        
        # Если статус awaiting_problem - создаем тикет прямо сейчас
        if status == "awaiting_problem":
            user_states[user_id] = {"status": "processing"}
            
            # Убираем промпт
            prompt_message_id = current_user_state.get("prompt_message_id")
            if prompt_message_id:
                try: await bot.edit_message_reply_markup(chat_id=user_id, message_id=prompt_message_id, reply_markup=None)
                except: pass
            
            topic_id = await create_new_topic_for_user(user_id, username)
            if not topic_id:
                await bot.send_message(user_id, "❗️ Ошибка создания тикета.")
                user_states.pop(user_id, None)
                return

            # Уведомление в админку
            panel_url = await get_setting('panel_base_url')
            buttons = []
            if panel_url: buttons.append(InlineKeyboardButton(text="Профиль", url=panel_url + f"users/{user_id}"))
            buttons.append(InlineKeyboardButton(text="Закрыть тикет", callback_data=f"admin_close_ticket_{topic_id}"))
            
            notice = await bot.send_message(SUPPORT_CHAT_ID, f"🆕 Новое обращение от @{username} (ID: {user_id})", message_thread_id=topic_id, reply_markup=InlineKeyboardMarkup(inline_keyboard=[buttons]))
            try: await bot.pin_chat_message(chat_id=SUPPORT_CHAT_ID, message_id=notice.message_id, disable_notification=True)
            except: pass
            
            # Ответ пользователю
            kb_close = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="❌ Закрыть обращение", callback_data="ticket_close")]])
            sent_info = await bot.send_message(user_id, "<b>✅ Ваше обращение зарегистрировано...</b>", reply_markup=None) # Текст по вашему ТЗ, кнопки отдельно
            
            # Кнопку "Закрыть" добавляем к промпту или отдельным сообщением? 
            # Вы просили оставить как было: меняем старую кнопку "Отменить" на "Закрыть"
            if prompt_message_id:
                try: await bot.edit_message_reply_markup(chat_id=user_id, message_id=prompt_message_id, reply_markup=kb_close)
                except: pass
            
            user_states[user_id] = {"status": "active", "prompt_message_id": prompt_message_id}

        elif not topic_id and status == "active":
             # Если тикета нет, а статус active (рассинхрон) - лечим
             user_states.pop(user_id, None)
             await show_main_menu(user_id)
             return

        if topic_id:
            # Отправляем альбом в топик
            reply_to_topic_msg_id = None
            # Для альбома Reply сложнее, берем Reply первого сообщения если есть
            if messages[0].reply_to_message:
                 reply_to_topic_msg_id = user_to_topic_from_operator.get(messages[0].reply_to_message.message_id)
                 if not reply_to_topic_msg_id: reply_to_topic_msg_id = user_to_topic_from_user.get(messages[0].reply_to_message.message_id)

            try:
                sent_msgs = await bot.send_media_group(chat_id=SUPPORT_CHAT_ID, message_thread_id=topic_id, media=media_group, reply_to_message_id=reply_to_topic_msg_id)
                # Сохраняем ID для reply (хотя бы первого сообщения из группы)
                if sent_msgs:
                    user_to_topic_from_user[messages[0].message_id] = sent_msgs[0].message_id
                    topic_to_user_from_user[sent_msgs[0].message_id] = messages[0].message_id
            except Exception as e:
                logging.error(f"Error sending album to support: {e}")

# === ГЛАВНОЕ МЕНЮ ===
async def show_main_menu(chat_id: int):
    text = await get_setting('main_menu_text')
    photo_id = await get_setting('main_menu_photo_id')
    if not text: text = "<b>👋 Привет!</b>\n\nЧтобы задать вопрос, воспользуйтесь меню."
    kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="📑 Часто задаваемые вопросы (FAQ)", callback_data="faq_open")]])
    try:
        if photo_id: await bot.send_photo(chat_id, photo_id, caption=text, reply_markup=kb)
        else: await bot.send_message(chat_id, text, reply_markup=kb)
    except: await bot.send_message(chat_id, text, reply_markup=kb)

# === СТАРТ ===
@dp.message(Command("start"), F.chat.type == "private")
async def cmd_start_handler(msg: Message, state: FSMContext):
    if not await check_access(msg): return
    await state.clear()
    if user_states.get(msg.from_user.id, {}).get("status") == "active":
        kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="❌ Закрыть обращение", callback_data="ticket_close")]])
        await msg.answer("У вас уже есть активное обращение.", reply_markup=kb)
    else:
        await show_main_menu(msg.chat.id)

# === ЗАКРЫТИЕ ТИКЕТА ===
async def close_ticket_flow(topic_id: int, closed_by: str = "operator", message_to_edit: Message | None = None):
    ticket_info = await get_ticket_info(topic_id)
    if not ticket_info: return
    user_id = topic_users.get(topic_id) or ticket_info['user_id']
    ticket_id = ticket_info['id']

    await close_ticket_by_topic_db(topic_id)

    if user_id:
        prompt_message_id = user_states.get(user_id, {}).get("prompt_message_id")
        if prompt_message_id:
            try: await bot.edit_message_reply_markup(chat_id=user_id, message_id=prompt_message_id, reply_markup=None)
            except: pass
        
        if closed_by == "user":
            if message_to_edit:
                try: await message_to_edit.edit_text("✅ Ваше обращение было закрыто.")
                except: pass
            try: await show_main_menu(user_id)
            except: pass
        else:
            try:
                await bot.send_message(user_id, f"✅ Ваше обращение было закрыто {'оператором' if closed_by == 'operator' else 'администратором'}.")
                await show_main_menu(user_id)
            except TelegramForbiddenError: logging.warning(f"User {user_id} blocked bot.")
            except Exception: pass

        user_states.pop(user_id, None)
        user_topics.pop(user_id, None)

    if ticket_id:
        try: await bot.edit_forum_topic(chat_id=SUPPORT_CHAT_ID, message_thread_id=topic_id, name=f"🟢 #ID{ticket_id} — CLOSED — {user_id}")
        except: pass
    try: await bot.close_forum_topic(chat_id=SUPPORT_CHAT_ID, message_thread_id=topic_id)
    except: pass
    topic_users.pop(topic_id, None)

# === КОМАНДЫ БАНА ===
@dp.message(Command("ban"), F.chat.id == SUPPORT_CHAT_ID)
async def cmd_ban_user(msg: Message):
    if not msg.message_thread_id: return
    topic_id = msg.message_thread_id
    user_id = topic_users.get(topic_id)
    if not user_id:
        info = await get_ticket_info(topic_id)
        if info: user_id = info['user_id']
    if not user_id: return await msg.reply("❌ Не могу найти ID пользователя.")

    args = msg.text.split(maxsplit=1)
    reason = args[1] if len(args) > 1 else "Нарушение правил"

    await ban_user_db(user_id, reason, msg.from_user.id)
    BANNED_USERS_CACHE.add(user_id)
    
    await close_ticket_by_topic_db(topic_id)
    
    ban_msg = await get_ban_message_text()
    try:
        await bot.send_message(user_id, ban_msg)
        prompt_id = user_states.get(user_id, {}).get("prompt_message_id")
        if prompt_id:
            try: await bot.edit_message_reply_markup(chat_id=user_id, message_id=prompt_id, reply_markup=None)
            except: pass
    except: pass
    
    user_states.pop(user_id, None)
    user_topics.pop(user_id, None)
    topic_users.pop(topic_id, None)

    await msg.reply(f"⛔ Пользователь {user_id} заблокирован.\nПричина: {reason}")

    try:
        ticket_info = await get_ticket_info(topic_id)
        if ticket_info:
            await bot.edit_forum_topic(chat_id=SUPPORT_CHAT_ID, message_thread_id=topic_id, name=f"🟢 #ID{ticket_info['id']} — BAN — {user_id}")
    except: pass
    try: await bot.close_forum_topic(chat_id=SUPPORT_CHAT_ID, message_thread_id=topic_id)
    except: pass

@dp.message(Command("unban"), F.chat.id == SUPPORT_CHAT_ID)
async def cmd_unban_user(msg: Message):
    args = msg.text.split(maxsplit=1)
    if len(args) < 2: return await msg.reply("❌ Используйте: /unban ID")
    try: target_id = int(args[1])
    except ValueError: return await msg.reply("❌ ID должен быть числом.")

    await unban_user_db(target_id)
    if target_id in BANNED_USERS_CACHE: BANNED_USERS_CACHE.remove(target_id)
    
    try: await bot.send_message(target_id, "✅ Вы были разблокированы администратором.")
    except: pass
    
    await msg.reply(f"✅ Пользователь {target_id} разблокирован.")
    
    last_ticket = await get_last_ticket_by_user(target_id)
    if last_ticket:
        topic_id = last_ticket['topic_id']
        try:
            await bot.edit_forum_topic(
                chat_id=SUPPORT_CHAT_ID, 
                message_thread_id=topic_id, 
                name=f"🟢 #ID{last_ticket['id']} — CLOSED — {target_id}"
            )
            await bot.reopen_forum_topic(chat_id=SUPPORT_CHAT_ID, message_thread_id=topic_id)
            await asyncio.sleep(0.2)
            await bot.close_forum_topic(chat_id=SUPPORT_CHAT_ID, message_thread_id=topic_id)
        except: pass

# === АДМИНКА ===
@dp.message(Command("admin"), F.chat.type == "private")
async def cmd_admin(msg: Message, state: FSMContext):
    if msg.from_user.id not in ADMIN_IDS: return
    await state.clear()
    await msg.answer("Админ-панель:", reply_markup=admin_main_keyboard())

@dp.callback_query(F.data.startswith("admin_cancel_to_"))
async def cb_admin_cancel(call: CallbackQuery, state: FSMContext):
    await state.clear()
    location = call.data.replace("admin_cancel_to_", "")
    if location == "admin_main": await call.message.edit_text("Админка:", reply_markup=admin_main_keyboard())
    elif location == "faq": await call.message.edit_text("FAQ:", reply_markup=admin_faq_keyboard())
    elif location == "main_menu_edit": await call.message.edit_text("Ред. меню:", reply_markup=admin_edit_main_menu_keyboard())
    elif location.startswith("faq_edit_"):
        faq_id = int(location.split("_")[-1])
        faq, media = await get_faq_item(faq_id)
        if faq:
            media_info = f"\n\n<b>Медиа:</b> {media[0]['type'] if media else 'нет'}"
            text = f"<b>В:</b>\n{faq['question']}\n\n<b>О:</b>\n{faq['answer']}" + media_info
            await call.message.edit_text(text, reply_markup=admin_edit_faq_keyboard(faq_id))
    await call.answer()

@dp.callback_query(F.data == "admin_show_user_menu")
async def cb_admin_show_user_menu(call: CallbackQuery, state: FSMContext):
    await state.clear()
    await call.message.delete()
    await show_main_menu(call.from_user.id)
    await call.answer()

@dp.callback_query(F.data == "admin_edit_main_menu")
async def cb_admin_edit_main_menu(call: CallbackQuery, state: FSMContext):
    await state.clear()
    await call.message.edit_text("Ред. меню:", reply_markup=admin_edit_main_menu_keyboard())

@dp.callback_query(F.data == "admin_edit_mm_text")
async def cb_admin_edit_mm_text(call: CallbackQuery, state: FSMContext):
    await state.set_state(AdminStates.edit_main_menu_text)
    await call.message.edit_text("Текст меню:", reply_markup=admin_cancel_keyboard("main_menu_edit"))

@dp.callback_query(F.data == "admin_edit_mm_photo")
async def cb_admin_edit_mm_photo(call: CallbackQuery, state: FSMContext):
    await state.set_state(AdminStates.edit_main_menu_photo)
    await call.message.edit_text("Фото меню (/remove для удаления):", reply_markup=admin_cancel_keyboard("main_menu_edit"))

@dp.callback_query(F.data == "admin_set_panel")
async def cb_admin_set_panel(call: CallbackQuery, state: FSMContext):
    current_url = await get_setting('panel_base_url')
    text = (f"Текущий URL: `{current_url}`\n\n" if current_url else "URL не задан.\n\n")
    text += "Введите URL (формат: `https://.../`)"
    await state.set_state(AdminStates.set_panel_url)
    await call.message.edit_text(text, parse_mode="Markdown", reply_markup=admin_cancel_keyboard("admin_main"))

@dp.callback_query(F.data == "admin_set_ban_contact")
async def cb_admin_set_ban_contact(call: CallbackQuery, state: FSMContext):
    current = await get_setting('ban_contact') or "Не задан"
    text = f"Текущий контакт: {current}\n\nОтправьте юзернейм (например @admin) или текст, куда писать забаненным."
    await state.set_state(AdminStates.set_ban_contact)
    await call.message.edit_text(text, reply_markup=admin_cancel_keyboard("admin_main"))

@dp.callback_query(F.data == "admin_manage_faq")
async def cb_admin_manage_faq(call: CallbackQuery, state: FSMContext):
    await state.clear()
    await call.message.edit_text("FAQ:", reply_markup=admin_faq_keyboard())

@dp.callback_query(F.data == "admin_add_faq")
async def cb_admin_add_faq(call: CallbackQuery, state: FSMContext):
    await state.set_state(AdminStates.add_question)
    await call.message.edit_text("Текст вопроса:", reply_markup=admin_cancel_keyboard("faq"))

@dp.callback_query(F.data == "admin_manage_faq_list")
async def cb_admin_manage_faq_list(call: CallbackQuery, state: FSMContext):
    await state.clear()
    await call.message.edit_text("Список вопросов:", reply_markup=await admin_manage_faq_list_keyboard())

@dp.callback_query(F.data.startswith("admin_open_faq_"))
async def cb_admin_open_faq(call: CallbackQuery):
    faq_id = int(call.data.split("_")[-1])
    faq, media = await get_faq_item(faq_id)
    if not faq: return
    media_info = f"\n\n<b>Медиа:</b> {media[0]['type'] if media else 'нет'}"
    text = f"<b>В:</b>\n{faq['question']}\n\n<b>О:</b>\n{faq['answer']}" + media_info
    try: await call.message.edit_text(text, reply_markup=admin_edit_faq_keyboard(faq_id))
    except: pass
    await call.answer()
    
@dp.callback_query(F.data.startswith("admin_move_faq_"))
async def cb_admin_move_faq(call: CallbackQuery):
    parts = call.data.split("_")
    direction = parts[3] # up или down
    faq_id = int(parts[4])
    await move_faq(faq_id, direction)
    await call.message.edit_reply_markup(reply_markup=await admin_manage_faq_list_keyboard()) # Обновляем список
    await call.answer("Перемещено")

@dp.callback_query(F.data.startswith("admin_edit_faq_"))
async def cb_admin_edit_faq_dispatch(call: CallbackQuery, state: FSMContext):
    parts = call.data.split("_")
    action = parts[3]
    faq_id = int(parts[4])
    await state.update_data(faq_id=faq_id)
    if action == "q":
        await state.set_state(AdminStates.edit_question)
        await call.message.edit_text("Новый вопрос:", reply_markup=admin_cancel_keyboard(f"faq_edit_{faq_id}"))
    elif action == "a":
        await state.set_state(AdminStates.edit_answer)
        await call.message.edit_text("Новый ответ:", reply_markup=admin_cancel_keyboard(f"faq_edit_{faq_id}"))
    elif action == "m":
        await state.set_state(AdminStates.edit_media)
        await call.message.edit_text("Новое медиа или /remove:", reply_markup=admin_cancel_keyboard(f"faq_edit_{faq_id}"))

@dp.callback_query(F.data.startswith("admin_del_faq_"))
async def cb_admin_del_faq(call: CallbackQuery):
    faq_id = int(call.data.split("_")[-1])
    await delete_faq(faq_id)
    await call.answer("Удалено")
    await call.message.edit_text("Список:", reply_markup=await admin_manage_faq_list_keyboard())

# --- ТЕКСТ АДМИНА ---
@dp.message(F.text, F.from_user.id.in_(ADMIN_IDS), StateFilter(AdminStates), F.chat.type == "private")
async def admin_text_handler(msg: Message, state: FSMContext):
    current_state = await state.get_state()
    data = await state.get_data()
    
    if current_state == AdminStates.set_panel_url:
        if msg.text.startswith('http'):
            await set_setting('panel_base_url', msg.text)
            await state.clear()
            await msg.answer("✅ URL сохранен.", reply_markup=admin_main_keyboard())
        else: await msg.answer("❌ Неверный формат.", reply_markup=admin_cancel_keyboard("admin_main"))
            
    elif current_state == AdminStates.set_ban_contact:
        await set_setting('ban_contact', msg.text)
        await state.clear()
        await msg.answer("✅ Контакт для жалоб сохранен.", reply_markup=admin_edit_main_menu_keyboard())

    elif current_state == AdminStates.edit_main_menu_text:
        await set_setting('main_menu_text', msg.html_text)
        await state.clear()
        await msg.answer("✅ Текст обновлен.", reply_markup=admin_edit_main_menu_keyboard())
        
    elif current_state == AdminStates.edit_main_menu_photo and msg.text == '/remove':
        await set_setting('main_menu_photo_id', '')
        await state.clear()
        await msg.answer("✅ Фото удалено.", reply_markup=admin_edit_main_menu_keyboard())
        
    elif current_state == AdminStates.add_question:
        await state.update_data(question=msg.html_text)
        await state.set_state(AdminStates.add_answer)
        await msg.answer("Текст ответа:", reply_markup=admin_cancel_keyboard("faq"))
        
    elif current_state == AdminStates.add_answer:
        await state.update_data(answer=msg.html_text)
        await state.set_state(AdminStates.add_media)
        await msg.answer("Медиа (или /skip):", reply_markup=admin_cancel_keyboard("faq"))

    elif current_state == AdminStates.add_media and msg.text == "/skip":
        await create_faq(data.get("question"), data.get("answer"))
        await state.clear()
        await msg.answer("✅ FAQ создан.", reply_markup=admin_faq_keyboard())
        
    elif current_state == AdminStates.edit_question:
        faq_id = data.get("faq_id")
        await update_faq(faq_id, question=msg.html_text)
        await state.clear()
        await msg.answer("✅ Вопрос обновлен.", reply_markup=admin_edit_faq_keyboard(faq_id))
        
    elif current_state == AdminStates.edit_answer:
        faq_id = data.get("faq_id")
        await update_faq(faq_id, answer=msg.html_text)
        await state.clear()
        await msg.answer("✅ Ответ обновлен.", reply_markup=admin_edit_faq_keyboard(faq_id))
        
    elif current_state == AdminStates.edit_media and msg.text == "/remove":
        faq_id = data.get("faq_id")
        await clear_faq_media(faq_id)
        await state.clear()
        await msg.answer("✅ Медиа удалено.", reply_markup=admin_edit_faq_keyboard(faq_id))

# --- МЕДИА АДМИНА ---
@dp.message(F.photo | F.video | F.document, F.from_user.id.in_(ADMIN_IDS), StateFilter(AdminStates), F.chat.type == "private")
async def admin_media_handler(msg: Message, state: FSMContext):
    current_state = await state.get_state()
    data = await state.get_data()
    file_id = None
    m_type = None
    if msg.photo: file_id, m_type = msg.photo[-1].file_id, "photo"
    elif msg.video: file_id, m_type = msg.video.file_id, "video"
    elif msg.document: file_id, m_type = msg.document.file_id, "document"

    if current_state == AdminStates.add_media:
        faq_id = await create_faq(data.get("question"), data.get("answer"))
        await add_faq_media(faq_id, file_id, m_type)
        await state.clear()
        await msg.answer("✅ FAQ создан (с медиа).", reply_markup=admin_faq_keyboard())
    elif current_state == AdminStates.edit_media:
        faq_id = data.get("faq_id")
        await add_faq_media(faq_id, file_id, m_type)
        await state.clear()
        await msg.answer("✅ Медиа обновлено.", reply_markup=admin_edit_faq_keyboard(faq_id))
    elif current_state == AdminStates.edit_main_menu_photo and msg.photo:
        await set_setting('main_menu_photo_id', msg.photo[-1].file_id)
        await state.clear()
        await msg.answer("✅ Фото меню обновлено.", reply_markup=admin_edit_main_menu_keyboard())

# === ХЕНДЛЕРЫ ПОЛЬЗОВАТЕЛЯ ===
@dp.callback_query(F.data == "faq_open")
async def cb_faq_open(call: CallbackQuery):
    if not await check_access(call): return
    try: await call.message.delete()
    except: pass
    await call.message.answer("📑 <b>Часто задаваемые вопросы (FAQ):</b>", reply_markup=await faq_main_keyboard())
    await call.answer()

@dp.callback_query(F.data.startswith("faq_q_"))
async def cb_faq_question(call: CallbackQuery):
    if not await check_access(call): return
    faq_id = int(call.data.split("_")[2])
    faq, media = await get_faq_item(faq_id)
    if not faq: return
    try: await call.message.delete()
    except: pass
    text = f"<b>{faq['question']}</b>\n\n{faq['answer']}"
    kb = faq_back_keyboard()
    if media:
        file_id = media[0]['file_id']
        m_type = media[0]['type']
        if m_type == "photo": await call.message.answer_photo(file_id, caption=text, reply_markup=kb)
        elif m_type == "video": await call.message.answer_video(file_id, caption=text, reply_markup=kb)
        elif m_type == "document": await call.message.answer_document(file_id, caption=text, reply_markup=kb)
    else: 
        await call.message.answer(text, reply_markup=kb, link_preview_options=LinkPreviewOptions(is_disabled=True))
    await call.answer()

@dp.callback_query(F.data == "faq_back")
async def cb_faq_back(call: CallbackQuery):
    if not await check_access(call): return
    await call.message.delete()
    await bot.send_message(call.from_user.id, "📑 <b>Часто задаваемые вопросы (FAQ):</b>", reply_markup=await faq_main_keyboard())
    await call.answer()
    
@dp.callback_query(F.data == "faq_back_to_menu")
async def cb_faq_back_to_menu(call: CallbackQuery):
    if not await check_access(call): return
    try: await call.message.delete()
    except: pass
    await show_main_menu(call.from_user.id)
    await call.answer()
    
@dp.callback_query(F.data == "ticket_close")
async def cb_ticket_close(call: CallbackQuery):
    if not await check_access(call): return
    topic_id = user_topics.get(call.from_user.id)
    if not topic_id: return await call.answer("Не найдено активных обращений.", show_alert=True)
    await close_ticket_flow(topic_id, "user", call.message)

@dp.callback_query(F.data == "faq_no_answer")
async def cb_faq_no_answer(call: CallbackQuery):
    if not await check_access(call): return
    user_id = call.from_user.id
    try: await call.message.delete()
    except: pass
    kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="❌ Отменить обращение", callback_data="ticket_cancel_creation")]])
    sent = await bot.send_message(call.message.chat.id, "<b>📨 Создаём обращение, пожалуйста, подробно опишите вашу проблему.</b>", reply_markup=kb)
    user_states[user_id] = {"status": "awaiting_problem", "prompt_message_id": sent.message_id}
    await call.answer()
    
@dp.callback_query(F.data == "ticket_cancel_creation")
async def cb_ticket_cancel_creation(call: CallbackQuery):
    if not await check_access(call): return
    user_states.pop(call.from_user.id, None)
    await call.message.delete()
    await show_main_menu(call.from_user.id)
    await call.answer("Создание обращения отменено.")

@dp.message(F.chat.type == "private", StateFilter(None))
async def handle_user(msg: Message):
    if not await check_access(msg): return # Антиспам
    
    # ПРОВЕРКА НА АЛЬБОМ
    if msg.media_group_id:
        if msg.media_group_id not in ALBUM_CACHE:
            ALBUM_CACHE[msg.media_group_id] = {'messages': [], 'task': None}
            # Запускаем отложенную обработку
            task = asyncio.create_task(process_album(msg.media_group_id, is_operator=False, extra_data={}))
            ALBUM_CACHE[msg.media_group_id]['task'] = task
        
        ALBUM_CACHE[msg.media_group_id]['messages'].append(msg)
        return # Выходим, обрабатывать будем в process_album

    # ДАЛЬШЕ СТАРАЯ ЛОГИКА ДЛЯ ОДИНОЧНЫХ СООБЩЕНИЙ
    user_id = msg.from_user.id
    current_user_state = user_states.get(user_id, {})
    status = current_user_state.get("status")

    if status == "active":
        topic_id = user_topics.get(user_id)
        if topic_id:
            ticket_info = await get_ticket_info(topic_id)
            if ticket_info and ticket_info['status'] == 'closed':
                user_states.pop(user_id, None)
                user_topics.pop(user_id, None)
                status = None

    if not status: return await show_main_menu(msg.chat.id)

    if status == "active":
        topic_id = user_topics.get(user_id)
        if not topic_id:
            user_states.pop(user_id, None)
            return await msg.answer("Ошибка, создайте новое обращение.")
        
        reply_to_topic_msg_id = None
        if msg.reply_to_message:
            reply_to_topic_msg_id = user_to_topic_from_operator.get(msg.reply_to_message.message_id)
            if not reply_to_topic_msg_id: reply_to_topic_msg_id = user_to_topic_from_user.get(msg.reply_to_message.message_id)

        sent = await copy_message_any_type(msg, dest_chat_id=SUPPORT_CHAT_ID, thread_id=topic_id, reply_to=reply_to_topic_msg_id)
        if sent:
            user_to_topic_from_user[msg.message_id] = sent.message_id
            topic_to_user_from_user[sent.message_id] = msg.message_id
        else: await msg.answer("⚠️ Не удалось отправить сообщение поддержке.")
        
    elif status == "processing": return
        
    elif status == "awaiting_problem":
        user_states[user_id] = {"status": "processing"}
        username = msg.from_user.username
        
        topic_id = await create_new_topic_for_user(user_id, username)
        if not topic_id:
            user_states.pop(user_id, None)
            return await msg.answer("❗️ Не удалось создать обращение.")

        panel_url = await get_setting('panel_base_url')
        buttons = []
        if panel_url: buttons.append(InlineKeyboardButton(text="Просмотреть пользователя", url=panel_url + f"users/{user_id}"))
        buttons.append(InlineKeyboardButton(text="Закрыть тикет", callback_data=f"admin_close_ticket_{topic_id}"))
        
        notice = await bot.send_message(SUPPORT_CHAT_ID, f"🆕 Новое обращение от @{username} (ID: {user_id})", message_thread_id=topic_id, reply_markup=InlineKeyboardMarkup(inline_keyboard=[buttons]))
        try: await bot.pin_chat_message(chat_id=SUPPORT_CHAT_ID, message_id=notice.message_id, disable_notification=True)
        except: pass
        
        sent = await copy_message_any_type(msg, dest_chat_id=SUPPORT_CHAT_ID, thread_id=topic_id)
        if sent:
            user_to_topic_from_user[msg.message_id] = sent.message_id
            topic_to_user_from_user[sent.message_id] = msg.message_id
        
        kb_close = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="❌ Закрыть обращение", callback_data="ticket_close")]])
        prompt_message_id = current_user_state.get("prompt_message_id")
        if prompt_message_id:
            try: await bot.edit_message_reply_markup(chat_id=user_id, message_id=prompt_message_id, reply_markup=kb_close)
            except: pass
            
        await msg.answer("<b>✅ Ваше обращение зарегистрировано, пожалуйста, дождитесь ответа оператора.\nЧтобы дополнить обращение — пришлите следующее сообщение.</b>")
        user_states[user_id] = {"status": "active", "prompt_message_id": prompt_message_id}

@dp.callback_query(F.data.startswith("admin_close_ticket_"))
async def cb_admin_close_ticket(call: CallbackQuery):
    if call.from_user.id not in ADMIN_IDS: return await call.answer("⛔ Эта кнопка только для операторов.", show_alert=True)
    topic_id = int(call.data.split("_")[-1])
    
    ticket_info = await get_ticket_info(topic_id)
    ticket_user_id = topic_users.get(topic_id) or (ticket_info['user_id'] if ticket_info else None)
    current_status = ticket_info['status'] if ticket_info else 'closed'

    panel_url = await get_setting('panel_base_url')
    new_kb = None
    if panel_url and ticket_user_id:
         new_kb = InlineKeyboardMarkup(inline_keyboard=[[InlineKeyboardButton(text="Просмотреть пользователя", url=panel_url + f"users/{ticket_user_id}")]])
    
    if current_status == "closed":
        await call.message.edit_reply_markup(reply_markup=new_kb)
        return await call.answer("Тикет уже закрыт пользователем.", show_alert=True)

    await call.message.edit_reply_markup(reply_markup=new_kb) 
    await close_ticket_flow(topic_id, "admin")
    await call.answer("Тикет закрыт.")

@dp.message(F.chat.id == SUPPORT_CHAT_ID)
async def handle_operator(msg: Message):
    if msg.from_user.id == bot.id: return
    if not msg.message_thread_id: return
    topic_id = msg.message_thread_id
    if msg.text and msg.text.startswith("/"): return

    user_id = topic_users.get(topic_id)
    if not user_id:
         info = await get_ticket_info(topic_id)
         if info and info['status'] == 'closed':
             return await msg.reply("⚠️ Тикет закрыт. Сообщение не доставлено.")
         user_id = info['user_id'] if info else None
    
    if not user_id: return
    
    reply_to_user_msg_id = None
    if msg.reply_to_message:
        reply_id = msg.reply_to_message.message_id
        reply_to_user_msg_id = topic_to_user_from_user.get(reply_id)
        if not reply_to_user_msg_id: reply_to_user_msg_id = topic_to_user_from_operator.get(reply_id)

    # ПРОВЕРКА НА АЛЬБОМ ОПЕРАТОРА
    if msg.media_group_id:
        if msg.media_group_id not in ALBUM_CACHE:
            ALBUM_CACHE[msg.media_group_id] = {'messages': [], 'task': None}
            # Передаем user_id и reply_to
            task = asyncio.create_task(process_album(msg.media_group_id, is_operator=True, extra_data={'user_id': user_id, 'reply_to': reply_to_user_msg_id}))
            ALBUM_CACHE[msg.media_group_id]['task'] = task
        
        ALBUM_CACHE[msg.media_group_id]['messages'].append(msg)
        return

    sent = await copy_message_any_type(msg, dest_chat_id=user_id, reply_to=reply_to_user_msg_id)
    if sent:
        user_to_topic_from_operator[sent.message_id] = msg.message_id
        topic_to_user_from_operator[msg.message_id] = sent.message_id
    else:
        try: await msg.reply("⚠️ Не удалось отправить сообщение пользователю.")
        except: pass

async def on_startup():
    await init_db()
    await reindex_faq_sort()
    banned = await get_banned_list_db()
    BANNED_USERS_CACHE.update(banned)
    rows = await get_active_tickets_db()
    for row in rows:
        uid, tid = row['user_id'], row['topic_id']
        user_states[uid] = {'status': 'active'}
        user_topics[uid] = tid
        topic_users[tid] = uid
    logging.info(f"Бот запущен. Банов: {len(BANNED_USERS_CACHE)}")

async def main():
    dp.startup.register(on_startup)
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())