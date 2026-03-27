# Methodology — Customer Tier Scoring

## Context
B2B customer segmentation project to help Customer Success
teams prioritize their portfolio based on objective criteria.

---

## Evaluated Dimensions

### 1. Profitability Score (0–100)
| Component          | Weight | Rationale                                          |
|--------------------|--------|----------------------------------------------------|
| Gross margin       | 55%    | High-margin customers are more operationally efficient |
| Total revenue      | 45%    | Volume matters, but is secondary to margin         |

### 2. Adherence Score (0–100)
| Component              | Weight | Rationale                                      |
|------------------------|--------|------------------------------------------------|
| Total events           | 30%    | Indicates platform usage volume                |
| Events per active month| 25%    | Normalizes by time — avoids bias               |
| Distinct products      | 20%    | Diversification reduces churn risk             |
| Distinct business units| 10%    | Penetration across customer organization       |
| Recency (inverted)     | 15%    | More recent activity = healthier customer      |

---

## Tier Matrix

|                           | Adherence ≥ 70        | Adherence < 70             |
|---------------------------|-----------------------|----------------------------|
| **Profitability ≥ 70**    | TIER A — Strategic    | TIER B — Margin Power      |
| **Profitability < 70**    | TIER C — High Adherence Cost | TIER D — Basic/Attention |

---

## Action Flags
| Flag | Condition | Recommended Action |
|---|---|---|
| CHURN RISK | No event in 90+ days | Immediate CS contact |
| WARNING | No event in 60–90 days | Proactive check-in |
| OPPORTUNITY: Xsell | Active 10+ months, only 1 product | Portfolio expansion |
| OPPORTUNITY: Expansion | High profitability, only 1 account | Account growth |
| NEW | Customer with less than 3 months | Onboarding follow-up |
| REGULAR | None of the above | Standard monitoring |

---

## Decisions & Trade-offs

> **Why 70 as the tier threshold?**
> The 70-point cutoff was chosen to represent the top 30%
> of customers — a threshold that balances strategic focus
> with a large enough base for dedicated CS allocation.
> An alternative would be 75 (top quartile), but that would
> reduce the strategic pool too aggressively.

> **Why prioritize margin over revenue in profitability?**
> A customer with high revenue but low margin consumes more
> operational resources relative to the return it generates.
> Weighting margin at 55% ensures CS effort is directed
> toward customers that are truly profitable, not just large.

> **Why invert recency in the adherence score?**
> PERCENT_RANK orders from lowest to highest by default.
> Since fewer days since last event = better, we apply
> (1 - PERCENT_RANK) to ensure recently active customers
> receive higher scores.
