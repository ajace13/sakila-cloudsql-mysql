"""Shared fixtures. The tests need a MySQL 8.0 server with the Sakila sample database loaded.

Connection settings come from the environment (nothing is stored in the repo):
  MYSQL_HOST (default 127.0.0.1), MYSQL_PORT (3306), MYSQL_USER (root), MYSQL_PASSWORD (empty),
  or MYSQL_UNIX_SOCKET to connect through a socket instead.
If no server is reachable, every database test is skipped.
"""
import os
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "sql"


def _connect():
    import pymysql

    kwargs = dict(user=os.environ.get("MYSQL_USER", "root"), password=os.environ.get("MYSQL_PASSWORD", ""),
                  database="sakila", autocommit=True, connect_timeout=5)
    if os.environ.get("MYSQL_UNIX_SOCKET"):
        kwargs["unix_socket"] = os.environ["MYSQL_UNIX_SOCKET"]
    else:
        kwargs["host"] = os.environ.get("MYSQL_HOST", "127.0.0.1")
        kwargs["port"] = int(os.environ.get("MYSQL_PORT", "3306"))
    return pymysql.connect(**kwargs)


@pytest.fixture(scope="session")
def db():
    try:
        con = _connect()
    except Exception as exc:  # no driver, no server or no sakila database
        pytest.skip(f"no MySQL with the sakila database reachable: {exc}")
    yield con
    con.close()


@pytest.fixture(scope="session")
def query(db):
    def run(sql, params=None):
        with db.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()
    return run


def split_statements(text):
    """Split a .sql file into statements: drops comment-only lines and splits on ';' at a line end."""
    body = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("--"))
    return [s.strip() for s in re.split(r";\s*(?:\n|$)", body) if s.strip()]


def run_script(db, path):
    """Run every statement of a .sql file and return the rows of the last one."""
    rows = None
    with db.cursor() as cur:
        for stmt in split_statements(path.read_text(encoding="utf-8")):
            cur.execute(stmt)
            rows = cur.fetchall()
    return rows
