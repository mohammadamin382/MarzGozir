import sqlite3
import logging
import os
from bot_config import DB_PATH  

logger = logging.getLogger(__name__)

def ensure_db_directory():
    """Ensure the directory for the database file exists."""
    db_dir = os.path.dirname(DB_PATH)
    if db_dir:  
        try:
            os.makedirs(db_dir, exist_ok=True)
            logger.info(f"Database directory ensured: {db_dir}")
        except OSError as e:
            logger.error(f"Failed to create database directory {db_dir}: {e}")
            raise

def init_db():
    """Initialize the SQLite database and create necessary tables."""
    try:
        ensure_db_directory()
        conn = sqlite3.connect(DB_PATH)
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
        logger.info(f"Database initialized successfully at {DB_PATH}")
    except sqlite3.Error as e:
        logger.error(f"Database initialization error: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error during database initialization: {e}")
        raise
    finally:
        if 'conn' in locals():
            conn.close()

def save_panel(chat_id: int, alias: str, panel_url: str, token: str, username: str, password: str):
    """Save or update a panel in the database."""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('''
            INSERT OR REPLACE INTO panels (chat_id, alias, panel_url, token, username, password)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (chat_id, alias, panel_url, token, username, password))
        conn.commit()
        logger.info(f"Panel saved for chat_id {chat_id}, alias {alias}")
    except sqlite3.Error as e:
        logger.error(f"Error saving panel for chat_id {chat_id}, alias {alias}: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

def get_panels(chat_id: int) -> list:
    """Retrieve all panels for a given chat_id."""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('SELECT alias, panel_url, token, username, password FROM panels WHERE chat_id = ?', (chat_id,))
        panels = c.fetchall()
        logger.info(f"Fetched {len(panels)} panels for chat_id {chat_id}")
        return panels
    except sqlite3.Error as e:
        logger.error(f"Error fetching panels for chat_id {chat_id}: {e}")
        return []
    finally:
        if 'conn' in locals():
            conn.close()

def delete_panel(chat_id: int, alias: str):
    """Delete a panel from the database."""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('DELETE FROM panels WHERE chat_id = ? AND alias = ?', (chat_id, alias))
        conn.commit()
        logger.info(f"Panel deleted for chat_id {chat_id}, alias {alias}")
    except sqlite3.Error as e:
        logger.error(f"Error deleting panel for chat_id {chat_id}, alias {alias}: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

def add_admin(chat_id: int):
    """Add a chat_id to the admins table."""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('INSERT OR IGNORE INTO admins (chat_id) VALUES (?)', (chat_id,))
        conn.commit()
        logger.info(f"Admin added: chat_id {chat_id}")
    except sqlite3.Error as e:
        logger.error(f"Error adding admin chat_id {chat_id}: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

def remove_admin(chat_id: int):
    """Remove a chat_id from the admins table."""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('DELETE FROM admins WHERE chat_id = ?', (chat_id,))
        conn.commit()
        logger.info(f"Admin removed: chat_id {chat_id}")
    except sqlite3.Error as e:
        logger.error(f"Error removing admin chat_id {chat_id}: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

def get_admins() -> list:
    """Retrieve all admin chat_ids."""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('SELECT chat_id FROM admins')
        admins = [row[0] for row in c.fetchall()]
        logger.info(f"Fetched {len(admins)} admins")
        return admins
    except sqlite3.Error as e:
        logger.error(f"Error fetching admins: {e}")
        return []
    finally:
        if 'conn' in locals():
            conn.close()

def set_log_channel(channel_id: int):
    """Set the log channel ID."""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('INSERT OR REPLACE INTO log_channel (id, channel_id) VALUES (1, ?)', (channel_id,))
        conn.commit()
        logger.info(f"Log channel set to {channel_id}")
    except sqlite3.Error as e:
        logger.error(f"Error setting log channel {channel_id}: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

def get_log_channel() -> int:
    """Retrieve the log channel ID."""
    try:
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        c.execute('SELECT channel_id FROM log_channel WHERE id = 1')
        result = c.fetchone()
        channel_id = result[0] if result else None
        logger.info(f"Fetched log channel: {channel_id}")
        return channel_id
    except sqlite3.Error as e:
        logger.error(f"Error fetching log channel: {e}")
        return None
    finally:
        if 'conn' in locals():
            conn.close()

try:
    init_db()
except Exception as e:
    logger.error(f"Failed to initialize database on startup: {e}")
