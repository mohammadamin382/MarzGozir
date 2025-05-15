import logging
from datetime import datetime, timezone
from aiogram import Bot
from database.db import get_log_channel

logger = logging.getLogger(__name__)

async def log_to_channel(bot: Bot, chat_id: int, action: str, details: str = ""):
    channel_id = get_log_channel()
    if not channel_id:
        logger.warning("No log channel set. Skipping log.")
        return
    try:
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        message = (
            f"📋 گزارش فعالیت:\n"
            f"👤 ادمین: {chat_id}\n"
            f"🛠 فعالیت: {action}\n"
            f"ℹ️ جزئیات: {details}\n"
            f"⏰ زمان: {timestamp}"
        )
        await bot.send_message(chat_id=channel_id, text=message)
        logger.info(f"Logged action '{action}' by admin {chat_id} to channel {channel_id}")
    except Exception as e:
        logger.error(f"Failed to log to channel {channel_id}: {str(e)}")
