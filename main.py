import asyncio
import logging
from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from aiogram.filters import Command
from bot.handlers import start, button_callback, message_handler
from bot_config import TOKEN, VERSION
from database.db import init_db
from bot_logger import setup_logging

async def main():
    setup_logging()
    init_db()
    bot = Bot(token=TOKEN, default=DefaultBotProperties(parse_mode='HTML'))
    dp = Dispatcher()
    dp.message.register(start, Command("start"))
    dp.callback_query.register(button_callback)
    dp.message.register(message_handler)
    logging.info(f"Starting bot (version {VERSION})")
    try:
        await dp.start_polling(bot)
    except Exception as e:
        logging.error(f"Polling error: {str(e)}")

if __name__ == "__main__":
    asyncio.run(main())