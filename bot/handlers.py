import asyncio
import logging
import asyncio
import logging
import uuid
from datetime import datetime, timezone
from aiogram import Bot, types
from aiogram.filters import Command
from aiogram.fsm.context import FSMContext
from bot_config import VERSION, ADMIN_IDS
from database.db import get_panels, add_admin, remove_admin, get_admins, delete_panel, save_panel
from bot.menus import config_selection_menu, delete_panel_menu, main_menu, admin_management_menu, note_menu, panel_selection_menu, panel_action_menu, user_action_menu, create_menu_layout
from bot.states import Form
from api.marzban_api import create_user_logic, show_user_info, delete_user_logic, disable_user_logic, enable_user_logic, delete_configs_logic, get_users_stats
from utils.message_utils import cleanup_messages
from utils.formatting import format_traffic, format_expire_time
from utils.validation import validate_panel_url
from marzpy import Marzban
import aiohttp
import socket
from aiogram.types import InlineKeyboardButton
from bot.menus import main_menu, admin_management_menu, panel_selection_menu, panel_action_menu, user_action_menu, create_menu_layout, panel_login_menu

logger = logging.getLogger(__name__)

def is_owner(chat_id: int) -> bool:
    return chat_id in ADMIN_IDS

def is_admin(chat_id: int) -> bool:
    if is_owner(chat_id):
        return True
    admins = get_admins()
    return chat_id in admins

async def cleanup_messages(bot: Bot, chat_id: int, state: FSMContext):
    data = await state.get_data()
    login_messages = data.get("login_messages", [])
    async def delete_message(message_id: int):
        try:
            await bot.delete_message(chat_id=chat_id, message_id=message_id)
        except Exception as e:
            logger.warning(f"Failed to delete message {message_id}: {str(e)}")
    await asyncio.gather(*[delete_message(message_id) for message_id in login_messages])
    await state.update_data(login_messages=[])

async def start(message: types.Message, state: FSMContext, bot: Bot):
    await cleanup_messages(bot, message.from_user.id, state)
    chat_id = message.from_user.id
    if not is_admin(chat_id):
        message = await bot.send_message(chat_id, "🚫 شما اجازه استفاده از این ربات را ندارید.")
        await state.update_data(login_messages=[message.message_id])
        return
    panels = get_panels(chat_id)
    if panels:
        message = await bot.send_message(chat_id, f"🎉 به ربات مدیر خوش آمدید (نسخه {VERSION})", reply_markup=main_menu(is_owner(chat_id)))
        await state.update_data(login_messages=[message.message_id])
    else:
        buttons = [
            InlineKeyboardButton(text="➕ افزودن پنل جدید", callback_data="add_server"),
            InlineKeyboardButton(text="👨‍💼 مدیریت مدیران", callback_data="manage_admins") if is_owner(chat_id) else None
        ]
        buttons = [b for b in buttons if b]
        message = await bot.send_message(chat_id, f"🎉 به ربات مدیر خوش آمدید (نسخه {VERSION})", reply_markup=create_menu_layout(buttons))
        await state.update_data(login_messages=[message.message_id])

async def show_user_info_for_owner(message: types.Message, state: FSMContext, chat_id: int, bot: Bot):
    await cleanup_messages(bot, chat_id, state)
    panels = get_panels(chat_id)
    if not panels:
        message = await bot.send_message(chat_id, "⚠️ هیچ پنلی ثبت نشده است.", reply_markup=admin_management_menu())
        await state.update_data(login_messages=[message.message_id])
        return
    response_text = f"📊 اطلاعات پنل‌ها برای کاربر {chat_id}:\n\n"
    for panel in panels:
        alias, panel_url, token, username, password = panel
        stats = await get_users_stats(panel_url, token)
        response_text += (
            f"📌 پنل: {alias}\n"
            f"🔗 آدرس: {panel_url}\n"
            f"👤 نام کاربری ادمین: {username}\n"
            f"🔑 رمز عبور: {password}\n"
            f"👥 تعداد کل کاربران: {stats['total']}\n"
            f"✅ کاربران فعال: {stats['active']}\n"
            f"⛔ کاربران غیرفعال: {stats['inactive']}\n"
            f"⌛ کاربران منقضی‌شده: {stats['expired']}\n"
            f"📉 کاربران محدود شده: {stats['limited']}\n\n"
        )
    message = await bot.send_message(chat_id, response_text, reply_markup=admin_management_menu())
    await state.update_data(login_messages=[message.message_id])
    await state.clear()

async def button_callback(query: types.CallbackQuery, state: FSMContext, bot: Bot):
    await query.answer()
    chat_id = query.from_user.id
    data = query.data
    await cleanup_messages(bot, chat_id, state)
    if data == "add_server":
        await state.set_state(Form.awaiting_panel_alias)
        message = await bot.send_message(chat_id, "📝 لطفاً یک نام مستعار برای پنل وارد کنید:", reply_markup=panel_login_menu())
        await state.update_data(login_messages=[message.message_id])
    elif data == "manage_admins":
        if not is_owner(chat_id):
            message = await bot.send_message(chat_id, "🚫 فقط مالک می‌تواند مدیران را مدیریت کند.")
            await state.update_data(login_messages=[message.message_id])
            return
        message = await bot.send_message(chat_id, "👨‍💼 مدیریت مدیران:", reply_markup=admin_management_menu())
        await state.update_data(login_messages=[message.message_id])
    elif data == "add_admin":
        if not is_owner(chat_id):
            message = await bot.send_message(chat_id, "🚫 فقط مالک می‌تواند مدیران را مدیریت کند.")
            await state.update_data(login_messages=[message.message_id])
            return
        await state.set_state(Form.awaiting_add_admin)
        message = await bot.send_message(chat_id, "👤 لطفاً آیدی عددی مدیر جدید را وارد کنید:")
        await state.update_data(login_messages=[message.message_id])
    elif data == "remove_admin":
        if not is_owner(chat_id):
            message = await bot.send_message(chat_id, "🚫 فقط مالک می‌تواند مدیران را مدیریت کند.")
            await state.update_data(login_messages=[message.message_id])
            return
        admins = get_admins()
        if not admins:
            message = await bot.send_message(chat_id, "📋 هیچ مدیری ثبت نشده است.", reply_markup=admin_management_menu())
            await state.update_data(login_messages=[message.message_id])
            return
        buttons = [
            InlineKeyboardButton(text=f"🗑 {admin_id}", callback_data=f"confirm_remove_admin:{admin_id}")
            for admin_id in admins
        ]
        buttons.append(InlineKeyboardButton(text="🔙 بازگشت به منوی اصلی", callback_data="back_to_main"))
        message = await bot.send_message(chat_id, "📋 لطفاً مدیر موردنظر را برای حذف انتخاب کنید:", reply_markup=create_menu_layout(buttons))
        await state.update_data(login_messages=[message.message_id])
    elif data.startswith("confirm_remove_admin:"):
        admin_id = int(data.split(":")[1])
        remove_admin(admin_id)
        message = await bot.send_message(chat_id, f"🗑 مدیر با آیدی {admin_id} با موفقیت حذف شد.", reply_markup=admin_management_menu())
        await state.update_data(login_messages=[message.message_id])
    elif data == "user_info":
        if not is_owner(chat_id):
            message = await bot.send_message(chat_id, "🚫 فقط مالک می‌تواند اطلاعات کاربر را ببیند.")
            await state.update_data(login_messages=[message.message_id])
            return
        await state.set_state(Form.awaiting_user_info)
        message = await bot.send_message(chat_id, "📊 لطفاً آیدی عددی کاربر را وارد کنید:")
        await state.update_data(login_messages=[message.message_id])
    elif data == "manage_panels":
        panels = get_panels(chat_id)
        if not panels:
            message = await bot.send_message(chat_id, "⚠️ هیچ پنلی ثبت نشده است.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            return
        await state.set_state(Form.awaiting_panel_selection)
        message = await bot.send_message(chat_id, "📌 لطفاً یک پنل انتخاب کنید:", reply_markup=panel_selection_menu(panels))
        await state.update_data(login_messages=[message.message_id])
    elif data == "delete_panel":
        panels = get_panels(chat_id)
        if not panels:
            message = await bot.send_message(chat_id, "⚠️ هیچ پنلی برای حذف وجود ندارد.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            return
        await state.set_state(Form.awaiting_delete_panel)
        message = await bot.send_message(chat_id, "🗑 لطفاً پنل موردنظر را برای حذف انتخاب کنید:", reply_markup=delete_panel_menu(panels))
        await state.update_data(login_messages=[message.message_id])
    elif data.startswith("confirm_delete_panel:"):
        alias = data.split(":", 1)[1]
        delete_panel(chat_id, alias)
        panels = get_panels(chat_id)
        if panels:
            message = await bot.send_message(chat_id, f"🗑 پنل '{alias}' با موفقیت حذف شد.", reply_markup=panel_selection_menu(panels))
            await state.update_data(login_messages=[message.message_id])
        else:
            message = await bot.send_message(chat_id, f"🗑 پنل '{alias}' با موفقیت حذف شد. هیچ پنلی باقی نمانده است.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
        await state.clear()
    elif data.startswith("select_panel:"):
        alias = data.split(":", 1)[1]
        await state.update_data(selected_panel_alias=alias)
        await state.set_state(Form.awaiting_action)
        panels = get_panels(chat_id)
        panel = next((p for p in panels if p[0] == alias), None)
        if not panel:
            message = await bot.send_message(chat_id, "⚠️ پنل انتخاب‌شده یافت نشد.")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        stats = await get_users_stats(panel[1], panel[2], force_refresh=True)
        response_text = (
            f"✅ پنل '{alias}' انتخاب شد.\n\n"
            f"👥 تعداد کل کاربران: {stats['total']}\n"
            f"✅ کاربران فعال: {stats['active']}\n"
            f"⛔ کاربران غیرفعال: {stats['inactive']}\n"
            f"⌛ کاربران منقضی‌شده: {stats['expired']}\n"
            f"📉 کاربران محدود شده: {stats['limited']}\n\n"
            "لطفاً یک عملیات انتخاب کنید:"
        )
        message = await bot.send_message(chat_id, response_text, reply_markup=panel_action_menu())
        await state.update_data(login_messages=[message.message_id])
    elif data == "back_to_panel_selection":
        panels = get_panels(chat_id)
        if not panels:
            message = await bot.send_message(chat_id, "⚠️ هیچ پنلی ثبت نشده است.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            return
        await state.set_state(Form.awaiting_panel_selection)
        message = await bot.send_message(chat_id, "📌 لطفاً یک پنل انتخاب کنید:", reply_markup=panel_selection_menu(panels))
        await state.update_data(login_messages=[message.message_id])
    elif data == "search_user":
        await state.set_state(Form.awaiting_search_username)
        message = await bot.send_message(chat_id, "🔍 نام کاربری را وارد کنید:")
        await state.update_data(login_messages=[message.message_id])
    elif data == "create_user":
        await state.set_state(Form.awaiting_create_username)
        buttons = [InlineKeyboardButton(text="🎲 تولید نام تصادفی", callback_data="random_username")]
        message = await bot.send_message(chat_id, "📝 نام کاربری را وارد کنید:", reply_markup=create_menu_layout(buttons))
        await state.update_data(login_messages=[message.message_id])
    elif data == "random_username":
        random_username = str(uuid.uuid4())[:8]
        await state.update_data(username=random_username)
        await state.set_state(Form.awaiting_data_limit)
        message = await bot.send_message(chat_id, f"📝 نام کاربری: {random_username}\n📊 حجم (به گیگابایت) را وارد کنید (برای نامحدود، 0 وارد کنید):")
        await state.update_data(login_messages=[message.message_id])
    elif data == "set_note_none":
        success_msg, error_msg = await create_user_logic(chat_id, state, "")
        if success_msg:
            message = await bot.send_message(chat_id, success_msg, reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
        else:
            message = await bot.send_message(chat_id, error_msg)
            await state.update_data(login_messages=[message.message_id])
        await state.clear()
    elif data.startswith("delete_user:"):
        username = data.split(":", 1)[1]
        await delete_user_logic(query, state, username, chat_id, bot)
    elif data.startswith("disable_user:"):
        username = data.split(":", 1)[1]
        await disable_user_logic(query, state, username, chat_id, bot)
    elif data.startswith("enable_user:"):
        username = data.split(":", 1)[1]
        await enable_user_logic(query, state, username, chat_id, bot)
    elif data.startswith("manage_configs:"):
        username = data.split(":", 1)[1]
        await state.update_data(existing_username=username)
        await state.set_state(Form.awaiting_inbounds_selection_for_existing_user)
        data = await state.get_data()
        selected_panel_alias = data.get("selected_panel_alias")
        if not selected_panel_alias:
            message = await bot.send_message(chat_id, "⚠️ لطفاً ابتدا یک پنل انتخاب کنید.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        panels = get_panels(chat_id)
        panel = next((p for p in panels if p[0] == selected_panel_alias), None)
        if not panel:
            message = await bot.send_message(chat_id, "⚠️ پنل انتخاب‌شده یافت نشد.")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        try:
            async with aiohttp.ClientSession() as session:
                headers = {"Authorization": f"Bearer {panel[2]}"}
                async with session.get(f"{panel[1].rstrip('/')}/api/user/{username}", headers=headers) as response:
                    if response.status == 200:
                        user_data = await response.json()
                        current_inbounds = []
                        for protocol, settings in user_data.get("inbounds", {}).items():
                            for tag in settings:
                                current_inbounds.append(f"{protocol}:{tag}")
                    else:
                        message = await bot.send_message(chat_id, "❌ کاربر یافت نشد.")
                        await state.update_data(login_messages=[message.message_id])
                        await state.clear()
                        return
                async with session.get(f"{panel[1].rstrip('/')}/api/inbounds", headers=headers) as response:
                    if response.status == 200:
                        inbounds_data = await response.json()
                        available_inbounds = []
                        for protocol, settings in inbounds_data.items():
                            for inbound in settings:
                                available_inbounds.append(f"{protocol}:{inbound['tag']}")
                    else:
                        message = await bot.send_message(chat_id, "❌ نتوانستم اینباند‌ها را دریافت کنم.")
                        await state.update_data(login_messages=[message.message_id])
                        await state.clear()
                        return
                await state.update_data(selected_inbounds=current_inbounds, available_inbounds=available_inbounds)
                message = await bot.send_message(chat_id, f"⚙️ انتخاب کانفیگ‌ها برای کاربر {username}:", reply_markup=config_selection_menu(available_inbounds, current_inbounds, username))
                await state.update_data(login_messages=[message.message_id])
        except Exception as e:
            logger.error(f"Error managing configs: {str(e)}")
            message = await bot.send_message(chat_id, f"❌ خطا: {str(e)}")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
    elif data.startswith("toggle_inbound:"):
        parts = data.split(":")
        if len(parts) == 3:
            inbound, username = parts[1], parts[2]
            data = await state.get_data()
            selected_inbounds = data.get("selected_inbounds", [])
            if inbound in selected_inbounds:
                selected_inbounds.remove(inbound)
            else:
                selected_inbounds.append(inbound)
            await state.update_data(selected_inbounds=selected_inbounds)
            available_inbounds = data.get("available_inbounds", [])
            message = await bot.send_message(chat_id, f"⚙️ انتخاب کانفیگ‌ها برای کاربر {username}:", reply_markup=config_selection_menu(available_inbounds, selected_inbounds, username))
            await state.update_data(login_messages=[message.message_id])
        else:
            await query.answer("❌ داده نامعتبر", show_alert=True)
    elif data.startswith("confirm_inbounds_for_existing:"):
        username = data.split(":", 1)[1]
        data = await state.get_data()
        selected_inbounds = data.get("selected_inbounds", [])
        selected_panel_alias = data.get("selected_panel_alias")
        if not selected_panel_alias:
            message = await bot.send_message(chat_id, "⚠️ لطفاً ابتدا یک پنل انتخاب کنید.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        panels = get_panels(chat_id)
        panel = next((p for p in panels if p[0] == selected_panel_alias), None)
        if not panel:
            message = await bot.send_message(chat_id, "⚠️ پنل انتخاب‌شده یافت نشد.")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        try:
            async with aiohttp.ClientSession() as session:
                headers = {"Authorization": f"Bearer {panel[2]}", "Content-Type": "application/json"}
                async with session.get(f"{panel[1].rstrip('/')}/api/user/{username}", headers=headers) as response:
                    if response.status == 200:
                        current_user = await response.json()
                    else:
                        message = await bot.send_message(chat_id, "❌ نتوانستم داده کاربر را دریافت کنم.")
                        await state.update_data(login_messages=[message.message_id])
                        await state.clear()
                        return
                inbounds_dict = {}
                for inbound in selected_inbounds:
                    protocol, tag = inbound.split(":")
                    if protocol not in inbounds_dict:
                        inbounds_dict[protocol] = []
                    inbounds_dict[protocol].append(tag)
                current_user["inbounds"] = inbounds_dict
                async with session.put(f"{panel[1].rstrip('/')}/api/user/{username}", json=current_user, headers=headers) as response:
                    if response.status == 200:
                        message = await bot.send_message(chat_id, f"✅ کانفیگ‌ها برای کاربر '{username}' با موفقیت به‌روزرسانی شد.")
                        await state.update_data(login_messages=[message.message_id])
                        await show_user_info(query, state, username, chat_id, selected_panel_alias, bot)
                    else:
                        result = await response.json()
                        message = await bot.send_message(chat_id, f"❌ خطا در به‌روزرسانی کانفیگ‌ها: {result.get('detail', 'No details')}")
                        await state.update_data(login_messages=[message.message_id])
            await state.clear()
        except Exception as e:
            logger.error(f"Error confirming inbounds: {str(e)}")
            message = await bot.send_message(chat_id, f"❌ خطا: {str(e)}")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
    elif data.startswith("delete_configs:"):
        username = data.split(":", 1)[1]
        await delete_configs_logic(query, state, username, chat_id, bot)
    elif data.startswith("regenerate_link:"):
        username = data.split(":", 1)[1]
        data = await state.get_data()
        selected_panel_alias = data.get("selected_panel_alias")
        if not selected_panel_alias:
            message = await bot.send_message(chat_id, "⚠️ لطفاً ابتدا یک پنل انتخاب کنید.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        panels = get_panels(chat_id)
        panel = next((p for p in panels if p[0] == selected_panel_alias), None)
        if not panel:
            message = await bot.send_message(chat_id, "⚠️ پنل انتخاب‌شده یافت نشد.")
            await state.update_data(login_messages=[message.message_id])
            return
        try:
            async with aiohttp.ClientSession() as session:
                headers = {"Authorization": f"Bearer {panel[2]}"}
                async with session.post(f"{panel[1].rstrip('/')}/api/user/{username}/revoke_sub", headers=headers) as response:
                    if response.status != 200:
                        result = await response.json()
                        message = await bot.send_message(chat_id, f"❌ خطا در لغو اشتراک: {result.get('detail', 'No details')}")
                        await state.update_data(login_messages=[message.message_id])
                        return
                async with session.get(f"{panel[1].rstrip('/')}/api/user/{username}", headers=headers) as response:
                    if response.status == 200:
                        user_data = await response.json()
                        subscription_url = user_data.get("subscription_url", None)
                        if subscription_url:
                            message = await bot.send_message(chat_id, f"🔄 لینک جدید برای کاربر '{username}':\n{subscription_url}")
                            await state.update_data(login_messages=[message.message_id])
                            await show_user_info(query, state, username, chat_id, selected_panel_alias, bot)
                        else:
                            message = await bot.send_message(chat_id, "❌ لینک اشتراک در دسترس نیست.")
                            await state.update_data(login_messages=[message.message_id])
                    else:
                        message = await bot.send_message(chat_id, "❌ نتوانستم داده کاربر را دریافت کنم.")
                        await state.update_data(login_messages=[message.message_id])
        except Exception as e:
            logger.error(f"Error regenerating link: {str(e)}")
            message = await bot.send_message(chat_id, f"❌ خطا: {str(e)}")
            await state.update_data(login_messages=[message.message_id])
    elif data.startswith("set_data_limit:"):
        username = data.split(":", 1)[1]
        await state.update_data(existing_username=username)
        await state.set_state(Form.awaiting_new_data_limit)
        message = await bot.send_message(chat_id, f"📊 حجم جدید (به گیگابایت) برای کاربر '{username}' را وارد کنید (برای نامحدود، 0 وارد کنید):")
        await state.update_data(login_messages=[message.message_id])
    elif data.startswith("set_expire_time:"):
        username = data.split(":", 1)[1]
        await state.update_data(existing_username=username)
        await state.set_state(Form.awaiting_new_expire_time)
        message = await bot.send_message(chat_id, f"⏰ زمان انقضای جدید (به روز) برای کاربر '{username}' را وارد کنید (برای نامحدود، 0 وارد کنید):")
        await state.update_data(login_messages=[message.message_id])
    elif data == "back_to_main":
        await state.clear()
        message = await bot.send_message(chat_id, "🏠 به منوی اصلی بازگشتید:", reply_markup=main_menu(is_owner(chat_id)))
        await state.update_data(login_messages=[message.message_id])

async def message_handler(message: types.Message, state: FSMContext, bot: Bot):
    chat_id = message.from_user.id
    text = message.text.lower() if message.text else ""
    current_state = await state.get_state()
    data = await state.get_data()
    login_messages = data.get("login_messages", [])
    login_messages.append(message.message_id)
    await state.update_data(login_messages=login_messages)
    await cleanup_messages(bot, chat_id, state)
    if current_state == Form.awaiting_add_admin.state:
        try:
            new_admin_id = int(text.strip())
            if new_admin_id in ADMIN_IDS:
                message = await bot.send_message(chat_id, "⚠️ این آیدی متعلق به مالک است و نمی‌تواند به عنوان مدیر اضافه شود.")
                await state.update_data(login_messages=[message.message_id])
                return
            add_admin(new_admin_id)
            message = await bot.send_message(chat_id, f"✅ مدیر با آیدی {new_admin_id} با موفقیت اضافه شد.", reply_markup=admin_management_menu())
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
        except ValueError:
            message = await bot.send_message(chat_id, "⚠️ لطفاً یک آیدی عددی معتبر وارد کنید.")
            await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_user_info.state:
        try:
            user_id = int(text.strip())
            await show_user_info_for_owner(message, state, user_id, bot)
        except ValueError:
            message = await bot.send_message(chat_id, "⚠️ لطفاً یک آیدی عددی معتبر وارد کنید.")
            await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_panel_alias.state:
        await state.update_data(panel_alias=text)
        await state.set_state(Form.awaiting_panel_url)
        message = await bot.send_message(chat_id, "🔗 لطفاً لینک پنل را ارسال کنید (مثلاً https://example.com):", reply_markup=panel_login_menu())
        await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_panel_url.state:
        if not validate_panel_url(text):
            message = await bot.send_message(chat_id, "⚠️ لطفاً آدرس پایه پنل را به درستی وارد کنید (مثلاً https://example.com).", reply_markup=panel_login_menu())
            await state.update_data(login_messages=[message.message_id])
            return
        if not await check_server_availability(text):
            message = await bot.send_message(chat_id, "❌ نمی‌توان به سرور متصل شد. لطفاً آدرس پنل یا اتصال اینترنت را بررسی کنید.", reply_markup=panel_login_menu())
            await state.update_data(login_messages=[message.message_id])
            return
        await state.update_data(panel_url=text)
        await state.set_state(Form.awaiting_username)
        message = await bot.send_message(chat_id, "👤 نام کاربری ادمین را وارد کنید:", reply_markup=panel_login_menu())
        await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_username.state:
        await state.update_data(admin_username=text)
        await state.set_state(Form.awaiting_password)
        message = await bot.send_message(chat_id, "🔑 رمز عبور ادمین را وارد کنید:", reply_markup=panel_login_menu())
        await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_password.state:
        data = await state.get_data()
        panel_url = data.get("panel_url")
        admin_username = data.get("admin_username")
        alias = data.get("panel_alias")
        password = message.text
        try:
            panel = Marzban(admin_username, password, panel_url)
            token_response = await panel.get_token()
            if not token_response or 'access_token' not in token_response:
                raise ValueError("احراز هویت ناموفق. لطفاً نام کاربری و رمز عبور را بررسی کنید.")
            token = token_response['access_token']
            save_panel(chat_id, alias, panel_url, token, admin_username, password)
            message = await bot.send_message(chat_id, f"✅ پنل '{alias}' با موفقیت اضافه شد!", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
        except Exception as e:
            logger.error(f"Authentication error: {str(e)}")
            message = await bot.send_message(chat_id, f"❌ خطا در ورود: {str(e)}", reply_markup=panel_login_menu())
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
    elif current_state == Form.awaiting_search_username.state:
        username = text
        if not username or len(username) < 3:
            message = await bot.send_message(chat_id, "⚠️ نام کاربری باید حداقل ۳ کاراکتر باشد.")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        data = await state.get_data()
        selected_panel_alias = data.get("selected_panel_alias")
        if not selected_panel_alias:
            message = await bot.send_message(chat_id, "⚠️ لطفاً ابتدا یک پنل انتخاب کنید.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        panels = get_panels(chat_id)
        panel = next((p for p in panels if p[0] == selected_panel_alias), None)
        if not panel:
            message = await bot.send_message(chat_id, "⚠️ پنل انتخاب‌شده یافت نشد.")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        try:
            async with aiohttp.ClientSession() as session:
                headers = {"Authorization": f"Bearer {panel[2]}"}
                async with session.get(f"{panel[1].rstrip('/')}/api/user/{username}", headers=headers, timeout=5) as response:
                    if response.status != 200:
                        result = await response.json()
                        message = await bot.send_message(chat_id, f"❌ خطا در جستجو: {result.get('detail', 'کاربر یافت نشد')}")
                        await state.update_data(login_messages=[message.message_id])
                        await state.clear()
                        return
                    user = await response.json()
                    response_text = (
                        f"👤 نام کاربری: {user['username']}\n"
                        f"📊 وضعیت: {user['status']}\n"
                        f"📈 حجم مصرفی: {format_traffic(user.get('used_traffic', 0))}\n"
                        f"📊 حجم کل: {format_traffic(user.get('data_limit', 0)) if user.get('data_limit') else 'نامحدود'}\n"
                        f"⏰ زمان انقضا: {format_expire_time(user.get('expire'))}\n"
                        f"📝 یادداشت: {user.get('note', 'هیچ')}\n"
                        f"🔗 لینک اشتراک: {user.get('subscription_url', 'ناموجود')}"
                    )
                    message = await bot.send_message(chat_id, response_text, reply_markup=user_action_menu(username))
                    await state.update_data(login_messages=[message.message_id])
        except Exception as e:
            logger.error(f"Search user error: {str(e)}")
            message = await bot.send_message(chat_id, f"❌ خطا در جستجو: {str(e)}")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
    elif current_state == Form.awaiting_create_username.state:
        if len(text) < 3:
            message = await bot.send_message(chat_id, "⚠️ نام کاربری باید حداقل ۳ کاراکتر باشد.")
            await state.update_data(login_messages=[message.message_id])
            return
        await state.update_data(username=text)
        await state.set_state(Form.awaiting_data_limit)
        message = await bot.send_message(chat_id, "📊 حجم (به گیگابایت) را وارد کنید (برای نامحدود، 0 وارد کنید):")
        await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_data_limit.state:
        try:
            data_limit = float(text.strip()) * 1e9 if float(text.strip()) > 0 else 0
            await state.update_data(data_limit=data_limit)
            await state.set_state(Form.awaiting_expire_time)
            message = await bot.send_message(chat_id, "⏰ زمان انقضا (به روز) را وارد کنید (برای نامحدود، 0 وارد کنید):")
            await state.update_data(login_messages=[message.message_id])
        except ValueError:
            message = await bot.send_message(chat_id, "⚠️ لطفاً یک عدد معتبر وارد کنید.")
            await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_expire_time.state:
        try:
            expire_days = int(text.strip())
            expire_time = int(datetime.now(timezone.utc).timestamp()) + expire_days * 86400 if expire_days > 0 else 0
            await state.update_data(expire_time=expire_time, expire_days=expire_days)
            await state.set_state(Form.awaiting_note)
            message = await bot.send_message(chat_id, "📝 یادداشت (اختیاری) را وارد کنید یا از دکمه زیر استفاده کنید:", reply_markup=note_menu())
            await state.update_data(login_messages=[message.message_id])
        except ValueError:
            message = await bot.send_message(chat_id, "⚠️ لطفاً یک عدد معتبر وارد کنید.")
            await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_note.state:
        note = text if text != "هیچ" else ""
        success_msg, error_msg = await create_user_logic(chat_id, state, note)
        if success_msg:
            message = await bot.send_message(chat_id, success_msg, reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
        else:
            message = await bot.send_message(chat_id, error_msg)
            await state.update_data(login_messages=[message.message_id])
        await state.clear()
    elif current_state == Form.awaiting_new_data_limit.state:
        data = await state.get_data()
        username = data.get("existing_username")
        selected_panel_alias = data.get("selected_panel_alias")
        if not selected_panel_alias:
            message = await bot.send_message(chat_id, "⚠️ لطفاً ابتدا یک پنل انتخاب کنید.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        panels = get_panels(chat_id)
        panel = next((p for p in panels if p[0] == selected_panel_alias), None)
        if not panel:
            message = await bot.send_message(chat_id, "⚠️ پنل انتخاب‌شده یافت نشد.")
            await state.update_data(login_messages=[message.message_id])
            return
        try:
            input_value = text.strip()
            new_data_limit = float(input_value) * 1e9 if float(input_value) > 0 else 0
            async with aiohttp.ClientSession() as session:
                headers = {"Authorization": f"Bearer {panel[2]}", "Content-Type": "application/json"}
                async with session.get(f"{panel[1].rstrip('/')}/api/user/{username}", headers=headers) as response:
                    if response.status == 200:
                        current_user = await response.json()
                    else:
                        message = await bot.send_message(chat_id, "❌ کاربر یافت نشد.")
                        await state.update_data(login_messages=[message.message_id])
                        return
                current_user["data_limit"] = new_data_limit
                if "status" not in current_user or current_user["status"] not in ["active", "disabled", "on_hold"]:
                    current_user["status"] = "active"
                logger.debug(f"Sending data to API: {current_user}")
                async with session.put(f"{panel[1].rstrip('/')}/api/user/{username}", json=current_user, headers=headers) as response:
                    if response.status == 200:
                        message = await bot.send_message(chat_id, f"✅ حجم کاربر '{username}' به {format_traffic(new_data_limit) if new_data_limit else 'نامحدود'} تنظیم شد.", reply_markup=user_action_menu(username))
                        await state.update_data(login_messages=[message.message_id])
                        await state.clear()
                    else:
                        result = await response.json()
                        message = await bot.send_message(chat_id, f"❌ خطا در تنظیم حجم: {result.get('detail', 'No details')}")
                        await state.update_data(login_messages=[message.message_id])
        except ValueError:
            message = await bot.send_message(chat_id, "⚠️ لطفاً یک عدد معتبر وارد کنید.")
            await state.update_data(login_messages=[message.message_id])
        except Exception as e:
            logger.error(f"Set data limit error: {str(e)}")
            message = await bot.send_message(chat_id, f"❌ خطا: {str(e)}")
            await state.update_data(login_messages=[message.message_id])
    elif current_state == Form.awaiting_new_expire_time.state:
        data = await state.get_data()
        username = data.get("existing_username")
        selected_panel_alias = data.get("selected_panel_alias")
        if not selected_panel_alias:
            message = await bot.send_message(chat_id, "⚠️ لطفاً ابتدا یک پنل انتخاب کنید.", reply_markup=main_menu(is_owner(chat_id)))
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        panels = get_panels(chat_id)
        panel = next((p for p in panels if p[0] == selected_panel_alias), None)
        if not panel:
            message = await bot.send_message(chat_id, "⚠️ پنل انتخاب‌شده یافت نشد.")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()
            return
        try:
            input_value = text.strip()
            new_expire_days = int(input_value)
            new_expire_time = int(datetime.now(timezone.utc).timestamp()) + new_expire_days * 86400 if new_expire_days > 0 else 0
            async with aiohttp.ClientSession() as session:
                headers = {"Authorization": f"Bearer {panel[2]}", "Content-Type": "application/json"}
                async with session.get(f"{panel[1].rstrip('/')}/api/user/{username}", headers=headers) as response:
                    if response.status == 200:
                        current_user = await response.json()
                    else:
                        message = await bot.send_message(chat_id, "❌ کاربر یافت نشد.")
                        await state.update_data(login_messages=[message.message_id])
                        await state.clear()
                        return
                current_user["expire"] = new_expire_time
                if "status" not in current_user or current_user["status"] not in ["active", "disabled", "on_hold"]:
                    current_user["status"] = "active"
                logger.debug(f"Sending data to API: {current_user}")
                async with session.put(f"{panel[1].rstrip('/')}/api/user/{username}", json=current_user, headers=headers) as response:
                    if response.status == 200:
                        message = await bot.send_message(chat_id, f"✅ زمان انقضای کاربر '{username}' به {new_expire_days if new_expire_days > 0 else 'نامحدود'} روز تنظیم شد.", reply_markup=user_action_menu(username))
                        await state.update_data(login_messages=[message.message_id])
                        await state.clear()
                    else:
                        result = await response.json()
                        message = await bot.send_message(chat_id, f"❌ خطا در تنظیم زمان انقضا: {result.get('detail', 'No details')}")
                        await state.update_data(login_messages=[message.message_id])
                        await state.clear()
        except ValueError:
            message = await bot.send_message(chat_id, "⚠️ لطفاً یک عدد معتبر وارد کنید.")
            await state.update_data(login_messages=[message.message_id])
        except Exception as e:
            logger.error(f"Set expire time error: {str(e)}")
            message = await bot.send_message(chat_id, f"❌ خطا: {str(e)}")
            await state.update_data(login_messages=[message.message_id])
            await state.clear()

async def check_server_availability(url: str) -> bool:
    try:
        hostname = url.split("://")[1].split("/")[0]
        socket.getaddrinfo(hostname, 443)
        async with aiohttp.ClientSession() as session:
            async with session.get(url, timeout=5, ssl=True) as response:
                return response.status < 500
    except (socket.gaierror, aiohttp.ClientConnectorError, asyncio.TimeoutError) as e:
        logger.error(f"Server check failed for {url}: {str(e)}")
        return False