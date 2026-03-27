# 🎯 Customer Segmentation & Tier Scoring

B2B customer segmentation using **profitability** and **adherence** 
composite scores built entirely in SQL with window functions.

---

## The Problem
Customer Success teams managing large portfolios need an objective
way to prioritize which customers deserve strategic attention.
Without a data-driven criteria, prioritization relies on perception
— leading to preventable churn and missed revenue opportunities.

## The Solution
A SQL pipeline that classifies each customer into 4 tiers based
on two independent composite scores, also generating automatic
action flags for the CS team.

---

## How It Works
```
fct_revenues + dim_accounts
         ↓
    base_12m     → aggregates metrics from the last 12 months
         ↓
    features     → normalizes and creates derived variables
         ↓
    scores       → PERCENT_RANK() with weighted dimensions
         ↓
    final        → tiers + action flags
```

---

## Tier Matrix

|                           | Adherence ≥ 70             | Adherence < 70              |
|---------------------------|----------------------------|-----------------------------|
| **Profitability ≥ 70**    | TIER A — Strategic         | TIER B — Margin Power       |
| **Profitability < 70**    | TIER C — High Adherence Cost | TIER D — Basic/Attention  |

---

## Action Flags

| Flag | Condition | Recommended Action |
|---|---|---|
| CHURN RISK | Inactive 90+ days | Immediate CS contact |
| WARNING | Inactive 60–90 days | Proactive check-in |
| OPPORTUNITY: Xsell | 10+ months, only 1 product | Portfolio expansion |
| OPPORTUNITY: Expansion | High profitability, 1 account | Account growth |
| NEW | Customer < 3 months | Onboarding follow-up |
| REGULAR | None of the above | Standard monitoring |

---

## Tech Stack
- **SQL** — Trino / Athena / DuckDB compatible
- **Window Functions** — PERCENT_RANK(), ROW_NUMBER()
- **Pattern** — Chained CTEs

---

## How to Run Locally
```bash
# Install DuckDB
pip install duckdb

# Generate sample data
python data/generate_sample.py

# Run the query
python -c "
import duckdb
duckdb.sql(open('queries/customer_tier_scoring.sql').read())
"
```

---

## Repository Structure
```
customer-segmentation-sql/
│
├── README.md
├── queries/
│   └── customer_tier_scoring.sql   ← main query
├── data/
│   └── generate_sample.py          ← fictional data generator
├── docs/
│   └── metodologia.md              ← scoring methodology
└── assets/
    └── output_example.png          ← sample output (fictional data)
```

---

## Key Technical Decisions

> **Composite scoring with PERCENT_RANK()**
> Instead of absolute thresholds, percentile ranking ensures
> the scoring adapts to any customer base size and distribution.

> **Normalization by active months**
> A customer active for 6 months may have fewer total events
> than one active for 12 months — dividing by active months
> avoids penalizing newer customers unfairly.

> **Recency as inverted score**
> Since PERCENT_RANK orders lowest to highest, recency is
> inverted with (1 - PERCENT_RANK) so recently active
> customers score higher.

📄 [Full methodology](docs/metodologia.md)
