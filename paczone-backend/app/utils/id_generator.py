import time
import uuid


def new_zone_id() -> str:
    return f"zone_{int(time.time())}_{uuid.uuid4().hex[:6]}"


def new_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:8]}"
