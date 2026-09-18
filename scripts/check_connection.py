from atorders.database import get_connection


def main() -> None:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    current_database(),
                    current_user,
                    current_setting('TimeZone')
                """
            )
            database, user, timezone = cursor.fetchone()

    print("PostgreSQL connection successful.")
    print(f"Database: {database}")
    print(f"User: {user}")
    print(f"Timezone: {timezone}")


if __name__ == "__main__":
    main()
