import asyncio
import logging
from aiogram import Bot
from aiogram.fsm.context import FSMContext

logger = logging.getLogger(__name__)

async def cleanup_messages(bot: Bot, chat_id: int, state: FSMContext):
    data = await state.get_data()
    login_messages = data.get("login_messages", [])
    async def delete_message(message_id: int, retries=3):
        for attempt in range(retries):
            try:
                await bot.delete_message(chat_id=chat_id, message_id=message_id)
                return
            except Exception as e:
                logger.warning(f"Failed to delete message {message_id} (attempt {attempt+1}): {str(e)}")
                if attempt < retries - 1:
                    await asyncio.sleep(1)  # Wait before retrying
    await asyncio.gather(*[delete_message(message_id) for message_id in login_messages], return_exceptions=True)
    await state.update_data(login_messages=[])
