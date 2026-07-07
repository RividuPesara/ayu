import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.chatbot_engine import SYSTEM_PROMPT, _SYSTEM_PROMPT_NAME
from app.core.langfuse_client import get_langfuse_client, initialize_langfuse


def main() -> None:
    initialize_langfuse()
    client = get_langfuse_client()
    if client is None:
        raise SystemExit(
            "Langfuse is not configured (check LANGFUSE_PUBLIC_KEY/LANGFUSE_SECRET_KEY in .env)."
        )

    client.create_prompt(
        name=_SYSTEM_PROMPT_NAME,
        prompt=SYSTEM_PROMPT,
        labels=["production"],
        type="text",
        commit_message="Seeded from chatbot_engine.py",
    )
    print(f"Pushed prompt '{_SYSTEM_PROMPT_NAME}' to Langfuse with label 'production'.")

if __name__ == "__main__":
    main()
