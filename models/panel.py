from dataclasses import dataclass

@dataclass
class Panel:
    chat_id: int
    alias: str
    panel_url: str
    token: str
    username: str
    password: str

@dataclass
class Admin:
    chat_id: int