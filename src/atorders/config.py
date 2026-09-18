import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class DatabaseSettings:
    database: str
    user: str
    password: str
    host: str
    port: int

    @classmethod
    def from_environment(cls) -> "DatabaseSettings":
        return cls(
            database=os.environ["POSTGRES_DB"],
            user=os.environ["POSTGRES_USER"],
            password=os.environ["POSTGRES_PASSWORD"],
            host=os.getenv("POSTGRES_HOST", "localhost"),
            port=int(os.getenv("POSTGRES_PORT", "5434")),
        )


database_settings = DatabaseSettings.from_environment()
