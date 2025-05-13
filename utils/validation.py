def validate_panel_url(url: str) -> bool:
    if not (url.startswith("http://") or url.startswith("https://")):
        return False
    parts = url.split("://")[1].split("/")
    return len(parts) <= 1 or not parts[1]