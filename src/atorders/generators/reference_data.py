from atorders.database import get_connection

WAREHOUSES = (
    (
        "CD-SE-01",
        "Centro de Distribuição Campinas",
        "Campinas",
        "SP",
        "southeast",
        "active",
    ),
    (
        "CD-SE-02",
        "Centro de Distribuição Contagem",
        "Contagem",
        "MG",
        "southeast",
        "active",
    ),
    (
        "CD-NE-01",
        "Centro de Distribuição Jaboatão",
        "Jaboatão dos Guararapes",
        "PE",
        "northeast",
        "active",
    ),
    (
        "CD-S-01",
        "Centro de Distribuição Joinville",
        "Joinville",
        "SC",
        "south",
        "active",
    ),
)

CARRIERS = (
    ("CAR-001", "Rota Certa Transportes", "active"),
    ("CAR-002", "ViaSul Logística", "active"),
    ("CAR-003", "Expresso Horizonte", "active"),
    ("CAR-004", "Conecta Cargas", "active"),
    ("CAR-005", "Nordeste Express", "active"),
    ("CAR-006", "Movecta Transportes", "active"),
)


def load_reference_data() -> tuple[int, int]:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.executemany(
                """
                INSERT INTO ecommerce.warehouses (
                    warehouse_code,
                    warehouse_name,
                    city,
                    state,
                    region,
                    status
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (warehouse_code)
                DO UPDATE SET
                    warehouse_name = EXCLUDED.warehouse_name,
                    city = EXCLUDED.city,
                    state = EXCLUDED.state,
                    region = EXCLUDED.region,
                    status = EXCLUDED.status
                """,
                WAREHOUSES,
            )

            cursor.executemany(
                """
                INSERT INTO ecommerce.carriers (
                    carrier_code,
                    carrier_name,
                    status
                )
                VALUES (%s, %s, %s)
                ON CONFLICT (carrier_code)
                DO UPDATE SET
                    carrier_name = EXCLUDED.carrier_name,
                    status = EXCLUDED.status
                """,
                CARRIERS,
            )

            cursor.execute(
                """
                SELECT
                    (SELECT COUNT(*) FROM ecommerce.warehouses),
                    (SELECT COUNT(*) FROM ecommerce.carriers)
                """
            )
            warehouse_count, carrier_count = cursor.fetchone()

    return warehouse_count, carrier_count
