from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.modules.ai.schemas import (
    AIStatus,
    ChatRequest,
    ChatResponse,
    FinancialContextResponse,
)
from app.modules.ai.service import AIService, get_ai_service
from app.modules.ai.providers.base import ChatTurn
from app.modules.auth.dependencies import get_current_user
from app.modules.auth.models import User

router = APIRouter(prefix="/ai", tags=["flora"])

# Shown in the empty state of the chat.
SUGGESTIONS = [
    "Como estão minhas finanças?",
    "Quanto posso gastar?",
    "Analise meus gastos",
    "Posso investir este mês?",
]


@router.get("/status", response_model=AIStatus)
def ai_status(
    service: AIService = Depends(get_ai_service),
    current_user: User = Depends(get_current_user),
):
    return AIStatus(
        provider=service.provider_name,
        is_live=service.is_live,
        suggestions=SUGGESTIONS,
    )


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    service: AIService = Depends(get_ai_service),
):
    """Answers as FLORA, always scoped to the authenticated user's data."""
    reply = await service.answer(
        db,
        current_user.id,
        request.message,
        history=[ChatTurn(role=item.role, content=item.content) for item in request.history],
    )
    return ChatResponse(
        content=reply.content,
        provider=reply.provider,
        model=reply.model,
        used_context=reply.used_context,
    )


@router.get("/context", response_model=FinancialContextResponse)
def financial_context(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    service: AIService = Depends(get_ai_service),
):
    """The context FLORA reads, so the numbers in the chat can be checked."""
    return FinancialContextResponse(context=service.context_for(db, current_user.id))
