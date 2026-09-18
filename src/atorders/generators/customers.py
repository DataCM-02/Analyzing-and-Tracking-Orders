from datetime import UTC, datetime, timedelta
from random import Random

from atorders.database import get_connection

CUSTOMER_COUNT = 2_000
DEFAULT_SEED = 360
REFERENCE_DATETIME = datetime(2026, 9, 1, tzinfo=UTC)

LOCATIONS = (
    ("Campinas", "SP", "southeast"),
    ("São Paulo", "SP", "southeast"),
    ("Rio de Janeiro", "RJ", "southeast"),
    ("Belo Horizonte", "MG", "southeast"),
    ("Vitória", "ES", "southeast"),
    ("Curitiba", "PR", "south"),
    ("Joinville", "SC", "south"),
    ("Porto Alegre", "RS", "south"),
    ("Recife", "PE", "northeast"),
    ("Salvador", "BA", "northeast"),
    ("Fortaleza", "CE", "northeast"),
    ("Goiânia", "GO", "central_west"),
    ("Brasília", "DF", "central_west"),
    ("Cuiabá", "MT", "central_west"),
    ("Manaus", "AM", "north"),
    ("Belém", "PA", "north"),
)

COMPANY_PREFIXES = (
    "Aliança",
    "Atlas",
    "Central",
    "Horizonte",
    "Integra",
    "Nacional",
    "Nova Era",
    "Pioneira",
    "Prime",
    "Vértice",
)

COMPANY_ACTIVITIES = (
    "Atacado",
    "Comercial",
    "Distribuição",
    "Equipamentos",
    "Indústria",
    "Materiais",
    "Serviços Empresariais",
    "Soluções",
    "Suprimentos",
    "Tecnologia",
)

LEGAL_SUFFIXES = (
    "Ltda.",
    "S.A.",
    "Comércio e Serviços Ltda.",
)


def _random_datetime(
    randomizer: Random,
    start: datetime,
    end: datetime,
) -> datetime:
    interval_seconds = int((end - start).total_seconds())
    return start + timedelta(seconds=randomizer.randint(0, interval_seconds))


def build_customers(
    count: int = CUSTOMER_COUNT,
    seed: int = DEFAULT_SEED,
) -> list[dict[str, object]]:
    randomizer = Random(seed)
    first_created_at = datetime(2023, 1, 1, tzinfo=UTC)
    last_created_at = REFERENCE_DATETIME - timedelta(days=30)

    customers: list[dict[str, object]] = []

    for customer_number in range(1, count + 1):
        city, state, region = randomizer.choice(LOCATIONS)

        created_at = _random_datetime(
            randomizer,
            first_created_at,
            last_created_at,
        )
        updated_at = _random_datetime(
            randomizer,
            created_at,
            REFERENCE_DATETIME,
        )

        company_name = " ".join(
            (
                randomizer.choice(COMPANY_PREFIXES),
                randomizer.choice(COMPANY_ACTIVITIES),
                f"{customer_number:04d}",
                randomizer.choice(LEGAL_SUFFIXES),
            )
        )

        segment = randomizer.choices(
            ("small", "medium", "enterprise"),
            weights=(60, 30, 10),
            k=1,
        )[0]

        status = randomizer.choices(
            ("active", "inactive", "blocked"),
            weights=(96, 3, 1),
            k=1,
        )[0]

        customers.append(
            {
                "customer_code": f"CUST-{customer_number:06d}",
                "company_name": company_name,
                "segment": segment,
                "status": status,
                "city": city,
                "state": state,
                "region": region,
                "created_at": created_at,
                "updated_at": updated_at,
            }
        )

    return customers


def load_customers(
    count: int = CUSTOMER_COUNT,
    seed: int = DEFAULT_SEED,
) -> int:
    customers = build_customers(count=count, seed=seed)

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.executemany(
                """
                INSERT INTO ecommerce.customers (
                    customer_code,
                    company_name,
                    segment,
                    status,
                    city,
                    state,
                    region,
                    created_at,
                    updated_at
                )
                VALUES (
                    %(customer_code)s,
                    %(company_name)s,
                    %(segment)s,
                    %(status)s,
                    %(city)s,
                    %(state)s,
                    %(region)s,
                    %(created_at)s,
                    %(updated_at)s
                )
                ON CONFLICT (customer_code)
                DO UPDATE SET
                    company_name = EXCLUDED.company_name,
                    segment = EXCLUDED.segment,
                    status = EXCLUDED.status,
                    city = EXCLUDED.city,
                    state = EXCLUDED.state,
                    region = EXCLUDED.region,
                    created_at = EXCLUDED.created_at,
                    updated_at = EXCLUDED.updated_at
                """,
                customers,
            )

            cursor.execute("SELECT COUNT(*) FROM ecommerce.customers")
            customer_count = cursor.fetchone()[0]

    return customer_count
