"""Application logging.

One place decides the format and the level, so a module only ever does
`logger = logging.getLogger(__name__)`.
"""

import logging
import sys

_FORMAT = "%(asctime)s %(levelname)-8s %(name)s | %(message)s"
_CONFIGURED = False


def configure_logging(level: str = "INFO") -> None:
    """Installs the handler once, even if the app is created more than once."""
    global _CONFIGURED
    if _CONFIGURED:
        return

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter(_FORMAT))

    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level.upper())

    # Uvicorn installs its own handlers; letting them propagate would print
    # every access line twice.
    for name in ("uvicorn", "uvicorn.access", "uvicorn.error"):
        logging.getLogger(name).handlers = [handler]
        logging.getLogger(name).propagate = False

    _CONFIGURED = True
