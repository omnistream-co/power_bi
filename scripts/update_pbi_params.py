"""
Update Power BI report sources and parameters.

This script updates a pbi-tools extracted Power BI report by:

1. Replacing dynamic PostgreSQL.Database(...) calls with static server/database
   values to avoid Power BI Service dynamic data source refresh issues.

2. Updating Power BI parameters in expressions.tmdl:
   - Para_gen_id
   - Para_base_pog_id
   - Para_store_code

The latest parameter values are fetched from output_store_pog in the selected
environment/database.

Example:
    python scripts/update_pbi_params.py --report "Violation Report Store Pog" --env dev --db merchant_db_6
"""

from pathlib import Path
import argparse
import re

from sqlalchemy import text
from common import load_secrets, get_connection


REPORTS_DIR = Path("reports")


def find_report_directory(report_name: str) -> Path:
    """Return the report folder path under reports/."""
    report_dir = REPORTS_DIR / report_name

    if not report_dir.exists():
        raise FileNotFoundError(f"Report folder not found: {report_dir}")

    if not report_dir.is_dir():
        raise NotADirectoryError(f"Report path is not a folder: {report_dir}")

    return report_dir


def find_expressions_file(report_dir: Path) -> Path:
    """Find the expressions.tmdl file for a report."""
    matches = list(report_dir.rglob("expressions.tmdl"))

    if not matches:
        raise FileNotFoundError(f"No expressions.tmdl found in {report_dir}")

    if len(matches) > 1:
        print("Multiple expressions.tmdl files found. Using first:")
        for match in matches:
            print(f" - {match}")

    return matches[0]


def build_static_postgres_source(env: str, database: str) -> str:
    """Build a static PostgreSQL.Database(...) call for Power Query."""
    env_secrets = load_secrets(env)

    server = f"{env_secrets['host']}:{env_secrets['port']}"

    return (
        f"PostgreSQL.Database("
        f"{quote_m_text(server)}, "
        f"{quote_m_text(database)}"
        f")"
    )


def replace_postgres_sources(
    text_content: str,
    env: str,
    database: str,
) -> tuple[str, int]:
    """Replace PostgreSQL.Database(...) calls with static source values."""
    replacement = build_static_postgres_source(env, database)

    pattern = re.compile(
        r"PostgreSQL\.Database\(\s*"
        r"(?:\"(?:\"\"|[^\"])*\"|[^,()]*)"
        r"\s*,\s*"
        r"(?:\"(?:\"\"|[^\"])*\"|[^,()]*)"
        r"\s*\)",
        re.DOTALL,
    )

    return pattern.subn(replacement, text_content)


def iter_power_query_files(report_dir: Path) -> list[Path]:
    """
    Return report files that contain PostgreSQL.Database(...) calls.

    This avoids modifying unrelated TMDL files that only define tables,
    relationships, or metadata.
    """

    files = []

    for path in report_dir.rglob("*"):
        if not path.is_file():
            continue

        if path.suffix.lower() not in {".m", ".pqm", ".tmdl"}:
            continue

        text = path.read_text(encoding="utf-8", errors="ignore")

        if "PostgreSQL.Database(" in text:
            files.append(path)

    return sorted(files)


def fetch_latest_report_params(
    env: str,
    database: str,
) -> tuple[int, int, str]:
    """Fetch latest gen_id, base_pog_id, and store_code from output_store_pog."""
    engine = get_connection(env=env, database=database)

    sql = text(
        """
        SELECT filter_config_id, base_pog_id, store AS store_code
        FROM output_store_pog
        WHERE is_latest_version
          AND base_pog_id IS NOT NULL
          AND status = 'DONE'
        ORDER BY id DESC
        LIMIT 1
        """
    )

    with engine.connect() as conn:
        row = conn.execute(sql).first()

    if row is None:
        raise ValueError("No valid output_store_pog records found")

    return row.filter_config_id, row.base_pog_id, row.store_code


def update_query_source_file(
    file_path: Path,
    env: str,
    database: str,
) -> int:
    """Update PostgreSQL source calls in one file and return replacement count."""
    text_content = file_path.read_text(encoding="utf-8", errors="ignore")

    updated_text, replacement_count = replace_postgres_sources(
        text_content,
        env=env,
        database=database,
    )

    if replacement_count:
        file_path.write_text(updated_text, encoding="utf-8")

    return replacement_count


def quote_m_text(value) -> str:
    """Quote a value as Power Query M text."""
    value = str(value)
    return '"' + value.replace('"', '""') + '"'


def update_expression_if_exists(
    text: str,
    name: str,
    value,
) -> str:
    """
    Update an existing TMDL expression while preserving metadata.

    If the current expression value is quoted, the new value is written as text.
    Otherwise, the new value is written as a raw value, such as a number.
    Missing expressions are skipped.
    """
    pattern = re.compile(
        rf"(?m)^(expression\s+{re.escape(name)}\s*=\s*)"
        rf"(.*?)"
        rf"(\s+meta\s+\[.*\])$"
    )

    match = pattern.search(text)

    if not match:
        print(f"Skipping missing parameter: {name}")
        return text

    current_value = match.group(2).strip()

    if current_value.startswith('"'):
        replacement_value = quote_m_text(value)
    else:
        replacement_value = str(value)

    return pattern.sub(
        rf"\g<1>{replacement_value}\g<3>",
        text,
    )


def update_report_parameters(
    expressions_file: Path,
    env: str,
    database: str,
) -> None:
    """Update Para_gen_id, Para_base_pog_id, and Para_store_code."""
    text_content = expressions_file.read_text(encoding="utf-8", errors="ignore")

    gen_id, base_pog_id, store_code = fetch_latest_report_params(env, database)

    text_content = update_expression_if_exists(text_content, "Para_gen_id", gen_id)
    text_content = update_expression_if_exists(
        text_content,
        "Para_base_pog_id",
        base_pog_id,
    )
    text_content = update_expression_if_exists(
        text_content,
        "Para_storecode",
        str(store_code),
    )

    expressions_file.write_text(text_content, encoding="utf-8")

    print(f"Para_gen_id = {gen_id}")
    print(f"Para_base_pog_id = {base_pog_id}")
    print(f"Para_store_code = {store_code}")


def update_report_postgres_sources(
    report_dir: Path,
    env: str,
    database: str,
) -> None:
    """Replace PostgreSQL.Database(...) calls across report query files."""
    files = iter_power_query_files(report_dir)

    total_replacements = 0
    updated_files = 0

    for file_path in files:
        replacement_count = update_query_source_file(
            file_path,
            env=env,
            database=database,
        )

        if replacement_count:
            updated_files += 1
            total_replacements += replacement_count
            print(f"Updated {replacement_count} source(s): {file_path}")

    print(f"files scanned = {len(files)}")
    print(f"files updated = {updated_files}")
    print(f"sources updated = {total_replacements}")

    if total_replacements == 0:
        print("No PostgreSQL.Database(...) calls were found.")


def update_powerbi_report(
    report_name: str,
    env: str,
    database: str,
) -> None:
    """Update both report parameters and static PostgreSQL data sources."""
    report_dir = find_report_directory(report_name)
    expressions_file = find_expressions_file(report_dir)

    update_report_parameters(
        expressions_file=expressions_file,
        env=env,
        database=database,
    )

    update_report_postgres_sources(
        report_dir=report_dir,
        env=env,
        database=database,
    )

    print("Done")
    print(f"report = {report_name}")
    print(f"env = {env}")
    print(f"database = {database}")


def main() -> None:
    """Parse CLI arguments and update the selected Power BI report."""
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--report",
        required=True,
        help="Report folder name under reports/",
    )

    parser.add_argument(
        "--env",
        required=True,
        help="Environment name, e.g. dev/qa/prod",
    )

    parser.add_argument(
        "--db",
        required=True,
        help="Database name, e.g. merchant_db_17",
    )

    args = parser.parse_args()

    update_powerbi_report(
        report_name=args.report,
        env=args.env,
        database=args.db,
    )


if __name__ == "__main__":
    main()
