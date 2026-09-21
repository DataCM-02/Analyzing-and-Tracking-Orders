from datetime import UTC, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from random import Random

from atorders.database import get_connection

ORDER_COUNT = 25_000
DEFAULT_SEED = 360

ORDER_START = datetime(2025, 9, 1, tzinfo=UTC)
DATA_SNAPSHOT_AT = datetime(2026, 9, 1, tzinfo=UTC)
ORDER_END = DATA_SNAPSHOT_AT - timedelta(seconds=1)

MONEY_PRECISION = Decimal("0.01")

WAREHOUSE_OPTIONS = {
    "southeast": ("CD-SE-01", "CD-SE-02"),
    "south": ("CD-S-01",),
    "northeast": ("CD-NE-01",),
    "central_west": ("CD-SE-01", "CD-SE-02"),
    "north": ("CD-NE-01", "CD-SE-02"),
}

SERVICE_LEVEL_HOURS = {
    "standard": 120,
    "express": 72,
    "priority": 36,
}

SHIPPING_AMOUNTS = {
    "standard": Decimal("45.00"),
    "express": Decimal("80.00"),
    "priority": Decimal("140.00"),
}


def _money(value: Decimal) -> Decimal:
    return value.quantize(
        MONEY_PRECISION,
        rounding=ROUND_HALF_UP,
    )


def _random_datetime(
    randomizer: Random,
    start: datetime,
    end: datetime,
) -> datetime:
    interval_seconds = int((end - start).total_seconds())

    return start + timedelta(seconds=randomizer.randint(0, interval_seconds))


def build_order_records(
    customers: list[tuple[int, str]],
    warehouses: dict[str, int],
    products: list[tuple[int, Decimal]],
    count: int = ORDER_COUNT,
    seed: int = DEFAULT_SEED,
) -> tuple[
    list[dict[str, object]],
    list[dict[str, object]],
    list[dict[str, object]],
]:
    if not customers:
        raise ValueError("No eligible customers were provided.")

    if not products:
        raise ValueError("No eligible products were provided.")

    randomizer = Random(seed)

    orders: list[dict[str, object]] = []
    order_items: list[dict[str, object]] = []
    payments: list[dict[str, object]] = []

    for order_number_value in range(1, count + 1):
        order_number = f"ORD-{order_number_value:07d}"
        customer_id, customer_region = randomizer.choice(customers)

        warehouse_code = randomizer.choice(WAREHOUSE_OPTIONS[customer_region])
        warehouse_id = warehouses[warehouse_code]

        service_level = randomizer.choices(
            ("standard", "express", "priority"),
            weights=(70, 22, 8),
            k=1,
        )[0]

        created_at = _random_datetime(
            randomizer,
            ORDER_START,
            ORDER_END,
        )

        promised_delivery_at = created_at + timedelta(
            hours=SERVICE_LEVEL_HOURS[service_level]
        )

        item_count = randomizer.choices(
            (1, 2, 3, 4, 5),
            weights=(15, 25, 35, 20, 5),
            k=1,
        )[0]

        selected_products = randomizer.sample(
            products,
            k=item_count,
        )

        subtotal_amount = Decimal("0.00")
        discount_amount = Decimal("0.00")

        for product_id, base_price in selected_products:
            quantity = randomizer.choices(
                (1, 2, 3, 5, 10),
                weights=(25, 30, 20, 15, 10),
                k=1,
            )[0]

            price_factor = Decimal(f"{randomizer.uniform(0.92, 1.08):.4f}")
            unit_price = _money(base_price * price_factor)
            gross_amount = _money(unit_price * quantity)

            discount_rate = randomizer.choices(
                (
                    Decimal("0.00"),
                    Decimal("0.03"),
                    Decimal("0.05"),
                    Decimal("0.10"),
                ),
                weights=(60, 15, 15, 10),
                k=1,
            )[0]

            item_discount = _money(gross_amount * discount_rate)

            subtotal_amount += gross_amount
            discount_amount += item_discount

            order_items.append(
                {
                    "order_number": order_number,
                    "product_id": product_id,
                    "quantity": quantity,
                    "unit_price": unit_price,
                    "discount_amount": item_discount,
                }
            )

        subtotal_amount = _money(subtotal_amount)
        discount_amount = _money(discount_amount)
        shipping_amount = SHIPPING_AMOUNTS[service_level]

        taxable_amount = subtotal_amount - discount_amount
        tax_amount = _money(taxable_amount * Decimal("0.08"))
        total_amount = _money(taxable_amount + shipping_amount + tax_amount)

        payment_outcome = randomizer.choices(
            ("approved", "declined"),
            weights=(96, 4),
            k=1,
        )[0]

        payment_created_at = min(
            created_at + timedelta(minutes=randomizer.randint(1, 30)),
            DATA_SNAPSHOT_AT,
        )
        payment_resolved_at = payment_created_at + timedelta(
            minutes=randomizer.randint(1, 360)
        )

        approved_at = None

        if payment_resolved_at > DATA_SNAPSHOT_AT:
            payment_status = "pending"
            order_status = "payment_pending"
            updated_at = payment_created_at
        elif payment_outcome == "approved":
            payment_status = "approved"
            approved_at = payment_resolved_at
            order_status = "paid"
            updated_at = approved_at
        else:
            payment_status = "declined"
            order_status = "payment_pending"
            updated_at = payment_created_at

        orders.append(
            {
                "order_number": order_number,
                "customer_id": customer_id,
                "warehouse_id": warehouse_id,
                "order_status": order_status,
                "service_level": service_level,
                "promised_delivery_at": promised_delivery_at,
                "subtotal_amount": subtotal_amount,
                "discount_amount": discount_amount,
                "shipping_amount": shipping_amount,
                "tax_amount": tax_amount,
                "total_amount": total_amount,
                "created_at": created_at,
                "updated_at": updated_at,
            }
        )

        payments.append(
            {
                "payment_reference": (f"PAY-{order_number_value:07d}-01"),
                "order_number": order_number,
                "attempt_number": 1,
                "payment_status": payment_status,
                "payment_method": randomizer.choices(
                    (
                        "credit_card",
                        "bank_transfer",
                        "invoice",
                    ),
                    weights=(45, 25, 30),
                    k=1,
                )[0],
                "amount": total_amount,
                "created_at": payment_created_at,
                "approved_at": approved_at,
            }
        )

    return orders, order_items, payments


def load_orders(
    count: int = ORDER_COUNT,
    seed: int = DEFAULT_SEED,
) -> tuple[int, int, int]:
    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT customer_id, region
                FROM ecommerce.customers
                WHERE status = 'active'
                  AND created_at <= %s
                ORDER BY customer_id
                """,
                (ORDER_START,),
            )
            customers = cursor.fetchall()

            cursor.execute(
                """
                SELECT warehouse_code, warehouse_id
                FROM ecommerce.warehouses
                WHERE status = 'active'
                ORDER BY warehouse_code
                """
            )
            warehouses = dict(cursor.fetchall())

            cursor.execute(
                """
                SELECT product_id, unit_price
                FROM ecommerce.products
                WHERE status = 'active'
                  AND created_at <= %s
                ORDER BY product_id
                """,
                (ORDER_START,),
            )
            products = cursor.fetchall()

            orders, item_blueprints, payment_blueprints = build_order_records(
                customers=customers,
                warehouses=warehouses,
                products=products,
                count=count,
                seed=seed,
            )
            # Rebuild synthetic transactional data from a clean state.
            cursor.execute(
                """
                TRUNCATE TABLE
                    ecommerce.order_events,
                    ecommerce.shipment_items,
                    ecommerce.shipments,
                    ecommerce.payments,
                    ecommerce.order_items,
                    ecommerce.orders
                RESTART IDENTITY
                """
            )

            cursor.executemany(
                """
                INSERT INTO ecommerce.orders (
                    order_number,
                    customer_id,
                    warehouse_id,
                    order_status,
                    service_level,
                    promised_delivery_at,
                    subtotal_amount,
                    discount_amount,
                    shipping_amount,
                    tax_amount,
                    total_amount,
                    created_at,
                    updated_at
                )
                VALUES (
                    %(order_number)s,
                    %(customer_id)s,
                    %(warehouse_id)s,
                    %(order_status)s,
                    %(service_level)s,
                    %(promised_delivery_at)s,
                    %(subtotal_amount)s,
                    %(discount_amount)s,
                    %(shipping_amount)s,
                    %(tax_amount)s,
                    %(total_amount)s,
                    %(created_at)s,
                    %(updated_at)s
                )
                ON CONFLICT (order_number)
                DO UPDATE SET
                    customer_id = EXCLUDED.customer_id,
                    warehouse_id = EXCLUDED.warehouse_id,
                    order_status = EXCLUDED.order_status,
                    service_level = EXCLUDED.service_level,
                    promised_delivery_at =
                        EXCLUDED.promised_delivery_at,
                    subtotal_amount = EXCLUDED.subtotal_amount,
                    discount_amount = EXCLUDED.discount_amount,
                    shipping_amount = EXCLUDED.shipping_amount,
                    tax_amount = EXCLUDED.tax_amount,
                    total_amount = EXCLUDED.total_amount,
                    created_at = EXCLUDED.created_at,
                    updated_at = EXCLUDED.updated_at,
                    cancelled_at = NULL,
                    cancellation_reason = NULL
                """,
                orders,
            )

            cursor.execute(
                """
                SELECT order_number, order_id
                FROM ecommerce.orders
                WHERE order_number LIKE 'ORD-%'
                """
            )
            order_ids = dict(cursor.fetchall())

            order_items = [
                {
                    **item,
                    "order_id": order_ids[item["order_number"]],
                }
                for item in item_blueprints
            ]

            payments = [
                {
                    **payment,
                    "order_id": order_ids[payment["order_number"]],
                }
                for payment in payment_blueprints
            ]

            cursor.executemany(
                """
                INSERT INTO ecommerce.order_items (
                    order_id,
                    product_id,
                    quantity,
                    unit_price,
                    discount_amount
                )
                VALUES (
                    %(order_id)s,
                    %(product_id)s,
                    %(quantity)s,
                    %(unit_price)s,
                    %(discount_amount)s
                )
                ON CONFLICT (order_id, product_id)
                DO UPDATE SET
                    quantity = EXCLUDED.quantity,
                    unit_price = EXCLUDED.unit_price,
                    discount_amount = EXCLUDED.discount_amount
                """,
                order_items,
            )

            cursor.executemany(
                """
                INSERT INTO ecommerce.payments (
                    payment_reference,
                    order_id,
                    attempt_number,
                    payment_status,
                    payment_method,
                    amount,
                    created_at,
                    approved_at
                )
                VALUES (
                    %(payment_reference)s,
                    %(order_id)s,
                    %(attempt_number)s,
                    %(payment_status)s,
                    %(payment_method)s,
                    %(amount)s,
                    %(created_at)s,
                    %(approved_at)s
                )
                ON CONFLICT (payment_reference)
                DO UPDATE SET
                    order_id = EXCLUDED.order_id,
                    attempt_number = EXCLUDED.attempt_number,
                    payment_status = EXCLUDED.payment_status,
                    payment_method = EXCLUDED.payment_method,
                    amount = EXCLUDED.amount,
                    created_at = EXCLUDED.created_at,
                    approved_at = EXCLUDED.approved_at
                """,
                payments,
            )

            cursor.execute(
                """
                SELECT
                    (SELECT COUNT(*) FROM ecommerce.orders),
                    (SELECT COUNT(*) FROM ecommerce.order_items),
                    (SELECT COUNT(*) FROM ecommerce.payments)
                """
            )
            order_count, item_count, payment_count = cursor.fetchone()

    return order_count, item_count, payment_count
