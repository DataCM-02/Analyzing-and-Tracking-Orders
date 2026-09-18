from atorders.generators.products import (
    CATEGORY_CONFIG,
    build_products,
)


def test_build_products_is_reproducible() -> None:
    first_result = build_products(count=80, seed=360)
    second_result = build_products(count=80, seed=360)

    assert first_result == second_result
    assert len(first_result) == 80

    product_codes = {product["sku"] for product in first_result}
    categories = {product["category"] for product in first_result}

    assert len(product_codes) == 80
    assert categories == set(CATEGORY_CONFIG)

    assert all(
        product["unit_price"] > 0 and product["weight_kg"] > 0
        for product in first_result
    )
