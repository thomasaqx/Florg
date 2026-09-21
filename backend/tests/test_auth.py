def test_register_returns_user_without_password(client):
    response = client.post(
        "/auth/register",
        json={"name": "Ana", "email": "ana@florg.com.br", "password": "senha-forte-123"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "ana@florg.com.br"
    # Neither the password nor its hash may ever travel back to the client.
    assert "password" not in body
    assert "hashed_password" not in body


def test_register_rejects_duplicate_email(client):
    payload = {"name": "Ana", "email": "ana@florg.com.br", "password": "senha-forte-123"}
    client.post("/auth/register", json=payload)
    response = client.post("/auth/register", json=payload)
    assert response.status_code == 409


def test_password_is_hashed_in_database(client, db_session):
    from app.modules.auth.models import User

    client.post(
        "/auth/register",
        json={"name": "Ana", "email": "ana@florg.com.br", "password": "senha-forte-123"},
    )
    user = db_session.query(User).filter_by(email="ana@florg.com.br").one()
    assert user.hashed_password != "senha-forte-123"
    assert user.hashed_password.startswith("$2b$")


def test_login_with_wrong_password_is_rejected(client):
    client.post(
        "/auth/register",
        json={"name": "Ana", "email": "ana@florg.com.br", "password": "senha-forte-123"},
    )
    response = client.post(
        "/auth/login", data={"username": "ana@florg.com.br", "password": "senha-errada"}
    )
    assert response.status_code == 401


def test_me_returns_current_user(client, auth_headers):
    response = client.get("/auth/me", headers=auth_headers)
    assert response.status_code == 200
    assert response.json()["email"] == "thomas@florg.com.br"


def test_protected_route_requires_token(client):
    assert client.get("/accounts").status_code == 401


def test_malformed_token_returns_401_not_500(client):
    """Regression: a non-UUID 'sub' raised ValueError and became an HTTP 500."""
    import jwt

    from app.core.config import get_settings

    settings = get_settings()
    token = jwt.encode({"sub": "nao-e-um-uuid"}, settings.secret_key, algorithm=settings.algorithm)
    response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401


def test_token_signed_with_other_secret_is_rejected(client):
    import jwt

    token = jwt.encode({"sub": "qualquer"}, "chave-do-atacante", algorithm="HS256")
    response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401


def test_updates_own_profile(client, auth_headers):
    response = client.patch(
        "/auth/me", headers=auth_headers, json={"name": "Thomas Lima"}
    )
    assert response.status_code == 200
    assert response.json()["name"] == "Thomas Lima"
    # O e-mail nao foi enviado, entao continua o mesmo.
    assert response.json()["email"] == "thomas@florg.com.br"


def test_cannot_take_an_email_that_is_already_used(client, auth_headers):
    client.post(
        "/auth/register",
        json={"name": "Outro", "email": "outro@florg.com.br", "password": "senha-forte-123"},
    )
    response = client.patch(
        "/auth/me", headers=auth_headers, json={"email": "outro@florg.com.br"}
    )
    assert response.status_code == 409


def test_profile_update_requires_a_token(client):
    assert client.patch("/auth/me", json={"name": "Invasor"}).status_code == 401
