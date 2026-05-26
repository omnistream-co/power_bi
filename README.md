# Power BI SQL Development Workflow

This repository provides a workflow for developing SQL-heavy Power BI reports while keeping SQL outside of PBIX/PBIP files.

Instead of editing SQL directly inside Power BI, SQL is extracted into standalone `.sql` files, formatted, version-controlled, and synced back into PBIP.

---

## Repository Structure


```text
power bi/
│
├── reports/
│   ├── Report_A/
│   │   ├── queries/
│   │   ├── Report_A.pbip
│   │   ├── Report_A.pbix
│   │   ├── Report_A.Report/
│   │   └── Report_A.SemanticModel/
│   │
│   └── Report_B/
│
├── scripts/
│   ├── extract_sql.py
│   ├── format_sql.py
│   ├── refresh_query_sources.py
│
└── README.md
```

---

## Full Workflow

```text
PBIX
↓
Save As PBIP
↓
extract_sql.py
↓
queries/*.sql
↓
format_sql.py
↓
edit + pg_format (if there is change in .sql files)
↓
refresh_query_sources.py
↓
update_pbi_params.py (for new merchant)
↓
open .pbip
↓
Refresh
↓
Save As PBIX
```

---

## Step 1: Convert PBIX → PBIP

Open your `.pbix`:

```text
File
→ Save As
→ Power BI Project (*.pbip)
```

Power BI generates:

```text
Report.pbip
Report.Report/
Report.SemanticModel/
```

This makes report contents editable as text.

---

## Step 2: Extract SQL

Extract all `Value.NativeQuery(...)` SQL into standalone `.sql` files.

Run:

```bash
python scripts/extract_sql.py
```

Or for a specific report:

```bash
python scripts/extract_sql.py --report "Violation Report"
```

Output:

```text
reports/
└── Violation Report/
    └── queries/
        ├── metrics.sql
        ├── shelves.sql
        ├── summary_metrics.sql
        └── ...
```

---

## Step 3: Format SQL

Format SQL files consistently.

Run:

```bash
python scripts/format_sql.py
```

Or:

```bash
python scripts/format_sql.py --report "Violation Report"
```

Formatting uses:

```text
pg_format
```

After formatting:

- edit SQL normally
- commit SQL changes
- review diffs easily

---

## Step 4: Sync SQL back to PBIP

Update Power BI query sources from SQL files:

```bash
python scripts/refresh_query_sources.py
```

Or:

```bash
python scripts/refresh_query_sources.py --report "Violation Report"
```

The script:

- finds matching tables
- extracts current SQL
- compares normalized SQL
- updates only changed queries
- preserves Power BI structure

Only matching `Value.NativeQuery(...)` objects are modified.

---
## Step 5: Update Environment Parameters

Before opening the report, update Power BI connection parameters:

- `url`
- `database`

Parameters are stored in:

```text
Report.SemanticModel/definition/expressions.tmdl
```

Run:

```bash
python scripts/update_pobi_params.py --report "Violation Report" 
    --env DEV
    --db merchant_db_17
```

## Step 6: Open PBIP

Open:

```text
Report.pbip
```

not:

```text
Report.pbix
```

---

## Step 7: Refresh

Inside Power BI:

```text
Refresh
```

Validate:

- SQL executes successfully
- visuals work
- parameters still function

---

## Step 8: Save Back to PBIX

Once validated:

```text
File
→ Save As
→ PBIX
```

---

## Notes

### Why use this workflow?

Benefits:

- SQL is version controlled
- cleaner diffs
- easier code review
- SQL formatter support
- avoid editing SQL inside Power BI
- easier collaboration

---

# Environment Setup

### Prerequisites

Install:

- Python 3.11+
- Git
- Conda (recommended)
- Power BI Desktop (Windows only)
- pg_format
- black.git@bracket-chaining

---

## Install pg_format

SQL formatting uses:

```text
pg_format
```

---

### Windows Setup

Download pgFormatter:

```text
https://github.com/darold/pgFormatter
```

Extract:

```text
C:\tools\pgFormatter
```

Verify:

```bash
C:\strawberry\perl\bin\perl.exe C:\tools\pgFormatter\pg_format --version
```

Expected:

```text
pg_format version 5.10
```

Create:

```text
C:\Users\<user>\miniconda3\envs\power_bi\Scripts\pg_format.bat
```

Contents:

```bat
@echo off
C:\strawberry\perl\bin\perl.exe C:\tools\pgFormatter\pg_format %*
```

Verify:

```bash
where pg_format
```

Expected:

```text
C:\Users\<user>\miniconda3\envs\power_bi\Scripts\pg_format.bat
```

---

### Linux Setup

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install pgformatter
```

---


# First-Time Report Setup

Create a folder under `reports/` for your report and place the original `.pbix` file inside.

Example:

```text
reports/
└── Violation Report Store Pog/
    └── Violation Report 2.5_output_store_pog.pbix
```

Open the PBIX in Power BI Desktop and convert it into a PBIP project:

```text
File
→ Save As in the same folder
→ Power BI Project (*.pbip)
```

Power BI will generate:

```text
reports/
└── Violation Report Store Pog/
    ├── Violation Report 2.5_output_store_pog.pbip
    ├── Violation Report 2.5_output_store_pog.pbix
    ├── Violation Report 2.5_output_store_pog.Report/
    └── Violation Report 2.5_output_store_pog.SemanticModel/
```

Once generated, follow the development workflow:

```text
extract_sql.py
↓
queries/*.sql
↓
format_sql.py
↓
edit SQL (if needed)
↓
refresh_query_sources.py
↓
update_powerbi_params.py (if needed)
↓
open .pbip
↓
Refresh
↓
Save As PBIX
```

# New Merchant Report Setup
From Step 5:

```text
update_pbi_params
↓
refresh_query_sources
↓
open PBIP
↓
Refresh
↓
Save PBIX
```

