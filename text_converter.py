import os

EXCLUDE = {".git", "__pycache__", "node_modules"}
OUTPUT_FILE = "repository_dump.txt"

with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in EXCLUDE]

        for file in files:
            path = os.path.join(root, file)

            # Skip the output file itself
            if os.path.abspath(path) == os.path.abspath(OUTPUT_FILE):
                continue

            out.write(f"\n{'=' * 80}\n")
            out.write(f"# {path}\n")
            out.write(f"{'=' * 80}\n\n")

            try:
                with open(path, "r", encoding="utf-8") as f:
                    out.write(f.read())
            except Exception:
                out.write("<binary file>")

            out.write("\n\n")

print(f"Repository contents written to {OUTPUT_FILE}")