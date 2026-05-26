from extract_sql import extract_native_query_sql_parts

from pathlib import Path
import argparse
import re

REPORTS_DIR = Path("reports")


def normalize_name(name: str) -> str:
    name = name.lower().strip()
    name = re.sub(r"_\d+$", "", name)
    name = re.sub(r"[^a-z0-9]+", "_", name)
    return name.strip("_")


def sql_to_m_expression(
    sql: str,
    multiline: bool = False,
) -> str:
    """
    Convert SQL text into a Power Query M string expression.

    Converts placeholders:

        {{bpid}}      -> " & bpid & "
        '{{bpid}}'    -> '" & bpid & "'

    Escapes SQL text and preserves the original formatting style:

    multiline=False:
        "#(lf)SELECT ...#(lf)"

    multiline=True:
        "
            SELECT ...
        "
    """

    tokens: list[str] = []

    def protect_placeholder(match: re.Match) -> str:
        tokens.append(match.group(0))
        return f"__M_TOKEN_{len(tokens) - 1}__"

    sql = re.sub(
        r"'\{\{\s*[A-Za-z_]\w*\s*\}\}'|\{\{\s*[A-Za-z_]\w*\s*\}\}",
        protect_placeholder,
        sql,
    )

    # Escape literal SQL double quotes for Power Query M strings.
    sql = sql.replace('"', '""')

    for i, token in enumerate(tokens):
        placeholder_match = re.search(
            r"\{\{\s*([A-Za-z_]\w*)\s*\}\}",
            token,
        )

        if not placeholder_match:
            continue

        variable_name = placeholder_match.group(1)

        if token.startswith("'") and token.endswith("'"):
            replacement = f"'\" & {variable_name} & \"'"
        else:
            replacement = f'" & {variable_name} & "'

        sql = sql.replace(f"__M_TOKEN_{i}__", replacement)

    if multiline:
        return (
            '"\n'
            + "\n".join("\t\t\t\t" + line for line in sql.splitlines())
            + '\n\t\t\t\t"'
        )

    sql = "#(lf)" + "#(lf)".join(line.rstrip() for line in sql.splitlines()) + "#(lf)"

    return f'"{sql}"'


def replace_native_query(
    text: str,
    sql: str,
) -> str:
    """
    Replace only second argument of Value.NativeQuery.

    Preserve original TMDL style:
      source = ```   -> multiline SQL
      source =       -> #(lf) SQL
    """

    multiline = bool(
        re.search(
            r"source\s*=\s*```",
            text,
            flags=re.IGNORECASE,
        )
    )
    m_sql = sql_to_m_expression(
        sql,
        multiline=multiline,
    )

    start = text.find("Value.NativeQuery")
    if start == -1:
        return text

    open_paren = text.find("(", start)
    if open_paren == -1:
        return text

    depth = 0
    in_string = False
    commas = []

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
                    break

            elif ch == "," and depth == 1:
                commas.append(i)

                if len(commas) == 2:
                    break

        i += 1

    if len(commas) < 2:
        return text

    first = commas[0]
    second = commas[1]

    if multiline:
        replacement = "\n" + m_sql
    else:
        replacement = " " + m_sql

    return text[: first + 1] + replacement + text[second:]


def find_query_dirs(report_name: str | None) -> list[Path]:
    root = REPORTS_DIR / report_name if report_name else REPORTS_DIR

    if report_name and not root.exists():
        raise FileNotFoundError(f"Report not found: {root}")

    print(
        f"Updating report: {report_name}"
        if report_name
        else "No report specified. Updating ALL reports."
    )

    return [
        path
        for path in root.rglob("queries")
        if path.is_dir()
        and (
            (path.parent / "Model" / "tables").exists()
            or any(path.parent.glob("*.SemanticModel"))
        )
    ]


def get_model_files(root: Path) -> list[Path]:
    files = []

    for suffix in ("*.tmdl", "*.m", "*.pq", "*.json", "*.pbism"):
        files.extend(root.rglob(suffix))

    return files


def file_matches_sql(file: Path, text: str, sql_name: str) -> bool:
    """
    Determine whether a SQL file belongs to a report object.

    Matching uses multiple candidate names:

    - filename stem
    - TMDL table declarations
    - query names
    - object name fields

    Example:

        summary_metrics.sql

    may match:

        table Summary Metrics

    after normalization.

    This allows SQL files to map correctly even when
    Power BI naming conventions differ.
    """
    candidates = {
        normalize_name(file.stem),
    }

    patterns = [
        r"\btable\s+['\"]?([^'\">\r\n]+)['\"]?",
        r"\bquery\s+['\"]?([^'\">\r\n]+)['\"]?",
        r"\bname:\s*['\"]?([^'\">\r\n]+)['\"]?",
    ]

    for pattern in patterns:
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            candidates.add(normalize_name(match.group(1)))

    return sql_name in candidates


def normalize_sql_for_compare(sql: str) -> str:
    """
    Normalize SQL for comparison only.

    Removes formatting differences while preserving semantics.

    Preserves:
    - single-quoted string literals
    - double-quoted identifiers
    - placeholders
    """

    protected_values = []

    def protect(match: re.Match) -> str:
        protected_values.append(match.group(0))
        return f"__SQL_PROTECTED_{len(protected_values) - 1}__"

    # Protect single-quoted strings: 'ABC', '{{bpid}}'
    sql = re.sub(
        r"'(?:''|[^'])*'",
        protect,
        sql,
    )

    # Protect double-quoted identifiers: "ProductCode"
    sql = re.sub(
        r'"(?:""|[^"])*"',
        protect,
        sql,
    )

    sql = sql.replace("\r\n", "\n").replace("\r", "\n")

    # Collapse whitespace
    sql = re.sub(r"\s+", " ", sql)

    # Normalize spaces around punctuation/operators
    sql = re.sub(r"\s*,\s*", ",", sql)
    sql = re.sub(r"\s*\(\s*", "(", sql)
    sql = re.sub(r"\s*\)\s*", ")", sql)
    sql = re.sub(r"\s*(=|<>|<=|>=|<|>)\s*", r"\1", sql)
    sql = re.sub(r"\s*\+\s*", "+", sql)
    sql = re.sub(r"\s*/\s*", "/", sql)

    sql = sql.strip().lower()

    # Restore protected values after lowercasing
    for i, value in enumerate(protected_values):
        sql = sql.replace(
            f"__sql_protected_{i}__",
            value,
        )

    return sql


def update_report(query_dir: Path) -> int:
    """
    Synchronize SQL files back into report model files.

    For each SQL file:

    1. Find matching report object
    2. Extract existing Value.NativeQuery SQL
    3. Compare normalized SQL
    4. Replace SQL if changed
    5. Save updated file

    Returns:
        Number of report files modified.
    """

    root = query_dir.parent
    updated_count = 0

    print(f"\nProcessing: {root}")

    model_files = sorted(get_model_files(root))

    for sql_file in sorted(query_dir.glob("*.sql")):
        sql_name = normalize_name(sql_file.stem)
        desired_sql = sql_file.read_text(encoding="utf-8")

        print(f"Using SQL: {sql_file.name} -> target name: {sql_name}")

        matched = False

        for file in model_files:
            text = file.read_text(
                encoding="utf-8",
                errors="ignore",
            )

            if "Value.NativeQuery" not in text:
                continue

            if not file_matches_sql(
                file,
                text,
                sql_name,
            ):
                continue

            matched = True
            existing_sqls = extract_native_query_sql_parts(text)

            if len(existing_sqls) > 1:
                raise ValueError(
                    f"{file.relative_to(REPORTS_DIR)} contains "
                    f"{len(existing_sqls)} Value.NativeQuery() blocks. "
                    "Each model file must contain exactly one Value.NativeQuery() block. "
                    "Multiple blocks may cause the wrong SQL query to be updated. "
                    "Please split queries into separate model files or "
                    "update the SQL sync logic."
                )

            existing_sql = existing_sqls[0]

            if normalize_sql_for_compare(existing_sql) == normalize_sql_for_compare(
                desired_sql
            ):
                print(f"No SQL change: " f"{file.relative_to(REPORTS_DIR)}")
                break

            new_text = replace_native_query(
                text,
                desired_sql,
            )

            if new_text != text:
                file.write_text(
                    new_text,
                    encoding="utf-8",
                )

                updated_count += 1
                print(f"Updated: {file.relative_to(REPORTS_DIR)}")
            else:
                print(f"Matched but no text change: {file.relative_to(REPORTS_DIR)}")

            break

        if not matched:
            print(f"No matching query found for {sql_file.name}")

    return updated_count


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--report",
        default=None,
        help="Report folder name under reports/. If omitted, all reports are updated.",
    )

    args = parser.parse_args()

    query_dirs = find_query_dirs(args.report)

    if not query_dirs:
        print("No queries folders found.")
        return

    total_updated = 0

    for query_dir in query_dirs:
        total_updated += update_report(query_dir)

    print(f"\nDone. Updated {total_updated} file(s).")


if __name__ == "__main__":
    main()
