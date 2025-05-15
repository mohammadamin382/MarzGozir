import logging
from aiogram import Bot, Dispatcher
from aiogram.filters import Command
from bot.handlers import start, button_callback, message_handler
from bot_config import TOKEN

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def main():
    bot = Bot(token=TOKEN)
    dp = Dispatcher()
    
    dp.message.register(start, Command(commands=["start"]))
    dp.callback_query.register(button_callback)
    dp.message.register(message_handler)
    try:
        logger.info("Starting bot...")
        await dp.start_polling(bot)
    finally:
        await bot.session.close()

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
