from atorders.generators.customers import build_customers


def test_build_customers_is_reproducible() -> None:
    first_result = build_customers(count=25, seed=360)
    second_result = build_customers(count=25, seed=360)

    assert first_result == second_result
    assert len(first_result) == 25

    customer_codes = {customer["customer_code"] for customer in first_result}

    assert len(customer_codes) == 25

    assert all(
        customer["updated_at"] >= customer["created_at"] for customer in first_result
    )
