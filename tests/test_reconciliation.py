"""The load, the top-customers query and the fact checks reconcile with the data."""
from decimal import Decimal

from conftest import SQL, run_script, split_statements


def test_load_matches_known_counts(query):
    first = split_statements((SQL / "01_verify_load.sql").read_text(encoding="utf-8"))[0]
    assert query(first) == ((16, 1000, 16044, Decimal("67406.56")),)


def test_row_counts_per_table(db):
    rows = dict(run_script(db, SQL / "01_verify_load.sql"))
    assert sum(rows.values()) == 47268 and rows["rental"] == 16044 and rows["film_actor"] == 5462


def test_top_customers_and_both_checks(query):
    top, check1, check2 = split_statements((SQL / "03_top_customers_by_store_city.sql").read_text(encoding="utf-8"))
    rows = query(top)
    assert [r[0] for r in rows] == [526, 148, 144, 137, 178]
    assert rows[0][4:] == ("Woodridge", 45, Decimal("221.55"))
    assert query(check1) == ((Decimal("67406.56"), Decimal("67406.56"), 1),)
    assert query(check2) == ((Decimal("67406.56"), Decimal("67406.56"), 599),)


def test_fact_checks(query):
    stmts = split_statements((SQL / "05_fact_checks.sql").read_text(encoding="utf-8"))
    assert query(stmts[0]) == ((1000, 200, 599),)
    assert query(stmts[1]) == ((16044, 16044),)
    assert query(stmts[2])[0] == ("PG-13", 223)
    assert [str(v) for v in query(stmts[3])[0]] == ["2005-05-24 22:53:30", "2006-02-14 15:16:03"]
    assert query(stmts[4]) == ((16,),)
    assert query(stmts[5]) == ((1, 326), (2, 273))
    assert query(stmts[6]) == ((599, Decimal("599")),)


def test_explain_plans_show_the_documented_access_types(db):
    with db.cursor() as cur:
        plans = []
        for stmt in split_statements((SQL / "04_explain_plans.sql").read_text(encoding="utf-8")):
            cur.execute(stmt)
            cols = [d[0] for d in cur.description]
            plans.append([dict(zip(cols, r)) for r in cur.fetchall()])
    q4, q17, q26 = plans
    assert (q4[0]["table"], q4[0]["type"], q4[0]["key"]) == ("film", "ALL", None)
    assert (q17[0]["table"], q17[0]["type"]) == ("film", "ALL") and "Using temporary" in q17[0]["Extra"]
    assert [(r["table"], r["type"]) for r in q26] == [("cat", "ALL"), ("fc", "ref"), ("i", "ref"), ("r", "ref"), ("c", "eq_ref")]
