import psycopg

from atorders.config import database_settings


def get_connection() -> psycopg.Connection:
    return psycopg.connect(
        dbname=database_settings.database,
        user=database_settings.user,
        password=database_settings.password,
        host=database_settings.host,
        port=database_settings.port,
    )
