from atorders.generators.products import load_products


def main() -> None:
    product_count = load_products()

    print("Product data loaded successfully.")
    print(f"Products: {product_count}")


if __name__ == "__main__":
    main()
