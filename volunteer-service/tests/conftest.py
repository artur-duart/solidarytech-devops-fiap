import importlib
import os
import sys

import boto3
import pytest
from moto import mock_aws

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

TABELA = "SolidaryTechVolunteers"


@pytest.fixture
def volunteer_app(monkeypatch):
    monkeypatch.setenv("AWS_REGION", "us-east-1")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "teste")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "teste")
    monkeypatch.setenv("AWS_DYNAMODB_TABLE", TABELA)
    monkeypatch.delenv("AWS_ENDPOINT_URL_DYNAMODB", raising=False)

    with mock_aws():
        boto3.client("dynamodb", region_name="us-east-1").create_table(
            TableName=TABELA,
            AttributeDefinitions=[{"AttributeName": "volunteer_id", "AttributeType": "S"}],
            KeySchema=[{"AttributeName": "volunteer_id", "KeyType": "HASH"}],
            BillingMode="PAY_PER_REQUEST",
        )
        sys.modules.pop("app", None)
        app_module = importlib.import_module("app")
        app_module.app.config["TESTING"] = True
        yield app_module


@pytest.fixture
def client(volunteer_app):
    return volunteer_app.app.test_client()
