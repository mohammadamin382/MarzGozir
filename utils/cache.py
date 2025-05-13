from datetime import datetime, timezone

users_stats_cache = {}

def get_users_stats_cache(panel_url: str, token: str, cache_duration: int) -> dict:
    global users_stats_cache
    cache_key = f"{panel_url}:{token}"
    if cache_key in users_stats_cache:
        cache_entry = users_stats_cache[cache_key]
        if (datetime.now(timezone.utc) - cache_entry["timestamp"]).total_seconds() < cache_duration:
            return cache_entry["stats"]
    return None

def set_users_stats_cache(panel_url: str, token: str, stats: dict):
    global users_stats_cache
    cache_key = f"{panel_url}:{token}"
    users_stats_cache[cache_key] = {
        "stats": stats,
        "timestamp": datetime.now(timezone.utc)
    }