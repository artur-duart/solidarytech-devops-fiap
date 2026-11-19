from unittest import mock

VOLUNTARIO = {"name": "Joao", "email": "joao@exemplo.org", "ngo_id": 1}


def test_health(client):
    resposta = client.get("/health")

    assert resposta.status_code == 200
    assert resposta.get_json() == {"status": "ok", "service": "volunteer-service"}


def test_inscreve_voluntario(client, volunteer_app):
    resposta = client.post("/volunteers", json=VOLUNTARIO)

    assert resposta.status_code == 201
    corpo = resposta.get_json()
    salvo = volunteer_app.table.get_item(Key={"volunteer_id": corpo["volunteer_id"]})["Item"]
    assert salvo["email"] == "joao@exemplo.org"


def test_rejeita_voluntario_sem_campos_obrigatorios(client):
    resposta = client.post("/volunteers", json={"name": "Sem ONG"})

    assert resposta.status_code == 400


def test_lista_apenas_voluntarios_da_ong(client):
    client.post("/volunteers", json=VOLUNTARIO)
    client.post("/volunteers", json={"name": "Ana", "email": "ana@exemplo.org", "ngo_id": 2})

    resposta = client.get("/volunteers/1")

    assert resposta.status_code == 200
    voluntarios = resposta.get_json()
    assert [v["email"] for v in voluntarios] == ["joao@exemplo.org"]


def test_ngo_id_mantem_o_mesmo_tipo_na_inscricao_e_na_listagem(client):
    inscrito = client.post("/volunteers", json=VOLUNTARIO).get_json()

    listado = client.get("/volunteers/1").get_json()[0]

    assert inscrito["ngo_id"] == listado["ngo_id"] == 1


def test_falha_no_dynamodb_retorna_500(client, volunteer_app):
    with mock.patch.object(volunteer_app.table, "put_item", side_effect=RuntimeError("throttling")):
        resposta = client.post("/volunteers", json=VOLUNTARIO)

    assert resposta.status_code == 500
