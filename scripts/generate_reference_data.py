from atorders.generators.reference_data import load_reference_data


def main() -> None:
    warehouse_count, carrier_count = load_reference_data()

    print("Reference data loaded successfully.")
    print(f"Warehouses: {warehouse_count}")
    print(f"Carriers: {carrier_count}")


if __name__ == "__main__":
    main()
