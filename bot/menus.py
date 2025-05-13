from aiogram.types import InlineKeyboardButton, InlineKeyboardMarkup

def create_menu_layout(buttons: list) -> InlineKeyboardMarkup:
    keyboard = []
    if not buttons:
        return InlineKeyboardMarkup(inline_keyboard=keyboard)
    if len(buttons) >= 1:
        keyboard.append([buttons[0]])
    if len(buttons) > 2:
        middle_buttons = buttons[1:-1]
        for i in range(0, len(middle_buttons), 2):
            row = [middle_buttons[i]]
            if i + 1 < len(middle_buttons):
                row.append(middle_buttons[i + 1])
            keyboard.append(row)
    if len(buttons) >= 2:
        keyboard.append([buttons[-1]])
    return InlineKeyboardMarkup(inline_keyboard=keyboard)

def main_menu(is_owner: bool = False) -> InlineKeyboardMarkup:
    buttons = [
        InlineKeyboardButton(text="📋 مدیریت پنل‌ها", callback_data="manage_panels"),
        InlineKeyboardButton(text="➕ افزودن پنل جدید", callback_data="add_server")
    ]
    if is_owner:
        buttons.append(InlineKeyboardButton(text="👨‍💼 مدیریت مدیران", callback_data="manage_admins"))
    return create_menu_layout(buttons)

def admin_management_menu() -> InlineKeyboardMarkup:
    buttons = [
        InlineKeyboardButton(text="➕ افزودن مدیر", callback_data="add_admin"),
        InlineKeyboardButton(text="🗑 حذف مدیر", callback_data="remove_admin"),
        InlineKeyboardButton(text="📊 اطلاعات کاربر", callback_data="user_info"),
        InlineKeyboardButton(text="🔙 بازگشت به منوی اصلی", callback_data="back_to_main")
    ]
    return create_menu_layout(buttons)

def panel_selection_menu(panels: list) -> InlineKeyboardMarkup:
    buttons = [
        InlineKeyboardButton(text=f"📌 {alias}", callback_data=f"select_panel:{alias}")
        for alias, _, _, _, _ in panels
    ]
    buttons.append(InlineKeyboardButton(text="🗑 حذف پنل", callback_data="delete_panel"))
    buttons.append(InlineKeyboardButton(text="🔙 بازگشت به منوی اصلی", callback_data="back_to_main"))
    return create_menu_layout(buttons)

def panel_action_menu() -> InlineKeyboardMarkup:
    buttons = [
        InlineKeyboardButton(text="🔍 جستجوی کاربر", callback_data="search_user"),
        InlineKeyboardButton(text="🪐 ایجاد کاربر", callback_data="create_user"),
        InlineKeyboardButton(text="⬅️ بازگشت به انتخاب پنل", callback_data="back_to_panel_selection"),
        InlineKeyboardButton(text="🔙 بازگشت به منوی اصلی", callback_data="back_to_main")
    ]
    return create_menu_layout(buttons)

def user_action_menu(username: str) -> InlineKeyboardMarkup:
    buttons = [
        InlineKeyboardButton(text="🗑 حذف کاربر", callback_data=f"delete_user:{username}"),
        InlineKeyboardButton(text="⏹ غیرفعال کردن", callback_data=f"disable_user:{username}"),
        InlineKeyboardButton(text="▶️ فعال کردن", callback_data=f"enable_user:{username}"),
        InlineKeyboardButton(text="📊 تنظیم حجم", callback_data=f"set_data_limit:{username}"),
        InlineKeyboardButton(text="⏰ تنظیم زمان انقضا", callback_data=f"set_expire_time:{username}"),
        InlineKeyboardButton(text="⚙️ مدیریت کانفیگ‌ها", callback_data=f"manage_configs:{username}"),
        InlineKeyboardButton(text="🗑 حذف همه کانفیگ‌ها", callback_data=f"delete_configs:{username}"),
        InlineKeyboardButton(text="🔄 تولید لینک جدید", callback_data=f"regenerate_link:{username}"),
        InlineKeyboardButton(text="🔙 بازگشت به منوی اصلی", callback_data="back_to_main")
    ]
    return create_menu_layout(buttons)

def config_selection_menu(inbounds: list, selected_inbounds: list, username: str) -> InlineKeyboardMarkup:
    buttons = []
    for inbound in inbounds:
        text = f"🔘 {inbound}" if inbound in selected_inbounds else f"⚪ {inbound}"
        buttons.append(InlineKeyboardButton(text=text, callback_data=f"toggle_inbound:{inbound}:{username}"))
    buttons.append(InlineKeyboardButton(text="✅ تأیید", callback_data=f"confirm_inbounds_for_existing:{username}"))
    return create_menu_layout(buttons)

def panel_login_menu() -> InlineKeyboardMarkup:
    buttons = [
        InlineKeyboardButton(text="🔙 بازگشت به منوی اصلی", callback_data="back_to_main")
    ]
    return create_menu_layout(buttons)

def note_menu() -> InlineKeyboardMarkup:
    buttons = [
        InlineKeyboardButton(text="📝 None", callback_data="set_note_none")
    ]
    return create_menu_layout(buttons)

def delete_panel_menu(panels: list) -> InlineKeyboardMarkup:
    buttons = [
        InlineKeyboardButton(text=f"🗑 {alias}", callback_data=f"confirm_delete_panel:{alias}")
        for alias, _, _, _, _ in panels
    ]
    buttons.append(InlineKeyboardButton(text="⬅️ بازگشت به انتخاب پنل", callback_data="back_to_panel_selection"))
    buttons.append(InlineKeyboardButton(text="🔙 بازگشت به منوی اصلی", callback_data="back_to_main"))
    return create_menu_layout(buttons)