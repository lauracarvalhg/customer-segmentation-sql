import csv
import random
from datetime import date, timedelta

random.seed(42)

COMPANIES = [f"Customer_{i:03d}" for i in range(1, 101)]
BUSINESS_UNITS = ["Enterprise", "SMB", "Mid-Market", "Public Sector"]
PRODUCTS = ["Product_A", "Product_B", "Product_C", "Product_D", "Product_E"]
REGIONS = ["South", "Southeast", "North", "Northeast", "Midwest"]
CS_REPS = ["Anna Smith", "Bruno Costa", "Carol Dias", "Diego Mendes"]

rows = []
for company in COMPANIES:
    bu = random.choice(BUSINESS_UNITS)
    region = random.choice(REGIONS)
    cs = random.choice(CS_REPS)
    n_events = random.randint(1, 120)

    for _ in range(n_events):
        event_date = date(2024, 1, 1) + timedelta(days=random.randint(0, 364))
        revenue = round(random.uniform(500, 50000), 2)
        margin = round(revenue * random.uniform(0.1, 0.6), 2)

        rows.append({
            "customer_name": company,
            "business_unit": bu,
            "product": random.choice(PRODUCTS),
            "event_date": event_date,
            "total_revenue": revenue,
            "total_gross_margin": margin,
            "event_count": random.randint(1, 5),
            "cs_representative": cs,
            "region": region,
            "account_id": f"ACC-{random.randint(1000, 9999)}",
            "status": random.choice(["active", "active", "active", "inactive"])
        })

with open("data/sample_data.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

print(f"{len(rows)} rows generated in data/sample_data.csv")
