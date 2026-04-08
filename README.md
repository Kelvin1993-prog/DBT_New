#  Airbnb Analytics — dbt Project

> A production-style dbt analytics project modelling Airbnb listings, hosts, and guest reviews — featuring incremental loading, surrogate key generation, advanced dbt testing with `dbt_expectations`, and review sentiment classification.

![dbt](https://img.shields.io/badge/dbt-Core-FF694B) ![Snowflake](https://img.shields.io/badge/Warehouse-Snowflake-29B5E8) ![Status](https://img.shields.io/badge/Status-Active-brightgreen)

---

##  Project Overview

This project transforms raw Airbnb data (listings, hosts, reviews) into clean dimensional models suitable for BI reporting. It demonstrates advanced dbt features including:

- **Incremental models** with date-range variable support
- **Surrogate key generation** using `dbt_utils.generate_surrogate_key`
- **Advanced data quality tests** using `dbt_expectations`
- **Source freshness monitoring** on review data
- **Review sentiment classification** (positive / neutral / negative)

**Business questions answered:**
- Which listings and room types are available and at what price?
- Who are the superhosts and what listings do they manage?
- What do guests think of listings, and how has sentiment trended over time?
- Are reviews being loaded on time (freshness checks)?

---

##  Architecture

```
models/
├── src/                             # Source-aligned raw models (views)
│   ├── src_listings.sql
│   ├── src_hosts.sql
│   └── src_reviews.sql
├── dim/                             # Cleaned dimension models
│   ├── dim_listings_cleansed.sql    # Validated & cleaned listings
│   ├── dim_hosts_cleansed.sql       # Validated & cleaned hosts
│   └── dim_listings_w_hosts.sql     # Listings joined with host details
├── fct/                             # Fact models
│   └── fct_reviews.sql              # Incremental reviews fact with surrogate key
├── mart/                            # Final mart models (BI-ready)
├── schema.yml                       # Full model docs, column tests
├── sources.yml                      # Source definitions with freshness config
├── docs.md                          # Extended Jinja doc blocks
└── overview.md                      # Project-level documentation
```

---

##  Materialisation Strategy

| Model | Materialisation | Reason |
|-------|----------------|--------|
| `src_*` | `view` | Thin wrappers over raw source tables |
| `dim_*` | `view` / `table` | Dimensions materialised for BI performance |
| `fct_reviews` | `incremental` | Large table; only new reviews loaded per run |

---

##  Model Reference

### Source Layer (`src/`)

Raw models that select directly from source tables with minimal transformation. One model per source table — no business logic applied here.

---

### Dimension Layer (`dim/`)

#### `dim_listings_cleansed`
Cleans and validates raw listings data:
- Ensures `room_type` is one of: `Entire home/apt`, `Private room`, `Shared room`, `Hotel room`
- Validates `minimum_nights` is a positive value
- Price validated against regex pattern `^\$[0-9][0-9\.]+$`

| Column | Test |
|--------|------|
| `listing_id` | `unique`, `not_null` |
| `host_id` | `not_null`, `relationships` → `dim_hosts_cleansed` |
| `room_type` | `accepted_values` |
| `minimum_nights` | `positive_value` |

#### `dim_hosts_cleansed`
Validates and cleans host data:

| Column | Test |
|--------|------|
| `host_id` | `unique`, `not_null` |
| `is_superhost` | `accepted_values: ['t', 'f']` |

#### `dim_listings_w_hosts`
Enriched listing model joining listing details with host information. Tested to ensure row count matches the source `listings` table using:
```yaml
- dbt_expectations.expect_table_row_count_to_equal_other_table:
    compare_model: source('airbnb', 'listings')
```
Price column validated for:
- Correct data type (`number`)
- 99th percentile between $50–$500
- Max value warning if exceeded

---

### Fact Layer (`fct/`)

#### `fct_reviews` — Incremental Reviews Fact Table
The most technically sophisticated model in this project:

```sql
{{ config(
    materialized = 'incremental',
    on_schema_change = 'fail'
) }}

SELECT
    {{ dbt_utils.generate_surrogate_key(
        ['listing_id', 'review_date', 'reviewer_name', 'review_text']
    ) }} AS review_id,
    *
FROM src_reviews
WHERE review_text IS NOT NULL

{% if is_incremental() %}
  {% if var("start_date", False) and var("end_date", False) %}
    AND review_date >= '{{ var("start_date") }}'
    AND review_date < '{{ var("end_date") }}'
  {% else %}
    AND review_date > (SELECT MAX(review_date) FROM {{ this }})
  {% endif %}
{% endif %}
```

Key features:
- **Incremental loading**: only processes new reviews on each run
- **Surrogate key**: generated from 4 columns using `dbt_utils`
- **Date-range variables**: supports `--vars '{"start_date": "...", "end_date": "..."}'`
- **Null filtering**: excludes records where `review_text` is NULL
- **Schema protection**: `on_schema_change = 'fail'` prevents silent schema drift

| Column | Test |
|--------|------|
| `listing_id` | `relationships` → `dim_listings_cleansed` |
| `reviewer_name` | `not_null` |
| `review_sentiment` | `accepted_values: ['positive', 'neutral', 'negative']` |

---

##  Packages

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.3.0
  - package: calogica/dbt_expectations
    version: [">=0.10.0", "<0.11.0"]
```

| Package | Used For |
|---------|---------|
| `dbt_utils` | `generate_surrogate_key` macro in `fct_reviews` |
| `dbt_expectations` | Advanced column-level tests (regex, quantile, type, count) |

---

##  Source Freshness

The `reviews` source has freshness monitoring configured:

```yaml
freshness:
  warn_after:  {count: 1,  period: hour}
  error_after: {count: 24, period: hour}
```

Run `dbt source freshness` to check whether source data is up to date.

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| dbt Core | Transformation framework |
| Snowflake | Cloud data warehouse |
| dbt_utils 1.3.0 | Surrogate key generation & utility macros |
| dbt_expectations | Advanced schema & data quality tests |
| Jinja2 | Templating, variables, conditional logic |
| YAML | Source configs, model docs, tests |

---

##  Getting Started

### 1. Install dependencies
```bash
pip install dbt-snowflake
```

### 2. Configure your profile (`~/.dbt/profiles.yml`)
```yaml
DBT_New_Project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: your_account
      user: your_username
      password: your_password
      role: TRANSFORMER
      database: AIRBNB
      warehouse: COMPUTE_WH
      schema: DEV
      threads: 4
```

### 3. Run the project
```bash
git clone https://github.com/Kelvin1993-prog/DBT_New_Project.git
cd DBT_New_Project

dbt deps                        # Install dbt_utils & dbt_expectations
dbt debug                       # Test connection
dbt source freshness            # Check source data freshness
dbt run                         # Build all models
dbt test                        # Run all tests
dbt run --select fct_reviews --vars '{"start_date": "2024-01-01", "end_date": "2024-02-01"}'
                                # Run incremental model for a specific date range
dbt docs generate && dbt docs serve   # Browse documentation
```

---

