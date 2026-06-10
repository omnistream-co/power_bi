from sqlalchemy import create_engine
from pathlib import Path
import yaml
from urllib import parse

PROJECT_DIR = Path(__file__).resolve().parents[1]


def load_secrets(env: str) -> dict:
    """Load secrets from secrets.yml."""
    secrets_path = PROJECT_DIR / "secrets.yml"
    if not secrets_path.exists():
        raise FileNotFoundError(f"Secrets file not found: {secrets_path}")

    with open(secrets_path, "r") as f:
        secrets = yaml.safe_load(f)

    env_secrets = secrets.get(env.upper())
    if not env_secrets:
        raise ValueError(f"No secrets found for environment '{env}'")

    return env_secrets


def get_connection(env: str, database: str):
    env_secrets = load_secrets(env)

    user = env_secrets["user"]
    host = env_secrets["host"]
    port = env_secrets["port"]
    password_original = env_secrets["password_original"]

    password = parse.quote(password_original)

    connection_string = (
        f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}"
    )

    return create_engine(
        connection_string,
        pool_pre_ping=True,
    )
