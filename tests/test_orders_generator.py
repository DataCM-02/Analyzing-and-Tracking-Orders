from decimal import Decimal

from atorders.generators.orders import build_order_records


def test_build_order_records_is_reproducible() -> None:
    customers = [
        (1, "southeast"),
        (2, "south"),
        (3, "northeast"),
    ]
    warehouses = {
        "CD-SE-01": 1,
        "CD-SE-02": 2,
        "CD-NE-01": 3,
        "CD-S-01": 4,
    }
    products = [(product_id, Decimal("100.00")) for product_id in range(1, 11)]

    first_result = build_order_records(
        customers=customers,
        warehouses=warehouses,
        products=products,
        count=50,
        seed=360,
    )
    second_result = build_order_records(
        customers=customers,
        warehouses=warehouses,
        products=products,
        count=50,
        seed=360,
    )

    assert first_result == second_result

    orders, order_items, payments = first_result

    assert len(orders) == 50
    assert len(payments) == 50
    assert 50 <= len(order_items) <= 250

    assert len({order["order_number"] for order in orders}) == 50

    assert all(
        order["total_amount"]
        == (
            order["subtotal_amount"]
            - order["discount_amount"]
            + order["shipping_amount"]
            + order["tax_amount"]
        )
        for order in orders
    )
