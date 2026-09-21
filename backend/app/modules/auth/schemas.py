import uuid

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    # bcrypt only looks at the first 72 bytes; accepting more would silently
    # ignore the rest of what the user typed.
    password: str = Field(min_length=6, max_length=72)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    email: EmailStr


class UserUpdate(BaseModel):
    """PATCH do proprio perfil: so o que for enviado muda."""

    name: str | None = Field(default=None, min_length=1, max_length=120)
    email: EmailStr | None = None


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
