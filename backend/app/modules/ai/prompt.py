"""What FLORA is told before she sees the question.

Lives outside the Claude provider so the prompt can be read, reviewed and
tested without touching the HTTP call.
"""

from decimal import Decimal

from app.modules.ai.context import FinancialContext
from app.modules.ai.formatting import format_day, format_money, format_percent

ZERO = Decimal("0")

SYSTEM_PROMPT = """\
Você é a FLORA, a inteligência financeira do FLORG (Financial Life Organizer).

Como você responde:
- Em português do Brasil, direto, sem rodeio e sem saudação a cada mensagem.
- Com a conta já feita e o motivo junto. Número primeiro, explicação depois.
- Curto: duas a quatro frases, a menos que peçam uma lista.
- Valores sempre no formato R$ 1.234,56.

O que você nunca faz:
- Inventar número. Use apenas os dados do contexto abaixo. Se o dado não
  estiver lá, diga o que falta e o que o usuário precisa registrar.
- Recomendar ativo, corretora ou produto financeiro específico. Você fala de
  fluxo de caixa, reserva e capacidade de aporte, não de onde aplicar.
- Prometer rentabilidade ou fazer projeção que os dados não sustentam.
- Julgar o usuário. Você aponta o número e o que ele significa.
"""


def _section(title: str, lines: list[str]) -> str:
    if not lines:
        return ""
    body = "\n".join(f"  {line}" for line in lines)
    return f"{title}:\n{body}\n"


def render_context(context: FinancialContext) -> str:
    """The user's numbers, as plain text for the model to read."""
    if not context.has_data:
        return (
            "DADOS FINANCEIROS DO USUÁRIO\n"
            "  Nenhuma conta ou lançamento registrado ainda.\n"
        )

    header = [
        f"Mês de referência: {context.month_label} "
        f"(faltam {context.days_left_in_month} dias para o fim do mês)",
        f"Saldo somado das contas: {format_money(context.total_balance)}",
        f"Entradas do mês: {format_money(context.month_income)}",
        f"Saídas do mês: {format_money(context.month_expenses)}",
        f"Resultado do mês: {format_money(context.month_net)}",
        f"Despesas do mês anterior: {format_money(context.previous_month_expenses)}",
        f"Lançamentos registrados: {context.transaction_count}",
    ]
    if context.savings_rate is not None:
        header.append(f"Sobra sobre a renda: {format_percent(context.savings_rate)}")
    if context.liabilities > ZERO:
        header.append(f"Fatura de cartão em aberto: {format_money(context.liabilities)}")

    accounts = [
        f"- {account.name} ({account.type}): {format_money(account.balance)}"
        for account in context.accounts
    ]

    categories = []
    for item in context.spending_by_category:
        line = (
            f"- {item.name}: {format_money(item.total)} "
            f"({format_percent(item.share_of_expenses)} das despesas)"
        )
        if item.previous_month_total is not None:
            line += f", mês anterior {format_money(item.previous_month_total)}"
        if item.change_percent is not None:
            line += f", variação {format_percent(item.change_percent)}"
        categories.append(line)

    budgets = [
        f"- {item.category_name}: gastou {format_money(item.spent)} de "
        f"{format_money(item.limit_amount)} "
        f"({format_percent(item.used_percent)}), restam {format_money(item.remaining)}"
        for item in context.budgets
    ]

    goals = []
    for goal in context.goals:
        line = (
            f"- {goal.title}: {format_money(goal.saved_amount)} de "
            f"{format_money(goal.target_amount)} "
            f"({format_percent(goal.progress_percent)}), faltam "
            f"{format_money(goal.remaining)}"
        )
        if goal.deadline is not None:
            line += f", prazo {goal.deadline.isoformat()}"
        if goal.monthly_needed is not None:
            line += f", precisa de {format_money(goal.monthly_needed)} por mês"
        goals.append(line)

    recurring = [
        f"- {item.description}: {format_money(item.amount)} "
        f"({item.months_seen} meses seguidos)"
        + (" — ainda não caiu neste mês" if item.pending_this_month else "")
        for item in context.recurring_expenses[:10]
    ]

    top_expenses = [
        f"- {item.description} ({item.category_name}): {format_money(item.amount)} "
        f"em {format_day(item.occurred_at)}"
        for item in context.top_expenses
    ]

    investments = [
        f"- Sobra do mês disponível para aporte: "
        f"{format_money(context.investments.available_to_invest)}",
        f"- Cobranças recorrentes que ainda vão cair neste mês: "
        f"{format_money(context.committed_this_month)}",
    ]
    if context.investments.reserve_months is not None:
        investments.append(
            f"- O saldo atual cobre {context.investments.reserve_months:.1f} meses "
            "de despesa"
        )

    sections = [
        _section("DADOS FINANCEIROS DO USUÁRIO", header),
        _section("CONTAS", accounts),
        _section("DESPESAS POR CATEGORIA NO MÊS", categories),
        _section("TETOS DE GASTO DEFINIDOS", budgets),
        _section("METAS", goals),
        _section("DESPESAS RECORRENTES", recurring),
        _section("MAIORES DESPESAS DO MÊS", top_expenses),
        _section("CAPACIDADE DE INVESTIMENTO", investments),
    ]
    return "\n".join(section for section in sections if section)
