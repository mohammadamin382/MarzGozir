import logging
from aiogram import Bot

logger = logging.getLogger(__name__)

async def cleanup_messages(bot: Bot, chat_id: int, state):
    data = await state.get_data()
    login_messages = data.get("login_messages", [])
    async def delete_message(message_id: int):
        try:
            await bot.delete_message(chat_id=chat_id, message_id=message_id)
        except Exception as e:
            logger.warning(f"Failed to delete message {message_id}: {str(e)}")
    await asyncio.gather(*[delete_message(message_id) for message_id in login_messages])
    await state.update_data(login_messages=[])