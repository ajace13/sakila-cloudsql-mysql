"""sql/06_payment_type.sql adds the lookup table and foreign key, can run twice, and leaves payments unchanged."""
from decimal import Decimal

import pytest
from conftest import SQL, run_script


@pytest.fixture
def migrated(db, query):
    before = query("SELECT COUNT(*), SUM(amount) FROM sakila.payment")
    first = run_script(db, SQL / "06_payment_type.sql")
    yield before, first
    run_script(db, SQL / "06_payment_type_rollback.sql")
    assert query("SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'sakila' "
                 "AND table_name = 'payment' AND column_name = 'payment_type_id'") == ((0,),)


def test_migration_adds_the_relationship(migrated, db, query):
    before, first = migrated
    assert first == ((1, 16044, Decimal("67406.56"), 0),)
    assert query("SELECT COUNT(*), SUM(amount) FROM sakila.payment") == before
    assert query("SELECT referenced_table_name, delete_rule FROM information_schema.referential_constraints "
                 "WHERE constraint_schema = 'sakila' AND constraint_name = 'fk_payment_payment_type'") == (("payment_type", "RESTRICT"),)


def test_migration_is_rerunnable(migrated, db):
    assert run_script(db, SQL / "06_payment_type.sql") == ((1, 16044, Decimal("67406.56"), 0),)


def test_foreign_key_is_enforced(migrated, query):
    import pymysql

    with pytest.raises(pymysql.err.IntegrityError):
        query("UPDATE sakila.payment SET payment_type_id = 99 WHERE payment_id = 1")
