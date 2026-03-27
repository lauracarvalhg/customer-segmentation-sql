/*
=============================================================
  PROJETO: Customer Segmentation & Tier Scoring
  Autor: Laura Carvalho
  Descrição: Segmentação de clientes B2B por rentabilidade
             e aderência usando scores compostos ponderados
  Banco: Compatível com Trino / Athena / DuckDB
=============================================================
*/

WITH params AS (
    SELECT
        CURRENT_DATE AS dt_ref,
        (CURRENT_DATE - INTERVAL '12' MONTH) AS dt_ini
),

/*
  CTE: base_12m
  Objetivo: agregar todas as métricas brutas dos últimos 12 meses
  por cliente. Base para todos os cálculos posteriores.
*/
base_12m AS (
    SELECT
        ar.customer_name,

        -- Rentabilidade
        SUM(ar.total_revenue)                                            AS total_revenue,
        SUM(ar.total_gross_margin)                                       AS total_gross_margin,
        SUM(ar.total_gross_margin) / NULLIF(SUM(ar.total_revenue), 0)   AS margin_rate,

        -- Aderência: Volume + Frequência + Variedade
        SUM(CAST(ar.event_count AS INTEGER))                                          AS total_events,
        COUNT(DISTINCT DATE_TRUNC('month', CAST(ar.event_date AS DATE)))              AS active_months,
        COUNT(DISTINCT ar.product)                                                    AS distinct_products,
        COUNT(DISTINCT ar.business_unit)                                              AS distinct_bus,

        -- Contas
        COUNT(DISTINCT CASE WHEN acc.status = 'active' THEN acc.account_id END)      AS active_accounts,
        COUNT(DISTINCT acc.account_id)                                                AS total_accounts,

        MAX(CAST(ar.event_date AS DATE)) AS last_event_date,
        MIN(CAST(ar.event_date AS DATE)) AS first_event_date,

        MAX(ar.cs_representative) AS cs_representative,
        MAX(ar.region)            AS region

    FROM fct_revenues ar
    LEFT JOIN dim_accounts acc
        ON acc.account_id = ar.account_id
    CROSS JOIN params p
    WHERE
        CAST(ar.event_date AS DATE) >= p.dt_ini
        AND CAST(ar.event_date AS DATE) <= p.dt_ref
        AND ar.customer_name IS NOT NULL
    GROUP BY 1
),

/*
  CTE: bu_rank
  Objetivo: identificar a Business Unit principal de cada cliente
  (aquela que gerou mais receita no período)
*/
bu_rank AS (
    SELECT
        ar.customer_name,
        ar.business_unit,
        SUM(ar.total_revenue) AS revenue_by_bu,
        ROW_NUMBER() OVER (
            PARTITION BY ar.customer_name
            ORDER BY SUM(ar.total_revenue) DESC
        ) AS rn
    FROM fct_revenues ar
    CROSS JOIN params p
    WHERE
        CAST(ar.event_date AS DATE) >= p.dt_ini
        AND CAST(ar.event_date AS DATE) <= p.dt_ref
        AND ar.customer_name IS NOT NULL
    GROUP BY 1, 2
),

/*
  CTE: features
  Objetivo: normalizar métricas para evitar viés por tempo ativo.
  Ex: um cliente com 6 meses pode ter menos eventos totais que
  um de 12 meses, mas ser mais ativo proporcionalmente.
*/
features AS (
    SELECT
        b.*,
        br.business_unit AS main_business_unit,

        -- Normalização por tempo
        (b.total_events / NULLIF(b.active_months, 0))                        AS events_per_active_month,
        DATE_DIFF('day', b.last_event_date, (SELECT dt_ref FROM params))      AS days_since_last_event,

        -- Receita por conta ativa (eficiência)
        (b.total_revenue / NULLIF(b.active_accounts, 0))                      AS revenue_per_active_account

    FROM base_12m b
    LEFT JOIN bu_rank br
        ON br.customer_name = b.customer_name
       AND br.rn = 1
    WHERE b.active_accounts > 0
),

/*
  CTE: scores
  Objetivo: calcular scores compostos (0-100) por dimensão.

  Score Rentabilidade:
    55% margem bruta → clientes com alta margem são mais eficientes
    45% receita total → volume importa, mas é secundário à margem

  Score Aderência:
    30% total de eventos        → volume de uso da plataforma
    25% eventos/mês ativo       → intensidade normalizada por tempo
    20% produtos distintos      → diversificação reduz risco de churn
    10% BUs distintas           → penetração na organização do cliente
    15% recência (invertida)    → quanto mais recente, melhor
*/
scores AS (
    SELECT
        *,

        (
            (PERCENT_RANK() OVER (ORDER BY total_gross_margin) * 0.55) +
            (PERCENT_RANK() OVER (ORDER BY total_revenue)      * 0.45)
        ) * 100 AS profitability_score,

        (
            (PERCENT_RANK() OVER (ORDER BY total_events)              * 0.30) +
            (PERCENT_RANK() OVER (ORDER BY events_per_active_month)   * 0.25) +
            (PERCENT_RANK() OVER (ORDER BY distinct_products)         * 0.20) +
            (PERCENT_RANK() OVER (ORDER BY distinct_bus)              * 0.10) +
            ((1 - PERCENT_RANK() OVER (ORDER BY days_since_last_event)) * 0.15)
        ) * 100 AS adherence_score

    FROM features
),

/*
  CTE: final
  Objetivo: aplicar a matriz de tiers e gerar flags de ação
  para o time de CS priorizar a carteira.

  Matriz de Tiers (threshold = 70):
    Profitability ≥ 70 + Adherence ≥ 70 → TIER A (Strategic)
    Profitability ≥ 70 + Adherence < 70  → TIER B (Margin Power)
    Profitability < 70 + Adherence ≥ 70  → TIER C (High Adherence Cost)
    Profitability < 70 + Adherence < 70  → TIER D (Basic/Attention)
*/
final AS (
    SELECT
        customer_name,
        main_business_unit,
        cs_representative,
        region,

        CAST(total_revenue AS DECIMAL(15,2))               AS total_revenue,
        CAST(total_gross_margin AS DECIMAL(15,2))          AS total_gross_margin,
        ROUND(margin_rate * 100, 2)                        AS margin_rate_pct,
        CAST(revenue_per_active_account AS DECIMAL(15,2))  AS revenue_per_active_account,

        active_accounts,
        total_accounts,
        total_events,
        active_months,
        ROUND(events_per_active_month, 2) AS events_per_active_month,
        distinct_products,
        distinct_bus,

        first_event_date,
        last_event_date,
        days_since_last_event,

        ROUND(profitability_score, 2) AS profitability_score,
        ROUND(adherence_score, 2)     AS adherence_score,

        CASE
            WHEN profitability_score >= 70 AND adherence_score >= 70 THEN 'TIER A - STRATEGIC'
            WHEN profitability_score >= 70 AND adherence_score <  70 THEN 'TIER B - MARGIN POWER'
            WHEN profitability_score <  70 AND adherence_score >= 70 THEN 'TIER C - HIGH ADHERENCE COST'
            ELSE                                                          'TIER D - BASIC/ATTENTION'
        END AS tier,

        CASE
            WHEN days_since_last_event > 90 THEN 'CHURN RISK: Inactive 90+ days'
            WHEN days_since_last_event > 60 THEN 'WARNING: Inactive 60+ days'
            WHEN active_months >= 10 AND distinct_products = 1 THEN 'OPPORTUNITY: Expand portfolio (Xsell)'
            WHEN profitability_score >= 70 AND active_accounts = 1 THEN 'OPPORTUNITY: Account expansion'
            WHEN DATE_DIFF('month', first_event_date, (SELECT dt_ref FROM params)) <= 3 THEN 'NEW: Recent customer'
            ELSE 'REGULAR'
        END AS action_flag

    FROM scores
)

SELECT *
FROM final
ORDER BY
    CASE tier
        WHEN 'TIER A - STRATEGIC'           THEN 1
        WHEN 'TIER B - MARGIN POWER'        THEN 2
        WHEN 'TIER C - HIGH ADHERENCE COST' THEN 3
        ELSE 4
    END,
    total_revenue DESC;
