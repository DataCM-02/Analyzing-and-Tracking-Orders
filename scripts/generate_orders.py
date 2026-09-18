from atorders.generators.orders import load_orders


def main() -> None:
    order_count, item_count, payment_count = load_orders()

    print("Order data loaded successfully.")
    print(f"Orders: {order_count}")
    print(f"Order items: {item_count}")
    print(f"Payments: {payment_count}")


if __name__ == "__main__":
    main()
