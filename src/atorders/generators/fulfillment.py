from datetime import datetime, timedelta
from random import Random
from uuid import UUID, uuid5

from psycopg.rows import dict_row

from atorders.database import get_connection
from atorders.generators.orders import DATA_SNAPSHOT_AT

DEFAULT_SEED = 360

EVENT_NAMESPACE = UUID("271376dd-71d9-4d8e-b645-010699612437")

CUSTOMER_CANCELLATION_RATE = 0.035

SERVICE_FACTORS = {
    "standard": 1.00,
    "express": 0.80,
    "priority": 0.65,
}

TRANSPORT_HOURS = {
    "southeast": 36,
    "south": 48,
    "northeast": 56,
    "central_west": 60,
    "north": 84,
}

CARRIER_FACTORS = {
    "CAR-001": 0.90,
    "CAR-002": 0.85,
    "CAR-003": 1.00,
    "CAR-004": 1.10,
    "CAR-005": 1.20,
    "CAR-006": 1.25,
}

EVENT_SOURCE = {
    "order_created": "erp",
    "payment_approved": "payment",
    "order_allocated": "wms",
    "picking_started": "wms",
    "picking_completed": "wms",
    "order_packed": "wms",
    "order_shipped": "tms",
    "in_transit": "tms",
    "order_delivered": "tms",
    "order_cancelled": "erp",
}


def _add_hours(
    timestamp: datetime,
    hours: float,
) -> datetime:
    return timestamp + timedelta(hours=hours)


def _create_event(
    randomizer: Random,
    order_id: int,
    order_number: str,
    event_type: str,
    event_time: datetime,
    sequence: int,
) -> dict[str, object]:
    received_delay = randomizer.randint(1, 180)

    if randomizer.random() < 0.05:
        received_delay += randomizer.randint(720, 2_160)

    received_at = event_time + timedelta(minutes=received_delay)

    if received_at > DATA_SNAPSHOT_AT:
        received_at = DATA_SNAPSHOT_AT

    event_id = uuid5(
        EVENT_NAMESPACE,
        f"{order_number}:{event_type}:{sequence}",
    )

    return {
        "event_id": event_id,
        "order_id": order_id,
        "event_type": event_type,
        "event_time": event_time,
        "received_at": received_at,
        "source_system": EVENT_SOURCE[event_type],
        "event_payload": "{}",
    }


def build_fulfillment_records(
    orders: list[dict[str, object]],
    carriers: list[tuple[int, str]],
    seed: int = DEFAULT_SEED,
) -> tuple[
    list[dict[str, object]],
    list[dict[str, object]],
    list[dict[str, object]],
]:
    randomizer = Random(seed)

    events: list[dict[str, object]] = []
    shipments: list[dict[str, object]] = []
    order_updates: list[dict[str, object]] = []

    for order in orders:
        order_id = order["order_id"]
        order_number = order["order_number"]
        created_at = order["created_at"]
        payment_created_at = order["payment_created_at"]
        payment_status = order["payment_status"]

        sequence = 1

        events.append(
            _create_event(
                randomizer,
                order_id,
                order_number,
                "order_created",
                created_at,
                sequence,
            )
        )
        sequence += 1

        if payment_status == "pending":
            order_updates.append(
                {
                    "order_id": order_id,
                    "order_status": "payment_pending",
                    "updated_at": payment_created_at,
                    "cancelled_at": None,
                    "cancellation_reason": None,
                }
            )
            continue

        if payment_status == "declined":
            cancelled_at = min(
                _add_hours(
                    payment_created_at,
                    randomizer.uniform(1, 12),
                ),
                DATA_SNAPSHOT_AT,
            )

            events.append(
                _create_event(
                    randomizer,
                    order_id,
                    order_number,
                    "order_cancelled",
                    cancelled_at,
                    sequence,
                )
            )

            order_updates.append(
                {
                    "order_id": order_id,
                    "order_status": "cancelled",
                    "updated_at": cancelled_at,
                    "cancelled_at": cancelled_at,
                    "cancellation_reason": "payment_declined",
                }
            )
            continue

        approved_at = order["approved_at"]

        events.append(
            _create_event(
                randomizer,
                order_id,
                order_number,
                "payment_approved",
                approved_at,
                sequence,
            )
        )
        sequence += 1

        if randomizer.random() < CUSTOMER_CANCELLATION_RATE:
            cancelled_at = _add_hours(
                approved_at,
                randomizer.uniform(1, 12),
            )

            if cancelled_at <= DATA_SNAPSHOT_AT:
                events.append(
                    _create_event(
                        randomizer,
                        order_id,
                        order_number,
                        "order_cancelled",
                        cancelled_at,
                        sequence,
                    )
                )

                order_updates.append(
                    {
                        "order_id": order_id,
                        "order_status": "cancelled",
                        "updated_at": cancelled_at,
                        "cancelled_at": cancelled_at,
                        "cancellation_reason": "customer_request",
                    }
                )
                continue

            order_updates.append(
                {
                    "order_id": order_id,
                    "order_status": "paid",
                    "updated_at": approved_at,
                    "cancelled_at": None,
                    "cancellation_reason": None,
                }
            )
            continue

        service_level = order["service_level"]
        customer_region = order["customer_region"]
        warehouse_code = order["warehouse_code"]

        service_factor = SERVICE_FACTORS[service_level]

        delay_factor = randomizer.choices(
            (1.0, 1.5, 2.5),
            weights=(78, 15, 7),
            k=1,
        )[0]

        carrier_id, carrier_code = randomizer.choice(carriers)
        carrier_factor = CARRIER_FACTORS.get(
            carrier_code,
            1.0,
        )

        picking_factor = 1.6 if warehouse_code == "CD-SE-02" else 1.0
        packing_factor = 1.5 if warehouse_code == "CD-NE-01" else 1.0

        allocated_at = _add_hours(
            approved_at,
            randomizer.uniform(1, 8) * service_factor * delay_factor,
        )
        picking_started_at = _add_hours(
            allocated_at,
            randomizer.uniform(0.5, 4) * service_factor * delay_factor,
        )
        picking_completed_at = _add_hours(
            picking_started_at,
            randomizer.uniform(2, 12) * service_factor * delay_factor * picking_factor,
        )
        packed_at = _add_hours(
            picking_completed_at,
            randomizer.uniform(0.5, 6)
            * service_factor
            * delay_factor
            * packing_factor,
        )
        shipped_at = _add_hours(
            packed_at,
            randomizer.uniform(1, 8) * service_factor * delay_factor,
        )
        in_transit_at = _add_hours(
            shipped_at,
            randomizer.uniform(0.25, 3),
        )
        delivered_at = _add_hours(
            in_transit_at,
            TRANSPORT_HOURS[customer_region]
            * service_factor
            * delay_factor
            * carrier_factor,
        )

        stage_events = (
            (
                "allocated",
                "order_allocated",
                allocated_at,
            ),
            (
                "picking",
                "picking_started",
                picking_started_at,
            ),
            (
                "picked",
                "picking_completed",
                picking_completed_at,
            ),
            (
                "packed",
                "order_packed",
                packed_at,
            ),
            (
                "shipped",
                "order_shipped",
                shipped_at,
            ),
            (
                "in_transit",
                "in_transit",
                in_transit_at,
            ),
            (
                "delivered",
                "order_delivered",
                delivered_at,
            ),
        )

        status_ranks = {
            "paid": 0,
            "allocated": 1,
            "picking": 2,
            "picked": 3,
            "packed": 4,
            "shipped": 5,
            "in_transit": 6,
            "delivered": 7,
        }

        final_status = "paid"
        last_event_at = approved_at

        for (
            stage_status,
            event_type,
            event_time,
        ) in stage_events:
            if event_time > DATA_SNAPSHOT_AT:
                break

            events.append(
                _create_event(
                    randomizer,
                    order_id,
                    order_number,
                    event_type,
                    event_time,
                    sequence,
                )
            )
            sequence += 1
            final_status = stage_status
            last_event_at = event_time

        final_status_rank = status_ranks[final_status]

        order_updates.append(
            {
                "order_id": order_id,
                "order_status": final_status,
                "updated_at": last_event_at,
                "cancelled_at": None,
                "cancellation_reason": None,
            }
        )

        if final_status_rank >= 5:
            shipment_status = {
                "shipped": "shipped",
                "in_transit": "in_transit",
                "delivered": "delivered",
            }[final_status]

            delivery_attempts = 0

            if final_status == "delivered":
                delivery_attempts = randomizer.choices(
                    (1, 2, 3),
                    weights=(88, 10, 2),
                    k=1,
                )[0]

            shipments.append(
                {
                    "shipment_number": (f"SHP-{order_number.removeprefix('ORD-')}"),
                    "order_id": order_id,
                    "carrier_id": carrier_id,
                    "shipment_status": shipment_status,
                    "delivery_attempts": delivery_attempts,
                    "shipped_at": shipped_at,
                    "in_transit_at": (
                        in_transit_at if final_status_rank >= 6 else None
                    ),
                    "delivered_at": (delivered_at if final_status_rank >= 7 else None),
                    "is_partial": (
                        final_status == "delivered" and randomizer.random() < 0.08
                    ),
                }
            )

    return events, shipments, order_updates


def load_fulfillment(
    seed: int = DEFAULT_SEED,
) -> tuple[int, int, int, int]:
    with get_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute(
                """
                SELECT
                    o.order_id,
                    o.order_number,
                    o.created_at,
                    o.service_level,
                    w.warehouse_code,
                    c.region AS customer_region,
                    p.payment_status,
                    p.created_at AS payment_created_at,
                    p.approved_at
                FROM ecommerce.orders AS o
                INNER JOIN ecommerce.customers AS c
                    ON c.customer_id = o.customer_id
                INNER JOIN ecommerce.warehouses AS w
                    ON w.warehouse_id = o.warehouse_id
                INNER JOIN ecommerce.payments AS p
                    ON p.order_id = o.order_id
                ORDER BY o.order_id
                """
            )
            orders = cursor.fetchall()

            cursor.execute(
                """
                SELECT carrier_id, carrier_code
                FROM ecommerce.carriers
                WHERE status = 'active'
                ORDER BY carrier_id
                """
            )
            carriers = [
                (row["carrier_id"], row["carrier_code"]) for row in cursor.fetchall()
            ]

            events, shipments, order_updates = build_fulfillment_records(
                orders=orders,
                carriers=carriers,
                seed=seed,
            )

            cursor.execute(
                """
                TRUNCATE TABLE
                    ecommerce.shipment_items,
                    ecommerce.shipments,
                    ecommerce.order_events
                RESTART IDENTITY
                """
            )

            cursor.executemany(
                """
                UPDATE ecommerce.orders
                SET
                    order_status = %(order_status)s,
                    updated_at = %(updated_at)s,
                    cancelled_at = %(cancelled_at)s,
                    cancellation_reason =
                        %(cancellation_reason)s
                WHERE order_id = %(order_id)s
                """,
                order_updates,
            )

            cursor.executemany(
                """
                INSERT INTO ecommerce.shipments (
                    shipment_number,
                    order_id,
                    carrier_id,
                    shipment_status,
                    delivery_attempts,
                    shipped_at,
                    in_transit_at,
                    delivered_at
                )
                VALUES (
                    %(shipment_number)s,
                    %(order_id)s,
                    %(carrier_id)s,
                    %(shipment_status)s,
                    %(delivery_attempts)s,
                    %(shipped_at)s,
                    %(in_transit_at)s,
                    %(delivered_at)s
                )
                ON CONFLICT (shipment_number)
                DO UPDATE SET
                    order_id = EXCLUDED.order_id,
                    carrier_id = EXCLUDED.carrier_id,
                    shipment_status = EXCLUDED.shipment_status,
                    delivery_attempts =
                        EXCLUDED.delivery_attempts,
                    shipped_at = EXCLUDED.shipped_at,
                    in_transit_at = EXCLUDED.in_transit_at,
                    delivered_at = EXCLUDED.delivered_at
                """,
                shipments,
            )

            cursor.executemany(
                """
                INSERT INTO ecommerce.order_events (
                    event_id,
                    order_id,
                    event_type,
                    event_time,
                    received_at,
                    source_system,
                    event_payload
                )
                SELECT
                    %(event_id)s,
                    %(order_id)s,
                    %(event_type)s,
                    %(event_time)s,
                    %(received_at)s,
                    %(source_system)s,
                    %(event_payload)s::JSONB
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM ecommerce.order_events
                    WHERE event_id = %(event_id)s
                )
                """,
                events,
            )

            cursor.execute(
                """
                SELECT shipment_id, shipment_number
                FROM ecommerce.shipments
                """
            )
            shipment_ids = {
                row["shipment_number"]: row["shipment_id"] for row in cursor.fetchall()
            }

            shipment_by_order = {
                shipment["order_id"]: shipment for shipment in shipments
            }

            cursor.execute(
                """
                SELECT
                    order_item_id,
                    order_id,
                    quantity
                FROM ecommerce.order_items
                ORDER BY order_id, order_item_id
                """
            )

            shipment_items: list[dict[str, object]] = []
            partial_orders: set[int] = set()

            for item in cursor.fetchall():
                shipment = shipment_by_order.get(item["order_id"])

                if shipment is None:
                    continue

                quantity_delivered = 0

                if shipment["shipment_status"] == "delivered":
                    quantity_delivered = item["quantity"]

                    if (
                        shipment["is_partial"]
                        and item["order_id"] not in partial_orders
                    ):
                        quantity_delivered = max(
                            0,
                            item["quantity"] - 1,
                        )
                        partial_orders.add(item["order_id"])

                shipment_items.append(
                    {
                        "shipment_id": shipment_ids[shipment["shipment_number"]],
                        "order_item_id": item["order_item_id"],
                        "quantity_shipped": item["quantity"],
                        "quantity_delivered": (quantity_delivered),
                    }
                )

            cursor.executemany(
                """
                INSERT INTO ecommerce.shipment_items (
                    shipment_id,
                    order_item_id,
                    quantity_shipped,
                    quantity_delivered
                )
                VALUES (
                    %(shipment_id)s,
                    %(order_item_id)s,
                    %(quantity_shipped)s,
                    %(quantity_delivered)s
                )
                ON CONFLICT (shipment_id, order_item_id)
                DO UPDATE SET
                    quantity_shipped =
                        EXCLUDED.quantity_shipped,
                    quantity_delivered =
                        EXCLUDED.quantity_delivered
                """,
                shipment_items,
            )

            cursor.execute(
                """
                SELECT
                    (
                        SELECT COUNT(*)
                        FROM ecommerce.order_events
                    ) AS event_count,
                    (
                        SELECT COUNT(*)
                        FROM ecommerce.shipments
                    ) AS shipment_count,
                    (
                        SELECT COUNT(*)
                        FROM ecommerce.shipment_items
                    ) AS shipment_item_count,
                    (
                        SELECT COUNT(*)
                        FROM ecommerce.orders
                        WHERE order_status = 'delivered'
                    ) AS delivered_count
                """
            )
            result = cursor.fetchone()

    return (
        result["event_count"],
        result["shipment_count"],
        result["shipment_item_count"],
        result["delivered_count"],
    )
