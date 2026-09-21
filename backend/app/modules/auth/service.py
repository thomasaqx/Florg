from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ConflictError, UnauthorizedError
from app.core.security import hash_password, verify_password
from app.modules.auth.models import User
from app.modules.auth.schemas import UserCreate, UserUpdate


def get_user_by_email(db: Session, email: str) -> User | None:
    return db.scalar(select(User).where(User.email == email))


def create_user(db: Session, data: UserCreate) -> User:
    if get_user_by_email(db, data.email) is not None:
        raise ConflictError("E-mail já cadastrado")

    user = User(name=data.name, email=data.email, hashed_password=hash_password(data.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def update_user(db: Session, user: User, data: UserUpdate) -> User:
    changes = data.model_dump(exclude_unset=True)

    new_email = changes.get("email")
    if new_email is not None and new_email != user.email:
        # O e-mail e o login: deixar dois usuarios com o mesmo faria um deles
        # nunca mais conseguir entrar.
        if get_user_by_email(db, new_email) is not None:
            raise ConflictError("E-mail já cadastrado")

    for field, value in changes.items():
        setattr(user, field, value)

    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, email: str, password: str) -> User:
    """One error for a wrong e-mail and for a wrong password.

    Two different messages would turn the login form into a way of finding out
    which e-mails have an account here.
    """
    user = get_user_by_email(db, email)
    if user is None or not verify_password(password, user.hashed_password):
        raise UnauthorizedError("E-mail ou senha inválidos")
    return user
