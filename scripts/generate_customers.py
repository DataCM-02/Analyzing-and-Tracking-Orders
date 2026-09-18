from atorders.generators.customers import load_customers


def main() -> None:
    customer_count = load_customers()

    print("Customer data loaded successfully.")
    print(f"Customers: {customer_count}")


if __name__ == "__main__":
    main()
