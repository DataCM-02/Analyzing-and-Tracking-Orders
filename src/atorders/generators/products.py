from datetime import UTC, datetime, timedelta
from decimal import Decimal
from random import Random

from atorders.database import get_connection

PRODUCT_COUNT = 800
DEFAULT_SEED = 360
REFERENCE_DATETIME = datetime(2026, 9, 1, tzinfo=UTC)

CATEGORY_CONFIG = {
    "office_supplies": {
        "names": (
            "Papel A4",
            "Caderno Executivo",
            "Caneta Esferográfica",
            "Marcador Permanente",
            "Pasta Arquivo",
            "Grampeador",
        ),
        "price_range": (3.00, 300.00),
        "weight_range": (0.020, 5.000),
    },
    "cleaning": {
        "names": (
            "Detergente",
            "Desinfetante",
            "Papel Toalha",
            "Saco para Lixo",
            "Limpador Multiuso",
            "Sabonete Líquido",
        ),
        "price_range": (5.00, 250.00),
        "weight_range": (0.200, 20.000),
    },
    "technology": {
        "names": (
            "Teclado USB",
            "Mouse Óptico",
            "Monitor LED",
            "Headset USB",
            "Webcam HD",
            "SSD Externo",
        ),
        "price_range": (35.00, 2500.00),
        "weight_range": (0.050, 12.000),
    },
    "electrical": {
        "names": (
            "Cabo Elétrico",
            "Extensão Elétrica",
            "Lâmpada LED",
            "Filtro de Linha",
            "Disjuntor",
            "Conector Elétrico",
        ),
        "price_range": (8.00, 800.00),
        "weight_range": (0.050, 18.000),
    },
    "safety": {
        "names": (
            "Capacete de Segurança",
            "Luva de Proteção",
            "Óculos de Proteção",
            "Colete Refletivo",
            "Protetor Auricular",
            "Botina de Segurança",
        ),
        "price_range": (10.00, 600.00),
        "weight_range": (0.050, 8.000),
    },
    "tools": {
        "names": (
            "Furadeira",
            "Chave de Fenda",
            "Alicate",
            "Jogo de Soquetes",
            "Trena",
            "Parafusadeira",
        ),
        "price_range": (12.00, 1800.00),
        "weight_range": (0.100, 25.000),
    },
    "packaging": {
        "names": (
            "Caixa de Papelão",
            "Filme Stretch",
            "Fita Adesiva",
            "Envelope de Segurança",
            "Plástico Bolha",
            "Etiqueta Adesiva",
        ),
        "price_range": (2.00, 400.00),
        "weight_range": (0.020, 30.000),
    },
    "maintenance": {
        "names": (
            "Lubrificante",
            "Graxa Industrial",
            "Selante",
            "Pano Técnico",
            "Escova Industrial",
            "Kit de Reparos",
        ),
        "price_range": (8.00, 900.00),
        "weight_range": (0.050, 20.000),
    },
}


def _random_datetime(
    randomizer: Random,
    start: datetime,
    end: datetime,
) -> datetime:
    interval_seconds = int((end - start).total_seconds())
    return start + timedelta(seconds=randomizer.randint(0, interval_seconds))


def build_products(
    count: int = PRODUCT_COUNT,
    seed: int = DEFAULT_SEED,
) -> list[dict[str, object]]:
    randomizer = Random(seed)
    categories = tuple(CATEGORY_CONFIG)
    first_created_at = datetime(2023, 1, 1, tzinfo=UTC)
    last_created_at = REFERENCE_DATETIME - timedelta(days=30)

    products: list[dict[str, object]] = []

    for product_number in range(1, count + 1):
        category = categories[(product_number - 1) % len(categories)]
        configuration = CATEGORY_CONFIG[category]

        price_minimum, price_maximum = configuration["price_range"]
        weight_minimum, weight_maximum = configuration["weight_range"]

        unit_price = Decimal(f"{randomizer.uniform(price_minimum, price_maximum):.2f}")
        weight_kg = Decimal(f"{randomizer.uniform(weight_minimum, weight_maximum):.3f}")

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

        product_name = (
            f"{randomizer.choice(configuration['names'])} {product_number:04d}"
        )

        status = randomizer.choices(
            ("active", "inactive"),
            weights=(97, 3),
            k=1,
        )[0]

        products.append(
            {
                "sku": f"SKU-{product_number:06d}",
                "product_name": product_name,
                "category": category,
                "unit_price": unit_price,
                "weight_kg": weight_kg,
                "status": status,
                "created_at": created_at,
                "updated_at": updated_at,
            }
        )

    return products


def load_products(
    count: int = PRODUCT_COUNT,
    seed: int = DEFAULT_SEED,
) -> int:
    products = build_products(count=count, seed=seed)

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.executemany(
                """
                INSERT INTO ecommerce.products (
                    sku,
                    product_name,
                    category,
                    unit_price,
                    weight_kg,
                    status,
                    created_at,
                    updated_at
                )
                VALUES (
                    %(sku)s,
                    %(product_name)s,
                    %(category)s,
                    %(unit_price)s,
                    %(weight_kg)s,
                    %(status)s,
                    %(created_at)s,
                    %(updated_at)s
                )
                ON CONFLICT (sku)
                DO UPDATE SET
                    product_name = EXCLUDED.product_name,
                    category = EXCLUDED.category,
                    unit_price = EXCLUDED.unit_price,
                    weight_kg = EXCLUDED.weight_kg,
                    status = EXCLUDED.status,
                    created_at = EXCLUDED.created_at,
                    updated_at = EXCLUDED.updated_at
                """,
                products,
            )

            cursor.execute("SELECT COUNT(*) FROM ecommerce.products")
            product_count = cursor.fetchone()[0]

    return product_count
