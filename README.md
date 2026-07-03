# User Funnel & Revenue Optimization Analysis

An end-to-end business analytics project diagnosing where and why an e-commerce funnel loses revenue — built using **Python (EDA & Cleaning) → PostgreSQL (Business Analysis) → Power BI (Executive Dashboard)**.

---

## 1. Business Problem

The business is converting only a fraction of browsing sessions into completed purchases. Leadership needs to know **where in the customer journey users drop off, which segments (channel, device, region) are underperforming, and how much revenue is at stake** — so marketing and UX teams can prioritize fixes with confidence.

## 2. Project Objective

Analyze the full user funnel (Browse → Add to Cart → Checkout → Purchase) to identify conversion bottlenecks by device, channel, region, and product category, and translate the findings into prioritized, evidence-backed business recommendations.

## 3. Dataset

| | |
|---|---|
| Rows | 21,663 events |
| Sessions | 10,000 |
| Users | 10,000 (one session per user — see *Data Limitations*) |
| Date range | ~1 month |
| Fields | `User_ID`, `Session_ID`, `Event`, `Timestamp`, `Device`, `Region`, `Channel`, `Product_Category`, `Revenue`, `Bounce_Flag` |
| Funnel stages | Browse → Add to Cart → Checkout → Purchase |

## 4. Tech Stack & Workflow

```
Python (pandas, matplotlib, seaborn)
      ↓  cleaning, feature engineering, EDA
PostgreSQL
      ↓  business analysis across 13 sections (validation → advanced KPIs → CTEs)
Power BI
      ↓  2-page interactive executive dashboard
```

## 5. Repository Structure

```
user-funnel-revenue-analysis/
├── README.md
├── data/
│   ├── funnel_analysis_data.csv          # raw dataset
│   └── funnel_analysis_clean.csv         # cleaned, SQL-ready export
├── python/
│   └── Funnel_Analysis.ipynb             # cleaning + EDA notebook
├── sql/
│   └── funnel_analysis_queries.sql       # all validation & business analysis queries
├── powerbi/
│   └── funnel_dashboard.pbix
├── images/
│   └── dashboard_screenshots/
└── docs/
    └── business_insights.md
```

## 6. Key Performance Indicators

- Overall Conversion Rate (Browse → Purchase)
- Stage-to-Stage Conversion Rate (3 transitions)
- Revenue per Session / Channel / Region / Device
- Average Order Value (AOV)
- Cart Abandonment Rate
- Bounce Rate by Device

---

## 7. Headline Numbers (validated across Python, SQL, and the dashboard)

| Metric | Value |
|---|---|
| Total Sessions | 10,000 |
| Total Purchases | 1,080 |
| **Overall Conversion Rate** | **10.80%** |
| Total Revenue | $1,176,405.78 (~$1.18M) |
| Average Order Value (AOV) | $1,089.26 |
| Browse → Add to Cart | 70.59% |
| Add to Cart → Checkout | 49.92% |
| **Checkout → Purchase** | **30.65% — the steepest drop-off in the funnel** |
| Sessions abandoning after Checkout | 2,444 |
| Average session duration | ~4.08 minutes |

---

## 8. Python — Cleaning & EDA

- Validated the dataset: **zero missing values, zero duplicate rows**
- Engineered session-level features (`Date`, `DayOfWeek`, `Hour`, `Event_sequence`) and a custom `get_max_funnel_stage()` function to determine each session's furthest funnel stage reached
- Aggregated raw events into a session-level summary table (the analytical backbone of the whole project)
- Scoped EDA strictly to cleaning, validation, and sanity-check visualizations (funnel volume, revenue distribution, daily session trend) — deliberately left all multi-dimensional business analysis (channel/region/device/product breakdowns) to SQL, to avoid duplicating work across tools
- Exported a renamed, retyped, SQL-ready CSV (`funnel_analysis_clean.csv`) for PostgreSQL import

## 9. SQL — Business Analysis (PostgreSQL)

13 structured sections, progressing from basic validation to advanced analytical SQL:

**A.** Data Validation · **B.** Session Analysis · **C.** Funnel Analysis · **D.** Revenue Analysis · **E.** Customer Behaviour · **F.** Marketing Analysis · **G.** Regional Analysis · **H.** Product Analysis · **I.** Device Analysis · **J.** Time Analysis · **K.** Advanced KPIs · **L.** Window Functions · **M.** CTEs

**SQL techniques demonstrated:** `JOIN`, `CASE WHEN`, `GROUP BY` / `HAVING`, correlated & nested subqueries, multi-step CTEs (`WITH`), window functions (`RANK() OVER (PARTITION BY ...)`, `LAG()`, running totals via `SUM() OVER`), date functions (`EXTRACT`, `TO_CHAR`), and `DISTINCT ON` for de-duplication/attribution logic.

### ⚠️ Data Quality Finding (methodology note)

During validation, session-level segment totals didn't reconcile — channel/device/region totals summed to far more than the true 10,000 sessions. Investigation showed **`channel`, `device`, and `region` were recorded per-event rather than per-session**: 60% of sessions had more than one distinct channel value across their own events.

**Fix applied:** attributed each session to the channel/device/region of its **first event** (first-touch attribution), using `DISTINCT ON (session_id) ... ORDER BY event_timestamp ASC` in SQL and an equivalent `RANKX` + `FILTER` pattern in Power BI/DAX. All segment-level totals now correctly reconcile to 10,000 sessions.

## 10. Power BI — Dashboard

**Page 1 — Executive Overview:** Total Sessions, Conversion Rate, Total Revenue, AOV, and Cart Abandonment Rate KPI cards; a funnel visual (Browse → Purchase); revenue by channel/region/device (sorted bar charts, not pie charts, for accurate comparison); a daily revenue trend line; and a headline-insight callout box.
<img width="1165" height="658" alt="Screenshot 2026-07-04 021438" src="https://github.com/user-attachments/assets/b0d36243-c361-436f-9431-e12455754d8b" />

**Page 2 — Funnel & Customer Diagnostics:** stage-to-stage conversion rate cards; conversion rate by device and by channel; bounce rate by device; and a segment-level table ranking channel+device combinations by checkout-to-purchase rate (surfacing the weakest-performing segment).
<img width="1167" height="655" alt="Screenshot 2026-07-04 021451" src="https://github.com/user-attachments/assets/375f2e2e-016c-40be-9438-2d6a0de86b50" />

**DAX/modeling techniques:** `DISTINCTCOUNT`, `CALCULATE`, `DIVIDE`, `RANKX`, `FILTER`, `SUMMARIZE`, `AVERAGEX`, a first-touch attribution table with a proper star-schema relationship to the event table, and a dedicated Date table for time intelligence.

---

## 11. Business Insights

**1. Checkout is the single biggest leak in the funnel**
- *Finding:* Checkout → Purchase is the steepest drop-off point.
- *Evidence:* Only 30.65% of sessions reaching Checkout complete a Purchase — the lowest stage-to-stage rate in the funnel.
- *Recommendation:* Prioritize a checkout UX audit (payment options, form length, guest checkout, cost transparency) before increasing top-of-funnel spend — this stage has the highest conversion leverage.

**2. Email is the weakest-performing channel**
- *Finding:* Email converts below every other channel and below the segment average.
- *Evidence:* Email converts at 10.20% (lowest of 4 channels), 0.60pp below the 10.80% average.
- *Recommendation:* Audit email segmentation/offer relevance and A/B test against higher-converting Organic and Google Ads messaging.

**3. Tablet is the weakest device across every metric**
- *Finding:* Tablet has the lowest conversion rate, highest bounce rate, and anchors the single worst-performing segment.
- *Evidence:* Tablet converts at 10.38% (lowest) with an 80.85% bounce rate (highest); Email + Tablet is the worst segment at 26.19% checkout-to-purchase.
- *Recommendation:* Test the site/checkout experience specifically on tablet viewports.

**4. Organic is the most efficient channel relative to spend**
- *Finding:* Organic converts best of all channels despite no direct ad spend.
- *Evidence:* Organic leads at 11.19% conversion, nearly matching Google Ads' revenue with a lower acquisition cost behind it.
- *Recommendation:* Increase SEO/content investment; use Organic's conversion rate as the internal benchmark.

**5. South and East regions outperform North and West**
- *Finding:* A consistent, moderate regional performance gap exists.
- *Evidence:* South (11.25%) and East (11.14%) outperform North (10.42%) and West (10.38%) by ~0.8–0.9pp.
- *Recommendation:* Investigate delivery times/regional promotions in North/West — the gap is real but doesn't currently justify a major resourcing shift.

**6. Cart-level revenue isn't tracked — a data limitation, not a finding**
- *Finding:* The dataset cannot quantify the dollar value of abandoned carts, since `revenue` is only populated on `Purchase` events.
- *Recommendation:* Capture cart-value-at-abandonment in future data collection to enable revenue-weighted prioritization.

**7. Data quality: session attribution required correction**
- *Finding:* Channel/device/region were recorded per-event, not per-session, requiring a first-touch attribution fix (see Section 9) before any segment-level analysis could be trusted.
- *Why it matters:* demonstrates the analysis was validated, not taken at face value.

## 12. Data Limitations

- **No repeat visitors:** every `user_id` in this dataset maps to exactly one `session_id`. Returning-visitor / repeat-purchase behavior could not be analyzed as a result — this is a dataset characteristic, not an analysis gap.
- **Revenue is only recorded at the Purchase event**, so pre-purchase cart/checkout value (and therefore true abandonment cost) cannot be quantified from this data.

## 13. Future Improvements

- Capture cart-value-at-abandonment to enable dollar-weighted prioritization of drop-off fixes
- Track users across multiple sessions to enable repeat-visitor and retention analysis
- Publish the Power BI dashboard to Power BI Service for live, clickable access instead of static screenshots
- Extend the analysis to a real-world (non-synthetic) dataset with genuine data messiness

---

## 14. Skills Demonstrated

**Python:** pandas (groupby/agg, custom `apply` functions), datetime feature engineering, session-level aggregation, matplotlib/seaborn visualization, data validation.

**SQL (PostgreSQL):** joins, `CASE` logic, aggregate functions, `HAVING`, subqueries, multi-step CTEs, window functions (`RANK`, `LAG`, running totals, `PARTITION BY`), date functions, `DISTINCT ON` for attribution correction, data quality diagnosis and remediation.

**Power BI:** Power Query transformations, DAX measures (`CALCULATE`, `DISTINCTCOUNT`, `DIVIDE`, `RANKX`, `FILTER`, `SUMMARIZE`), star-schema data modeling, first-touch attribution modeling, executive dashboard design.

---
