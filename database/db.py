import sqlite3
from bot_config import DB_PATH

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS panels
                 (chat_id INTEGER, alias TEXT, panel_url TEXT, token TEXT, username TEXT, password TEXT, PRIMARY KEY (chat_id, alias))''')
    c.execute('''CREATE TABLE IF NOT EXISTS admins
                 (chat_id INTEGER PRIMARY KEY)''')
    conn.commit()
    conn.close()

def get_panels(chat_id: int) -> list:
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT alias, panel_url, token, username, password FROM panels WHERE chat_id = ?", (chat_id,))
    result = c.fetchall()
    conn.close()
    return result

def save_panel(chat_id: int, alias: str, panel_url: str, token: str, username: str, password: str):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("INSERT OR REPLACE INTO panels (chat_id, alias, panel_url, token, username, password) VALUES (?, ?, ?, ?, ?, ?)",
              (chat_id, alias.lower(), panel_url, token, username, password))
    conn.commit()
    conn.close()

def delete_panel(chat_id: int, alias: str):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("DELETE FROM panels WHERE chat_id = ? AND alias = ?", (chat_id, alias))
    conn.commit()
    conn.close()

def add_admin(chat_id: int):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("INSERT OR IGNORE INTO admins (chat_id) VALUES (?)", (chat_id,))
    conn.commit()
    conn.close()

def remove_admin(chat_id: int):
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("DELETE FROM admins WHERE chat_id = ?", (chat_id,))
    conn.commit()
    conn.close()

def get_admins() -> list:
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT chat_id FROM admins")
    result = c.fetchall()
    conn.close()
    return [row[0] for row in result]
