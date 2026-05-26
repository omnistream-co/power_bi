from pathlib import Path
import argparse
import subprocess
import shutil


REPORTS_DIR = Path("reports")


def find_query_dirs(report_name: str | None) -> list[Path]:
    """
    Find queries/ folders to format.

    If report_name is provided, only searches inside that report folder.
    Otherwise searches all reports under REPORTS_DIR.
    """
    if report_name:
        root = REPORTS_DIR / report_name

        if not root.exists():
            raise FileNotFoundError(f"Report not found: {root}")

        print(f"Formatting SQL for report: {report_name}")

    else:
        root = REPORTS_DIR
        print("No report specified. Formatting SQL for ALL reports.")

    return [path for path in root.rglob("queries") if path.is_dir()]


def find_pg_format() -> str:
    """
    Locate pg_format executable in PATH.

    Supports Windows (.bat/.exe) and Unix environments.
    """
    formatter = shutil.which("pg_format")

    if formatter:
        return formatter

    raise FileNotFoundError(
        "pg_format not found in PATH. "
        "Install pgFormatter or activate the correct environment."
    )


def format_sql_file(file: Path, formatter: str) -> bool:
    """
    Format a single SQL file using pg_format.

    pg_format writes the formatted SQL to stdout, so this function captures
    stdout and overwrites the original file only when the formatted content
    is different.

    Returns:
        True if the file was changed.
        False if the file was already formatted or formatting failed.
    """
    original = file.read_text(encoding="utf-8")

    result = subprocess.run(
        [formatter, str(file)],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"Formatter failed for: {file}\n"
            f"STDOUT:\n{result.stdout}\n"
            f"STDERR:\n{result.stderr}"
        )

    formatted = result.stdout

    if formatted != original:
        file.write_text(formatted, encoding="utf-8")
        return True

    return False


def main() -> None:
    """
    CLI entrypoint.

    Finds extracted SQL files under queries/ folders and formats them
    using pg_format.
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--report",
        default=None,
        help="Report folder name under reports/. If omitted, all reports are processed.",
    )

    args = parser.parse_args()

    formatter = find_pg_format()
    query_dirs = find_query_dirs(args.report)

    if not query_dirs:
        print("No queries folders found.")
        return

    changed = 0
    total = 0

    for query_dir in query_dirs:
        print(f"\nChecking: {query_dir}")

        for sql_file in query_dir.rglob("*.sql"):
            total += 1

            try:
                if format_sql_file(sql_file, formatter):
                    changed += 1
                    print(f"Formatted: {sql_file}")

            except Exception as e:
                print(f"\nFailed: {sql_file}")
                print(type(e).__name__, str(e))

    print(f"\nDone. Checked {total} SQL files. Formatted {changed} files.")


if __name__ == "__main__":
    main()
