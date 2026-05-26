from pathlib import Path
import argparse
import hashlib
import re


REPORTS_DIR = Path("reports")
SEARCH_SUFFIXES = {".m", ".pq", ".json", ".tmdl", ".pbism"}


def clean_power_query_string(value: str) -> str:
    """
    Replace Power Query escape sequences with their literal characters.

    Converts #(lf), #(cr), and #(tab) into newline, carriage return,
    and tab characters respectively.
    """
    return (
        value.replace("#(lf)", "\n")
        .replace("#(cr)", "\r")
        .replace("#(tab)", "\t")
        .strip()
    )


def read_m_string(expr: str, start: int) -> tuple[str, int]:
    """
    Parse a quoted M string starting at the given index.

    Handles escaped double quotes ("") and returns:
    - parsed string content
    - index immediately after the closing quote

    Raises:
        ValueError: If input is not a valid M string.
    """
    if start >= len(expr) or expr[start] != '"':
        raise ValueError("Expected M string literal")

    i = start + 1
    chars = []

    while i < len(expr):
        if expr[i] == '"':
            if i + 1 < len(expr) and expr[i + 1] == '"':
                chars.append('"')
                i += 2
                continue

            return "".join(chars), i + 1

        chars.append(expr[i])
        i += 1

    raise ValueError("Unterminated M string literal")


def render_m_string_expression(expr: str) -> str:
    """
    Convert an M string expression into a readable SQL-like string.

    Static strings are concatenated directly while dynamic expressions
    are preserved as {{expression}} placeholders.

    Example:
        "SELECT * FROM " & table_name

    becomes:

        SELECT * FROM {{table_name}}
    """
    parts = []
    i = 0

    while i < len(expr):
        ch = expr[i]

        if ch.isspace() or ch == "&":
            i += 1
            continue

        if ch == '"':
            value, i = read_m_string(expr, i)
            parts.append(value)
            continue

        start = i
        depth = 0
        in_string = False

        while i < len(expr):
            c = expr[i]

            if c == '"':
                if in_string and i + 1 < len(expr) and expr[i + 1] == '"':
                    i += 2
                    continue
                in_string = not in_string

            elif not in_string:
                if c in "([{":
                    depth += 1
                elif c in ")]}":
                    if depth == 0:
                        break
                    depth -= 1
                elif c == "&" and depth == 0:
                    break

            i += 1

        dynamic_expr = expr[start:i].strip()

        if dynamic_expr:
            parts.append(f"{{{{{dynamic_expr}}}}}")

    return clean_power_query_string("".join(parts))


def extract_native_query_sql_parts(text: str) -> list[str]:
    """
    Extract SQL expressions passed into Value.NativeQuery().

    Finds the second argument of Value.NativeQuery(...) and converts
    M string expressions into readable SQL text.

    Returns:
        List of extracted SQL strings.
    """
    results = []
    keyword = "Value.NativeQuery"
    start = 0

    while True:
        idx = text.find(keyword, start)
        if idx == -1:
            break

        open_paren = text.find("(", idx)
        if open_paren == -1:
            break

        depth = 0
        in_string = False
        comma_count = 0
        second_arg_start = None
        second_arg_end = None
        i = open_paren

        while i < len(text):
            ch = text[i]

            if ch == '"':
                if in_string and i + 1 < len(text) and text[i + 1] == '"':
                    i += 2
                    continue
                in_string = not in_string

            elif not in_string:
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        if second_arg_start is not None:
                            second_arg_end = i
                        break
                elif ch == "," and depth == 1:
                    comma_count += 1

                    if comma_count == 1:
                        second_arg_start = i + 1
                    elif comma_count == 2:
                        second_arg_end = i
                        break

            i += 1

        if second_arg_start is not None and second_arg_end is not None:
            arg = text[second_arg_start:second_arg_end].strip()
            sql = render_m_string_expression(arg)

            if sql:
                results.append(sql)

        start = idx + len(keyword)

    return results


def is_report_root(path: Path) -> bool:
    """
    Determine whether a directory looks like a Power BI report root.

    Supports standard SemanticModel folder structures.
    """
    return (
        (path / "Model" / "tables").exists()
        or path.name.endswith(".SemanticModel")
        or (path / "SemanticModel").exists()
    )


def find_report_roots(report_name: str | None) -> list[Path]:
    """
    Find report roots to process.

    If report_name is provided, only that report is searched.
    Otherwise all report roots under REPORTS_DIR are returned.

    Nested report roots are deduplicated.
    """

    if report_name:
        root = REPORTS_DIR / report_name

        if not root.exists():
            raise FileNotFoundError(f"Report not found: {root}")

        print(f"Extracting SQL for report: {report_name}")

        roots = [
            path for path in root.rglob("*") if path.is_dir() and is_report_root(path)
        ]
        return roots or [root]

    print("No report specified. Extracting SQL from ALL reports.")

    roots = [
        path
        for path in REPORTS_DIR.rglob("*")
        if path.is_dir() and is_report_root(path)
    ]

    # Avoid processing nested roots twice.
    unique_roots: list[Path] = []
    for root in sorted(roots, key=lambda p: len(p.parts)):
        if not any(root.is_relative_to(existing) for existing in unique_roots):
            unique_roots.append(root)

    return unique_roots


def get_output_dir(report_root: Path) -> Path:
    """
    Determine where extracted SQL files should be written.
    """

    if report_root.name.endswith(".SemanticModel"):
        return report_root.parent / "queries"

    return report_root / "queries"


def clear_existing_sql_files(output_dir: Path) -> None:
    """
    Remove previously extracted SQL files from the output folder.
    """
    for file in output_dir.glob("*.sql"):
        file.unlink()


def make_sql_filename(source_file: Path) -> str:
    """
    Generate a SQL filename from the source filename.

    Converts the source stem into a normalized snake_case filename.

    Example:
        Summary Metrics.tmdl
        -> summary_metrics.sql
    """
    stem = re.sub(r"\W+", "_", source_file.stem.lower()).strip("_")
    return f"{stem}.sql"


def looks_like_sql(sql: str) -> bool:
    """
    Apply a lightweight SQL check.

    Keeps only SQL beginning with SELECT or WITH.
    """

    normalized = re.sub(r"^\s*(--.*\n|/\*.*?\*/\s*)+", "", sql, flags=re.DOTALL)
    normalized = normalized.lower().lstrip()
    return normalized.startswith("select") or normalized.startswith("with")


def extract_sql_from_folder(report_root: Path) -> int:
    """
    Extract SQL queries from a report folder.

    Searches supported files, extracts Value.NativeQuery SQL,
    removes duplicates, and writes results into queries/.

    Returns:
        Number of extracted SQL files.
    """

    output_dir = get_output_dir(report_root)
    output_dir.mkdir(parents=True, exist_ok=True)
    clear_existing_sql_files(output_dir)

    seen_sql_fingerprints = set()
    count = 0

    print(f"\nSearching: {report_root}")
    print(f"Saving SQL to: {output_dir}")

    for file in report_root.rglob("*"):
        if file.suffix.lower() not in SEARCH_SUFFIXES:
            continue

        text = file.read_text(encoding="utf-8", errors="ignore")

        if "Value.NativeQuery" not in text:
            continue

        for sql in extract_native_query_sql_parts(text):
            if not sql or not looks_like_sql(sql):
                continue

            sql_fingerprint = hashlib.md5(sql.encode("utf-8")).hexdigest()

            if sql_fingerprint in seen_sql_fingerprints:
                continue

            seen_sql_fingerprints.add(sql_fingerprint)
            count += 1

            # Assumes Power BI query/table names are unique.
            output_file = output_dir / make_sql_filename(file)

            if output_file.exists():
                existing_table = output_file.stem
                current_table = file.stem

                raise ValueError(
                    "\nDuplicate SQL filename detected.\n"
                    f"Existing SQL file : {output_file.name}\n"
                    f"Current table     : {current_table}\n"
                    f"Normalized name   : {existing_table}\n\n"
                    "Multiple Power BI queries/tables normalized "
                    "to the same SQL filename.\n"
                    "Please rename one of the Power BI tables/queries "
                    "to keep names unique."
                )

            output_file.write_text(sql + "\n", encoding="utf-8")

            print(f"Saved: {output_file}")

    print(f"Extracted {count} SQL file(s).")
    return count


def main() -> None:
    """
    CLI entrypoint.

    Processes either a specific report or all reports under
    REPORTS_DIR and writes extracted SQL files.
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--report",
        default=None,
        help="Report folder name under reports/. If omitted, all reports are processed.",
    )

    args = parser.parse_args()

    report_roots = find_report_roots(args.report)

    if not report_roots:
        print("No report roots found.")
        return

    total = 0

    for report_root in report_roots:
        total += extract_sql_from_folder(report_root)

    print(f"\nDone. Extracted {total} SQL file(s).")


if __name__ == "__main__":
    main()
