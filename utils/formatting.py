from datetime import datetime, timezone

def format_expire_time(expire_timestamp: int) -> str:
    if not expire_timestamp:
        return "بدون انقضا 🕒"
    expire_date = datetime.fromtimestamp(expire_timestamp, tz=timezone.utc)
    now = datetime.now(timezone.utc)
    days_left = (expire_date - now).days
    return f"{days_left} روز 📅" if days_left >= 0 else "منقضی شده ⛔"

def format_traffic(traffic: int) -> str:
    return f"{traffic / 1e9:.2f} GB 📊"