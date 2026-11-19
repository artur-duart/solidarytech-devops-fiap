import importlib
import os
import sys
from unittest import mock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


@pytest.fixture
def ngo_app(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgres://teste:teste@localhost:5432/ngo_db")
    with mock.patch("psycopg2.pool.SimpleConnectionPool") as pool_cls:
        sys.modules.pop("app", None)
        app_module = importlib.import_module("app")
    app_module.app.config["TESTING"] = True
    return app_module, pool_cls.return_value


@pytest.fixture
def client(ngo_app):
    app_module, _ = ngo_app
    return app_module.app.test_client()


@pytest.fixture
def cursor(ngo_app):
    _, pool = ngo_app
    conn = pool.getconn.return_value
    return conn.cursor.return_value.__enter__.return_value
