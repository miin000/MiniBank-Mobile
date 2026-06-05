from pathlib import Path


def repair(text: str) -> str:
    previous = None
    current = text
    while previous != current:
        previous = current
        current = current.encode("cp1252", errors="ignore").decode("utf-8", errors="ignore")
    return current


path = Path("lib/screens/home_screen.dart")
content = path.read_text(encoding="utf-8")
path.write_text(repair(content), encoding="utf-8", newline="")