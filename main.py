import logging
import telebot
from telebot import types
from bot.handlers import TelebotHandlers
from bot_config import TOKEN
import threading
import time
from database.db import init_db

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    bot = telebot.TeleBot(TOKEN)
    handlers = TelebotHandlers(bot)
    
    # Register handlers
    @bot.message_handler(commands=['start'])
    def start_handler(message):
        handlers.start(message)
    
    @bot.callback_query_handler(func=lambda call: True)
    def callback_handler(call):
        handlers.button_callback(call)
    
    @bot.message_handler(func=lambda message: True, content_types=['text'])
    def message_handler(message):
        handlers.message_handler(message)
    
    try:
        logger.info("Starting bot...")
        bot.infinity_polling(none_stop=True, interval=0)
    except Exception as e:
        logger.error(f"Bot error: {e}")
        time.sleep(15)
        main()

if __name__ == "__main__":
    init_db()
    main()
