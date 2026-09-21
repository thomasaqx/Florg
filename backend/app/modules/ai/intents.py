"""What the user is asking FLORA.

Keyword scoring, not a model: it runs in microseconds, costs nothing and is
the piece the offline provider needs to answer with the right number. When
Claude is configured this file is not used -- the model reads the question
itself.
"""

from enum import Enum

from app.modules.ai.formatting import normalize


class Intent(str, Enum):
    GREETING = "greeting"
    OVERVIEW = "overview"
    SPENDING_CAPACITY = "spending_capacity"
    CATEGORY_SPEND = "category_spend"
    OVERSPENDING = "overspending"
    BIGGEST_EXPENSES = "biggest_expenses"
    BUDGETS = "budgets"
    GOALS = "goals"
    INVESTING = "investing"
    RECURRING = "recurring"
    BALANCE = "balance"
    INCOME = "income"
    CAPABILITIES = "capabilities"
    UNKNOWN = "unknown"


# Phrases weigh more than single words: "quanto posso gastar" should win over
# the bare "gastar" that half of these questions contain.
_RULES: dict[Intent, list[tuple[str, int]]] = {
    Intent.GREETING: [
        ("ola", 3),
        ("oi flora", 4),
        ("bom dia", 3),
        ("boa tarde", 3),
        ("boa noite", 3),
        ("tudo bem", 2),
        ("obrigado", 3),
        ("obrigada", 3),
        ("valeu", 3),
    ],
    Intent.CAPABILITIES: [
        ("o que voce faz", 5),
        ("o que voce pode", 5),
        ("como voce funciona", 5),
        ("quem e voce", 5),
        ("no que pode ajudar", 4),
        ("me ajuda com o que", 4),
    ],
    Intent.OVERVIEW: [
        ("como estao minhas financas", 6),
        ("situacao financeira", 5),
        ("como esta minha situacao", 5),
        ("resumo", 3),
        ("como estou", 4),
        ("panorama", 3),
        ("como foi o mes", 4),
        ("visao geral", 4),
    ],
    Intent.SPENDING_CAPACITY: [
        ("quanto posso gastar", 6),
        ("quanto eu posso gastar", 6),
        ("posso gastar", 4),
        ("quanto sobra para gastar", 5),
        ("disponivel para gastar", 4),
        ("essa semana", 2),
        ("esta semana", 2),
        ("cabe no orcamento", 3),
    ],
    Intent.CATEGORY_SPEND: [
        ("quanto gastei com", 6),
        ("quanto gastei em", 6),
        ("quanto gasto com", 5),
        ("gastei com", 4),
        ("gasto com", 3),
        ("quanto foi de", 3),
    ],
    Intent.OVERSPENDING: [
        ("estou gastando demais", 6),
        ("estou gastando muito", 6),
        ("gastando demais", 5),
        ("gastando muito", 5),
        ("estou exagerando", 4),
        ("gastei demais", 4),
    ],
    Intent.BIGGEST_EXPENSES: [
        ("maiores despesas", 6),
        ("maiores gastos", 6),
        ("onde meu dinheiro", 5),
        ("com o que mais gastei", 5),
        ("maior gasto", 4),
        ("para onde vai", 4),
    ],
    Intent.BUDGETS: [
        ("orcamento", 4),
        ("orcamentos", 4),
        ("teto de gasto", 5),
        ("tetos de gasto", 5),
        ("meu teto", 4),
        ("meus tetos", 4),
        ("limite de gasto", 5),
        ("limites de gasto", 5),
        ("estourei", 4),
        ("estourou", 4),
        ("dentro do limite", 4),
    ],
    Intent.GOALS: [
        ("minha meta", 5),
        ("minhas metas", 5),
        ("para a meta", 4),
        ("quanto preciso guardar", 6),
        ("quanto falta para", 5),
        ("objetivo", 3),
        ("juntar para", 4),
        ("economizar para", 4),
    ],
    Intent.INVESTING: [
        ("posso investir", 6),
        ("quanto investir", 6),
        ("aportar", 4),
        ("investimento", 3),
        ("aplicar", 3),
        ("reserva de emergencia", 5),
    ],
    Intent.RECURRING: [
        ("assinatura", 5),
        ("assinaturas", 5),
        ("recorrente", 5),
        ("recorrentes", 5),
        ("todo mes", 3),
        ("mensalidade", 4),
        ("cobrancas repetidas", 5),
    ],
    Intent.BALANCE: [
        ("meu saldo", 5),
        ("qual o saldo", 5),
        ("quanto eu tenho", 5),
        ("quanto tenho na conta", 6),
        ("patrimonio", 4),
    ],
    Intent.INCOME: [
        ("quanto recebi", 6),
        ("quanto entrou", 5),
        ("minhas receitas", 5),
        ("meu salario", 4),
        ("minha renda", 4),
    ],
}


# Nomear uma categoria muda o sentido da pergunta: "estou gastando muito" e
# sobre o mes inteiro; "estou gastando muito com delivery" e sobre uma
# categoria. So entram aqui palavras que nomeiam gasto e nao sao a palavra
# chave de outro intent -- "assinatura" fica de fora porque pertence a
# RECURRING, e "viagem" porque costuma ser nome de meta.
_CATEGORY_MARKERS = (
    "alimentacao",
    "transporte",
    "moradia",
    "saude",
    "lazer",
    "delivery",
    "ifood",
    "mercado",
    "supermercado",
    "restaurante",
    "uber",
    "gasolina",
    "combustivel",
    "farmacia",
)
_CATEGORY_BOOST = 7


def detect_intent(message: str) -> Intent:
    """Highest-scoring intent, or UNKNOWN when nothing matches.

    A pontuacao e o maior peso que casou, nao a soma: varias regras do mesmo
    intent sao uma substring da outra ("gastando muito" dentro de "estou
    gastando muito"), e somar as duas daria a esse intent o dobro do peso que
    a regra declara.
    """
    text = normalize(message)

    scores: dict[Intent, int] = {}
    for intent, rules in _RULES.items():
        matched = [weight for phrase, weight in rules if phrase in text]
        scores[intent] = max(matched) if matched else 0

    if any(marker in text for marker in _CATEGORY_MARKERS):
        scores[Intent.CATEGORY_SPEND] += _CATEGORY_BOOST

    best_intent, best_score = max(scores.items(), key=lambda item: item[1])
    return best_intent if best_score > 0 else Intent.UNKNOWN
