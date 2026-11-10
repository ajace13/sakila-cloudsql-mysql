"""Run all 34 queries in sql/02_sakila_questions.sql and check each result.

Row counts were first recorded on Cloud SQL (MySQL 8.0, saved in notebooks/02_sql_questions_and_ai_checks.ipynb)
and match a local MySQL 8.0 load of the same Sakila 1.5 download.
"""
import re
from decimal import Decimal

import pytest
from conftest import SQL

TEXT = (SQL / "02_sakila_questions.sql").read_text(encoding="utf-8")
_parts = re.split(r"(?m)^-- Q(\d+):.*\n", TEXT)[1:]
QUERIES = {int(n): "\n".join(line for line in body.splitlines() if not line.startswith("--")).strip().rstrip(";")
           for n, body in zip(_parts[0::2], _parts[1::2])}

ROWS = {1: 223, 2: 417, 3: 1, 4: 3, 5: 1, 6: 377, 7: 10, 8: 1, 9: 1, 10: 1, 11: 819, 12: 1, 13: 1, 14: 1, 15: 1,
        16: 599, 17: 5, 18: 378, 19: 659, 20: 2, 21: 1, 22: 2, 23: 1, 24: 125, 25: 0, 26: 34, 27: 262, 28: 1,
        29: 0, 30: 1, 31: 53, 32: 10, 33: 8, 34: 183}


def test_all_34_queries_present():
    assert sorted(QUERIES) == list(range(1, 35))


def test_every_table_is_schema_qualified():
    for n, sql in QUERIES.items():
        for table in re.findall(r"\b(?:FROM|JOIN)\s+([\w.]+)", sql, re.I):
            assert table.startswith("sakila."), f"Q{n}: {table} is not schema-qualified"


@pytest.mark.parametrize("n", sorted(ROWS))
def test_row_count(query, n):
    assert len(query(QUERIES[n])) == ROWS[n]


def test_spot_values(query):
    assert query(QUERIES[3]) == (("Jon", "Stephens", "Jon.Stephens@sakilastaff.com"),)
    assert query(QUERIES[4]) == (("MEMENTO ZOOLANDER", 4), ("UNFORGIVEN ZOOLANDER", 7), ("ZOOLANDER FICTION", 5))
    assert query(QUERIES[5])[0][0] == Decimal("2.31")           # 0.99 x 14 / 6: this film rents for 6 days, not 7
    assert query(QUERIES[8])[0][0] == 1000
    assert query(QUERIES[9])[0] == (Decimal("0.00"), Decimal("11.99"))
    assert query(QUERIES[10])[0][0] == 520
    assert query(QUERIES[12])[0][0] == Decimal("66892.38")      # 2005 only: February 2006 payments excluded
    assert dict(query(QUERIES[17])) == {"PG-13": 223, "NC-17": 210, "R": 195, "PG": 194, "G": 178}
    assert query(QUERIES[20]) == (("CHARIOTS CONSPIRACY", "R", Decimal("29.99")), ("CUPBOARD SINNERS", "R", Decimal("29.99")))
    assert query(QUERIES[21])[0] == (Decimal("0.99"), 341)
    assert [r[0] for r in query(QUERIES[22])] == ["CONTROL ANTHEM", "HOME PITY"]
    assert query(QUERIES[28]) == ((582, "ANDY", "VANHORN"),)
    assert query(QUERIES[30])[0][0] == 10
    assert sorted(query(QUERIES[32]))[0] == ("Action", 64)
    assert [r[0] for r in query(QUERIES[33])] == ["Action", "Animation", "Children", "Classics", "Drama", "Games", "Sci-Fi", "Sports"]


def test_the_data_behind_the_two_empty_answers(query):
    # Q25 is empty because every film is in English; Q29 because address2 is NULL or '' everywhere.
    assert query("SELECT COUNT(DISTINCT language_id), COUNT(original_language_id) FROM sakila.film") == ((1, 0),)
    assert query("SELECT COUNT(*) FROM sakila.address WHERE address2 IS NOT NULL AND address2 <> ''") == ((0,),)
