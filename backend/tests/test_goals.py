"""Goals used to live only in the app's memory: closing it lost them."""


def _create(client, auth_headers, **overrides):
    payload = {
        "title": "Viagem em dezembro",
        "target_amount": "6000.00",
        "saved_amount": "1500.00",
        "deadline": "2026-12-01",
        "priority": "high",
        "icon": "viagem",
    }
    payload.update(overrides)
    return client.post("/goals", headers=auth_headers, json=payload)


def test_creates_and_lists_a_goal(client, auth_headers):
    response = _create(client, auth_headers)
    assert response.status_code == 201
    assert response.json()["title"] == "Viagem em dezembro"

    listed = client.get("/goals", headers=auth_headers).json()
    assert len(listed) == 1
    assert listed[0]["priority"] == "high"


def test_rejects_a_goal_without_a_target(client, auth_headers):
    response = _create(client, auth_headers, target_amount="0")
    assert response.status_code == 422


def test_updates_only_the_fields_sent(client, auth_headers):
    goal = _create(client, auth_headers).json()

    response = client.patch(
        f"/goals/{goal['id']}", headers=auth_headers, json={"title": "Viagem ao Chile"}
    )
    assert response.status_code == 200
    body = response.json()
    assert body["title"] == "Viagem ao Chile"
    assert body["target_amount"] == "6000.00"


def test_contribution_adds_to_what_is_saved(client, auth_headers):
    goal = _create(client, auth_headers).json()

    response = client.post(
        f"/goals/{goal['id']}/contributions", headers=auth_headers, json={"amount": "500.00"}
    )
    assert response.status_code == 200
    assert response.json()["saved_amount"] == "2000.00"


def test_contribution_cannot_push_the_goal_below_zero(client, auth_headers):
    goal = _create(client, auth_headers, saved_amount="100.00").json()

    response = client.post(
        f"/goals/{goal['id']}/contributions", headers=auth_headers, json={"amount": "-500.00"}
    )
    assert response.status_code == 422
    assert response.json()["code"] == "validation_error"


def test_linking_an_account_that_is_not_mine_is_rejected(client, auth_headers, account):
    other = client.post(
        "/auth/register",
        json={"name": "Outro", "email": "outro@florg.com.br", "password": "senha-forte-123"},
    )
    assert other.status_code == 201
    token = client.post(
        "/auth/login", data={"username": "outro@florg.com.br", "password": "senha-forte-123"}
    ).json()["access_token"]

    response = _create(
        client, {"Authorization": f"Bearer {token}"}, linked_account_id=account["id"]
    )
    assert response.status_code == 404


def test_cannot_touch_another_users_goal(client, auth_headers):
    goal = _create(client, auth_headers).json()

    client.post(
        "/auth/register",
        json={"name": "Intruso", "email": "intruso@florg.com.br", "password": "senha-forte-123"},
    )
    token = client.post(
        "/auth/login", data={"username": "intruso@florg.com.br", "password": "senha-forte-123"}
    ).json()["access_token"]
    intruder = {"Authorization": f"Bearer {token}"}

    assert client.get("/goals", headers=intruder).json() == []
    assert client.patch(f"/goals/{goal['id']}", headers=intruder, json={"title": "x"}).status_code == 404
    assert client.delete(f"/goals/{goal['id']}", headers=intruder).status_code == 404


def test_deletes_a_goal(client, auth_headers):
    goal = _create(client, auth_headers).json()

    assert client.delete(f"/goals/{goal['id']}", headers=auth_headers).status_code == 204
    assert client.get("/goals", headers=auth_headers).json() == []


def test_goals_require_authentication(client):
    assert client.get("/goals").status_code == 401
