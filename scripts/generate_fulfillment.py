from atorders.generators.fulfillment import load_fulfillment


def main() -> None:
    event_count, shipment_count, item_count, delivered_count = load_fulfillment()

    print("Fulfillment data loaded successfully.")
    print(f"Events: {event_count}")
    print(f"Shipments: {shipment_count}")
    print(f"Shipment items: {item_count}")
    print(f"Delivered orders: {delivered_count}")


if __name__ == "__main__":
    main()
