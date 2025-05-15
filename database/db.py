import sqlite3
import logging

logger = logging.getLogger(__name__)

def init_db():
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('''
            CREATE TABLE IF NOT EXISTS panels (
                chat_id INTEGER,
                alias TEXT,
                panel_url TEXT,
                token TEXT,
                username TEXT,
                password TEXT,
                PRIMARY KEY (chat_id, alias)
            )
        ''')
        c.execute('''
            CREATE TABLE IF NOT EXISTS admins (
                chat_id INTEGER PRIMARY KEY
            )
        ''')
        c.execute('''
            CREATE TABLE IF NOT EXISTS log_channel (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                channel_id INTEGER UNIQUE
            )
        ''')
        conn.commit()
    except sqlite3.Error as e:
        logger.error(f"Database initialization error: {e}")
    finally:
        conn.close()

def save_panel(chat_id: int, alias: str, panel_url: str, token: str, username: str, password: str):
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('''
            INSERT OR REPLACE INTO panels (chat_id, alias, panel_url, token, username, password)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (chat_id, alias, panel_url, token, username, password))
        conn.commit()
    except sqlite3.Error as e:
        logger.error(f"Error saving panel: {e}")
    finally:
        conn.close()

def get_panels(chat_id: int) -> list:
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('SELECT alias, panel_url, token, username, password FROM panels WHERE chat_id = ?', (chat_id,))
        panels = c.fetchall()
        return panels
    except sqlite3.Error as e:
        logger.error(f"Error fetching panels: {e}")
        return []
    finally:
        conn.close()

def delete_panel(chat_id: int, alias: str):
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('DELETE FROM panels WHERE chat_id = ? AND alias = ?', (chat_id, alias))
        conn.commit()
    except sqlite3.Error as e:
        logger.error(f"Error deleting panel: {e}")
    finally:
        conn.close()

def add_admin(chat_id: int):
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('INSERT OR IGNORE INTO admins (chat_id) VALUES (?)', (chat_id,))
        conn.commit()
    except sqlite3.Error as e:
        logger.error(f"Error adding admin: {e}")
    finally:
        conn.close()

def remove_admin(chat_id: int):
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('DELETE FROM admins WHERE chat_id = ?', (chat_id,))
        conn.commit()
    except sqlite3.Error as e:
        logger.error(f"Error removing admin: {e}")
    finally:
        conn.close()

def get_admins() -> list:
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('SELECT chat_id FROM admins')
        admins = [row[0] for row in c.fetchall()]
        return admins
    except sqlite3.Error as e:
        logger.error(f"Error fetching admins: {e}")
        return []
    finally:
        conn.close()

def set_log_channel(channel_id: int):
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('INSERT OR REPLACE INTO log_channel (id, channel_id) VALUES (1, ?)', (channel_id,))
        conn.commit()
        logger.info(f"Log channel set to {channel_id}")
    except sqlite3.Error as e:
        logger.error(f"Error setting log channel: {e}")
    finally:
        conn.close()

def get_log_channel() -> int:
    try:
        conn = sqlite3.connect('database.db')
        c = conn.cursor()
        c.execute('SELECT channel_id FROM log_channel WHERE id = 1')
        result = c.fetchone()
        return result[0] if result else None
    except sqlite3.Error as e:
        logger.error(f"Error fetching log channel: {e}")
        return None
    finally:
        conn.close()
