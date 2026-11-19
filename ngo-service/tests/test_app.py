import psycopg2

NOVA_ONG = {"name": "Teto", "email": "contato@teto.org", "cause": "Moradia", "city": "Recife"}


def test_health(client):
    resposta = client.get("/health")

    assert resposta.status_code == 200
    assert resposta.get_json() == {"status": "ok", "service": "ngo-service"}


def test_lista_ongs(client, cursor):
    cursor.fetchall.return_value = [{"id": 1, "name": "Anjos de Patas"}]

    resposta = client.get("/ngos")

    assert resposta.status_code == 200
    assert resposta.get_json() == [{"id": 1, "name": "Anjos de Patas"}]


def test_cria_ong(client, cursor, ngo_app):
    _, pool = ngo_app
    cursor.fetchone.return_value = {"id": 3, **NOVA_ONG}

    resposta = client.post("/ngos", json=NOVA_ONG)

    assert resposta.status_code == 201
    assert resposta.get_json()["id"] == 3
    pool.getconn.return_value.commit.assert_called_once()
    pool.putconn.assert_called_once()


def test_rejeita_ong_sem_campos_obrigatorios(client, ngo_app):
    _, pool = ngo_app

    resposta = client.post("/ngos", json={"name": "Sem e-mail"})

    assert resposta.status_code == 400
    pool.getconn.assert_not_called()


def test_email_duplicado_retorna_409(client, cursor, ngo_app):
    _, pool = ngo_app
    cursor.execute.side_effect = psycopg2.IntegrityError("duplicate key")

    resposta = client.post("/ngos", json=NOVA_ONG)

    assert resposta.status_code == 409
    pool.getconn.return_value.rollback.assert_called_once()
    pool.putconn.assert_called_once()


def test_falha_no_banco_retorna_500_e_devolve_conexao(client, cursor, ngo_app):
    _, pool = ngo_app
    cursor.execute.side_effect = RuntimeError("conexão perdida")

    resposta = client.post("/ngos", json=NOVA_ONG)

    assert resposta.status_code == 500
    pool.getconn.return_value.rollback.assert_called_once()
    pool.putconn.assert_called_once()
