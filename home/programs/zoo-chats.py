"""Read-only snapshots from Zoo's native Task Board, including freshness."""
import json, time
from pathlib import Path

def list_chats(roots=None, now_ms=None):
    now_ms = time.time() * 1000 if now_ms is None else now_ms
    if roots is None:
        h = Path.home()
        roots = [h / ".vscode-server/data/User/globalStorage/zoocodeorganization.zoo-code", h / ".config/Code/User/globalStorage/zoocodeorganization.zoo-code", h / "Library/Application Support/Code/User/globalStorage/zoocodeorganization.zoo-code"]
    boards, errors = [], []
    for root in map(Path, roots):
        files = sorted((root / "task-boards").glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:10]
        for path in files:
            try:
                if path.stat().st_size > 4_000_000:
                    raise ValueError("Snapshot exceeds 4 MB")
                data = json.loads(path.read_text())
                age = max(0, now_ms - data["updatedAt"])
                boards.append({"board_id": data["boardId"], "updated_at_ms": data["updatedAt"], "age_ms": round(age), "stale": age > 20000, "tasks": data["tasks"][:200], "snapshot": str(path)})
            except (OSError, ValueError, KeyError, TypeError) as error:
                errors.append({"snapshot": str(path), "error": str(error)[:200]})
    return {"boards": boards, "errors": errors, "note": "Open Zoo: Show Task Board once in each VS Code window to publish live five-second snapshots. Stale boards do not prove any task is still running. Closed chats remain in Zoo History."}
