"""Domain errors.

Services raise these; routers stay thin. The alternative -- every service
returning None and every router guessing which HTTP status that None meant --
spread the business rules across the handlers and made "not found" and
"not yours" indistinguishable.
"""

from fastapi import status


class DomainError(Exception):
    """Base for every error the application raises on purpose."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "domain_error"

    # Extra response headers, for the errors whose HTTP status requires one.
    headers: dict[str, str] | None = None

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        if code is not None:
            self.code = code
        if headers is not None:
            self.headers = headers


class NotFoundError(DomainError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"


class ConflictError(DomainError):
    status_code = status.HTTP_409_CONFLICT
    code = "conflict"


class ValidationError(DomainError):
    # The literal, not status.HTTP_422_*: Starlette renamed the constant and
    # reading the old name emits a DeprecationWarning at import time.
    status_code = 422
    code = "validation_error"


class UnauthorizedError(DomainError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "unauthorized"
    # RFC 6750: a 401 on a bearer-token API has to say which scheme it wants.
    headers = {"WWW-Authenticate": "Bearer"}


class ServiceUnavailableError(DomainError):
    """A dependency the request needed is not answering (or not configured)."""

    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "service_unavailable"
