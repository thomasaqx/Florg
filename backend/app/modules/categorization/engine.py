from abc import ABC, abstractmethod

# Keywords per category. No API cost, and kept behind an interface so it can be
# swapped for an ML/LLM model later without touching the rest of the system.
KEYWORD_RULES: dict[str, list[str]] = {
    "Alimentação": ["ifood", "restaurante", "mercado", "supermercado", "padaria"],
    "Transporte": ["uber", "99", "combustivel", "gasolina", "estacionamento"],
    "Assinaturas": ["netflix", "spotify", "amazon prime", "disney"],
    "Moradia": ["aluguel", "condominio", "energia", "agua", "internet"],
    "Saúde": ["farmacia", "drogaria", "hospital", "plano de saude"],
    "Lazer": ["cinema", "show", "bar", "viagem"],
    "Outros": [],
}


class CategorizationStrategy(ABC):
    """Contract for any transaction categorization strategy."""

    @abstractmethod
    def categorize(self, description: str) -> str:
        raise NotImplementedError


class KeywordCategorizationStrategy(CategorizationStrategy):
    """Categorizes by matching keywords in the description."""

    def categorize(self, description: str) -> str:
        normalized = description.lower()
        for category, keywords in KEYWORD_RULES.items():
            if any(keyword in normalized for keyword in keywords):
                return category
        return "Outros"


def get_categorization_strategy() -> CategorizationStrategy:
    # Single swap point: return an ML/LLM-based strategy here in the future.
    return KeywordCategorizationStrategy()
