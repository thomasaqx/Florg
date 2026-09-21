"""FLORA answering offline, from the user's own numbers.

This is not a placeholder that says "hello, how can I help". Every sentence
below is built out of the FinancialContext, so the chat is usable before any
API key exists -- and when there is nothing to compute, it says so instead of
inventing a figure.
"""

from decimal import Decimal

from app.modules.ai.context import FinancialContext
from app.modules.ai.formatting import format_day, format_money, format_percent, normalize
from app.modules.ai.intents import Intent, detect_intent
from app.modules.ai.providers.base import AIProvider, AIReply, ChatTurn

ZERO = Decimal("0")

# Words people use that are not category names. Maps to the category the
# keyword-based categorizer actually files them under.
_CATEGORY_SYNONYMS = {
    "delivery": "Alimentação",
    "ifood": "Alimentação",
    "comida": "Alimentação",
    "mercado": "Alimentação",
    "supermercado": "Alimentação",
    "restaurante": "Alimentação",
    "uber": "Transporte",
    "gasolina": "Transporte",
    "combustivel": "Transporte",
    "carro": "Transporte",
    "streaming": "Assinaturas",
    "netflix": "Assinaturas",
    "spotify": "Assinaturas",
    "aluguel": "Moradia",
    "casa": "Moradia",
    "luz": "Moradia",
    "energia": "Moradia",
    "internet": "Moradia",
    "farmacia": "Saúde",
    "remedio": "Saúde",
    "medico": "Saúde",
    "academia": "Saúde",
    "cinema": "Lazer",
    "bar": "Lazer",
    "viagem": "Lazer",
}

_NO_DATA_AT_ALL = (
    "Ainda não tenho lançamentos para analisar. Assim que você importar o "
    "extrato do banco ou registrar algumas movimentações, eu consigo responder "
    "isso com os seus números de verdade."
)

_NO_MONTH_DATA = (
    "Não encontrei nenhuma movimentação em {month}. Registre os lançamentos "
    "do mês ou importe o extrato e eu refaço essa conta para você."
)


class MockAIProvider(AIProvider):
    """Answers from the context alone, with no external call."""

    name = "mock"

    async def reply(
        self,
        message: str,
        context: FinancialContext,
        history: list[ChatTurn],
    ) -> AIReply:
        intent = detect_intent(message)
        handler = _HANDLERS.get(intent, _unknown)

        # Greetings and "what can you do" work on an empty account; everything
        # else needs something to compute.
        needs_data = intent not in {Intent.GREETING, Intent.CAPABILITIES, Intent.UNKNOWN}
        if needs_data and not context.has_data:
            return AIReply(content=_NO_DATA_AT_ALL, provider=self.name, used_context=False)

        content = handler(message, context)
        return AIReply(
            content=content,
            provider=self.name,
            used_context=needs_data,
            metadata={"intent": intent.value},
        )


# --- helpers ---------------------------------------------------------------


def _no_month_data(context: FinancialContext) -> str:
    return _NO_MONTH_DATA.format(month=context.month_label)


def _join(sentences: list[str]) -> str:
    return " ".join(sentence for sentence in sentences if sentence)


def _category_names(context: FinancialContext) -> str:
    names = [item.name for item in context.spending_by_category[:5]]
    if not names:
        return ""
    if len(names) == 1:
        return names[0]
    return f"{', '.join(names[:-1])} e {names[-1]}"


def _find_category(message: str, context: FinancialContext):
    """Matches the question against the categories the month actually has."""
    text = normalize(message)

    for item in context.spending_by_category:
        if normalize(item.name) in text:
            return item

    for keyword, category_name in _CATEGORY_SYNONYMS.items():
        if keyword in text:
            for item in context.spending_by_category:
                if item.name == category_name:
                    return item
    return None


# --- one handler per intent ------------------------------------------------


def _greeting(message: str, context: FinancialContext) -> str:
    if not context.has_month_data:
        return (
            "Oi! Sou a FLORA, a inteligência financeira do FLORG. Ainda não vejo "
            "movimentações suas, mas assim que houver extrato eu respondo sobre "
            "quanto você pode gastar, para onde o dinheiro está indo e quanto dá "
            "para guardar."
        )
    return _join([
        f"Oi! Em {context.month_label} entraram {format_money(context.month_income)} e "
        f"saíram {format_money(context.month_expenses)}.",
        "Pode perguntar o que quiser sobre esses números.",
    ])


def _capabilities(message: str, context: FinancialContext) -> str:
    return (
        "Eu leio os seus lançamentos e respondo com a conta já feita. Dá para "
        "perguntar quanto você pode gastar até o fim do mês, quanto foi para cada "
        "categoria, se algum teto estourou, quanto falta para uma meta e quanto "
        "sobra para investir. Sempre com os números da sua conta, nunca com média "
        "de mercado."
    )


def _overview(message: str, context: FinancialContext) -> str:
    if not context.has_month_data:
        return _no_month_data(context)

    parts = [
        f"Em {context.month_label} entraram {format_money(context.month_income)} e "
        f"saíram {format_money(context.month_expenses)}, "
        f"{'sobrando' if context.month_net >= ZERO else 'faltando'} "
        f"{format_money(abs(context.month_net))}."
    ]

    if context.savings_rate is not None:
        rate = context.savings_rate
        if rate >= 20:
            parts.append(
                f"Isso é {format_percent(rate)} do que entrou — uma folga confortável."
            )
        elif rate >= 0:
            parts.append(f"São {format_percent(rate)} do que entrou ficando com você.")
        else:
            parts.append(
                f"O mês está {format_percent(abs(rate))} acima do que entrou, "
                "então a diferença está saindo do saldo."
            )

    if context.spending_by_category:
        top = context.spending_by_category[0]
        parts.append(
            f"A maior saída é {top.name}, com {format_money(top.total)} "
            f"({format_percent(top.share_of_expenses)} das despesas)."
        )

    if context.total_balance > ZERO:
        parts.append(f"O saldo somado das suas contas é {format_money(context.total_balance)}.")

    return _join(parts)


def _spending_capacity(message: str, context: FinancialContext) -> str:
    if not context.has_month_data:
        return _no_month_data(context)

    days_left = max(context.days_left_in_month, 0)
    committed = context.committed_this_month
    # A conta de luz que ainda nao chegou ja tem dono: oferecer esse dinheiro
    # como folga seria o erro mais caro que a FLORA pode cometer.
    leftover = context.month_net - committed

    if leftover <= ZERO:
        reason = (
            f"Neste mês as saídas já passaram as entradas em "
            f"{format_money(abs(context.month_net))}."
            if context.month_net <= ZERO
            else f"O que sobrou do mês ({format_money(context.month_net)}) já está "
            f"comprometido com {format_money(committed)} de cobranças que ainda "
            "vão cair."
        )
        return _join([
            reason,
            "Não há folga para gasto variável agora — o que for gasto sai do saldo "
            f"de {format_money(context.total_balance)} que você tem em conta.",
        ])

    weekly = min(leftover / Decimal(max(days_left, 1)) * Decimal("7"), leftover)

    parts = [
        f"Considerando o que entrou e o que já saiu em {context.month_label}, "
        f"sobram {format_money(leftover)} até o fim do mês."
    ]
    if committed > ZERO:
        parts.append(
            f"Isso já desconta {format_money(committed)} de cobranças recorrentes "
            "que ainda não caíram."
        )
    if days_left > 0:
        parts.append(
            f"Faltam {days_left} dias, então dá cerca de {format_money(weekly)} "
            "por semana para gasto variável."
        )

    tight = [item for item in context.budgets if item.remaining < ZERO]
    if tight:
        names = ", ".join(item.category_name for item in tight)
        parts.append(f"Vale olhar {names}: o teto do mês já foi passado.")

    return _join(parts)


def _category_spend(message: str, context: FinancialContext) -> str:
    if not context.spending_by_category:
        return _no_month_data(context)

    category = _find_category(message, context)
    if category is None:
        return _join([
            "Não achei essa categoria entre as suas despesas de "
            f"{context.month_label}.",
            f"As que aparecem por aqui são {_category_names(context)}.",
        ])

    parts = [
        f"Você gastou {format_money(category.total)} com {category.name} em "
        f"{context.month_label}. Isso é {format_percent(category.share_of_expenses)} "
        "das suas despesas do mês."
    ]

    if category.change_percent is not None and category.previous_month_total is not None:
        change = category.change_percent
        direction = "acima" if change >= 0 else "abaixo"
        parts.append(
            f"No mês passado foram {format_money(category.previous_month_total)}, "
            f"então está {format_percent(abs(change))} {direction}."
        )

    budget = next(
        (item for item in context.budgets if item.category_name == category.name), None
    )
    if budget is not None:
        if budget.remaining >= ZERO:
            parts.append(
                f"Do teto de {format_money(budget.limit_amount)} que você definiu, "
                f"ainda restam {format_money(budget.remaining)}."
            )
        else:
            parts.append(
                f"O teto era {format_money(budget.limit_amount)}, então passou "
                f"{format_money(abs(budget.remaining))}."
            )

    return _join(parts)


def _overspending(message: str, context: FinancialContext) -> str:
    if not context.has_month_data:
        return _no_month_data(context)

    parts = []
    if context.previous_month_expenses > ZERO:
        change = float(
            (context.month_expenses - context.previous_month_expenses)
            / context.previous_month_expenses
            * 100
        )
        if change >= 10:
            parts.append(
                f"Sim, um pouco: {format_money(context.month_expenses)} neste mês contra "
                f"{format_money(context.previous_month_expenses)} no mês passado, "
                f"{format_percent(change)} a mais."
            )
        elif change <= -10:
            parts.append(
                f"Pelo contrário: {format_money(context.month_expenses)} neste mês contra "
                f"{format_money(context.previous_month_expenses)} no anterior, "
                f"{format_percent(abs(change))} a menos."
            )
        else:
            parts.append(
                f"Está em linha com o mês passado: {format_money(context.month_expenses)} "
                f"contra {format_money(context.previous_month_expenses)}."
            )
    else:
        parts.append(
            f"Suas despesas somam {format_money(context.month_expenses)} em "
            f"{context.month_label}. Ainda não tenho um mês anterior completo para "
            "comparar."
        )

    over_budget = [item for item in context.budgets if item.remaining < ZERO]
    if over_budget:
        worst = min(over_budget, key=lambda item: item.remaining)
        parts.append(
            f"{worst.category_name} passou o teto em {format_money(abs(worst.remaining))}."
        )
    elif context.spending_by_category:
        climbing = [
            item
            for item in context.spending_by_category[:3]
            if item.change_percent is not None and item.change_percent >= 30
        ]
        if climbing:
            item = climbing[0]
            parts.append(
                f"O que mais subiu foi {item.name}: {format_percent(item.change_percent)} "
                f"em relação ao mês passado."
            )

    if context.month_net < ZERO:
        parts.append(
            f"No fim das contas o mês está negativo em {format_money(abs(context.month_net))}."
        )

    return _join(parts)


def _biggest_expenses(message: str, context: FinancialContext) -> str:
    if not context.top_expenses:
        return _no_month_data(context)

    lines = [
        f"- {item.description} ({item.category_name}): {format_money(item.amount)} "
        f"em {format_day(item.occurred_at)}"
        for item in context.top_expenses
    ]
    header = f"Suas maiores saídas de {context.month_label}:"
    footer = ""
    if context.spending_by_category:
        top = context.spending_by_category[0]
        footer = (
            f"\n\nPor categoria, {top.name} lidera com {format_money(top.total)} "
            f"({format_percent(top.share_of_expenses)} do total)."
        )
    return f"{header}\n" + "\n".join(lines) + footer


def _budgets(message: str, context: FinancialContext) -> str:
    if not context.budgets:
        return (
            "Você ainda não definiu teto nenhum. Em Configurações dá para colocar um "
            "limite por categoria e eu passo a avisar quando o mês estiver perto dele."
        )

    over = [item for item in context.budgets if item.remaining < ZERO]
    close = [
        item for item in context.budgets if ZERO <= item.remaining and item.used_percent >= 80
    ]

    lines = [
        f"- {item.category_name}: {format_money(item.spent)} de "
        f"{format_money(item.limit_amount)} ({format_percent(item.used_percent)})"
        for item in context.budgets
    ]
    parts = [f"Seus tetos em {context.month_label}:\n" + "\n".join(lines)]

    if over:
        names = ", ".join(item.category_name for item in over)
        parts.append(f"\n\nPassou do limite em {names}.")
    elif close:
        names = ", ".join(item.category_name for item in close)
        parts.append(f"\n\nPerto do limite: {names}.")
    else:
        parts.append("\n\nNenhum teto estourado até agora.")

    return "".join(parts)


def _goals(message: str, context: FinancialContext) -> str:
    if not context.goals:
        return (
            "Você ainda não tem metas cadastradas. Crie uma em Metas com o valor e o "
            "prazo, e eu calculo quanto precisa sair por mês para ela fechar no tempo."
        )

    lines = []
    for goal in context.goals:
        line = (
            f"- {goal.title}: {format_money(goal.saved_amount)} de "
            f"{format_money(goal.target_amount)} "
            f"({format_percent(goal.progress_percent)})"
        )
        if goal.monthly_needed is not None and goal.months_left:
            line += (
                f" — faltam {format_money(goal.remaining)}, ou "
                f"{format_money(goal.monthly_needed)} por mês nos {goal.months_left} "
                "meses que restam"
            )
        elif goal.remaining <= ZERO:
            line += " — concluída"
        else:
            line += f" — faltam {format_money(goal.remaining)}"
        lines.append(line)

    parts = ["Suas metas:\n" + "\n".join(lines)]

    needed = sum(
        (goal.monthly_needed for goal in context.goals if goal.monthly_needed is not None),
        ZERO,
    )
    if needed > ZERO:
        leftover = context.investments.available_to_invest
        if leftover >= needed:
            parts.append(
                f"\n\nJuntas elas pedem {format_money(needed)} por mês, e o mês está "
                f"deixando {format_money(leftover)} de folga. Cabe."
            )
        else:
            parts.append(
                f"\n\nJuntas elas pedem {format_money(needed)} por mês, mas o mês só "
                f"está deixando {format_money(leftover)}. Faltam "
                f"{format_money(needed - leftover)} para manter todas no prazo."
            )

    return "".join(parts)


def _investing(message: str, context: FinancialContext) -> str:
    if not context.has_month_data:
        return _no_month_data(context)

    available = context.investments.available_to_invest
    reserve = context.investments.reserve_months

    if available <= ZERO:
        return _join([
            f"Neste mês não sobrou nada: saíram {format_money(context.month_expenses)} "
            f"contra {format_money(context.month_income)} que entraram.",
            "Antes de aportar, vale fechar o mês no positivo.",
        ])

    parts = [f"Sobraram {format_money(available)} em {context.month_label}."]

    if reserve is None:
        parts.append("Esse é o valor que cabe no fluxo deste mês.")
    elif reserve < 3:
        parts.append(
            f"Seu saldo cobre {reserve:.1f} meses de despesa. Abaixo de 3 meses o "
            "caminho mais seguro é mandar essa sobra para a reserva de emergência "
            "antes de qualquer outra aplicação."
        )
    elif reserve < 6:
        parts.append(
            f"Seu saldo cobre {reserve:.1f} meses de despesa. Já dá para dividir: "
            "parte completando a reserva até 6 meses, parte em aplicação de prazo "
            "mais longo."
        )
    else:
        parts.append(
            f"Seu saldo já cobre {reserve:.1f} meses de despesa, então a reserva está "
            "coberta e essa sobra pode ir inteira para investimento."
        )

    committed = sum(
        (goal.monthly_needed for goal in context.goals if goal.monthly_needed is not None),
        ZERO,
    )
    if committed > ZERO:
        parts.append(
            f"Lembrando que suas metas já pedem {format_money(committed)} por mês."
        )

    return _join(parts)


def _recurring(message: str, context: FinancialContext) -> str:
    if not context.recurring_expenses:
        return (
            "Não encontrei cobrança que se repita mês a mês pelo mesmo valor. Preciso "
            "de pelo menos dois meses de extrato para reconhecer uma assinatura."
        )

    top = context.recurring_expenses[:8]
    lines = [
        f"- {item.description}: {format_money(item.amount)} "
        f"({item.months_seen} meses seguidos)"
        for item in top
    ]
    total = context.recurring_total
    share = ""
    if context.month_expenses > ZERO:
        share = (
            f" Isso é {format_percent(float(total / context.month_expenses * 100))} "
            "das suas despesas do mês."
        )

    return (
        f"Achei {len(context.recurring_expenses)} cobranças que se repetem todo mês, "
        f"somando {format_money(total)}:\n" + "\n".join(lines) + f"\n\n{share.strip()}"
    ).strip()


def _balance(message: str, context: FinancialContext) -> str:
    if not context.accounts:
        return (
            "Você ainda não cadastrou nenhuma conta. Crie uma em Contas e eu passo a "
            "acompanhar o saldo por aqui."
        )

    lines = [
        f"- {account.name}: {format_money(account.balance)}" for account in context.accounts
    ]
    parts = [
        f"Seu saldo somado é {format_money(context.total_balance)}, em "
        f"{len(context.accounts)} conta(s):\n" + "\n".join(lines)
    ]

    if context.liabilities > ZERO:
        parts.append(f"\n\nHá {format_money(context.liabilities)} em fatura de cartão em aberto.")

    reserve = context.investments.reserve_months
    if reserve is not None:
        parts.append(f"\n\nEsse saldo cobre {reserve:.1f} meses das suas despesas atuais.")

    return "".join(parts)


def _income(message: str, context: FinancialContext) -> str:
    if context.month_income <= ZERO:
        return (
            f"Não registrei nenhuma entrada em {context.month_label}. Se o salário já "
            "caiu, importe o extrato e eu atualizo a conta."
        )

    parts = [f"Entraram {format_money(context.month_income)} em {context.month_label}."]
    if context.month_expenses > ZERO:
        parts.append(
            f"Contra {format_money(context.month_expenses)} de despesa, "
            f"{'sobraram' if context.month_net >= ZERO else 'faltaram'} "
            f"{format_money(abs(context.month_net))}."
        )
    return _join(parts)


def _unknown(message: str, context: FinancialContext) -> str:
    if not context.has_data:
        return _NO_DATA_AT_ALL

    suggestions = [
        "quanto posso gastar até o fim do mês",
        "quanto gastei com alimentação",
        "quais foram minhas maiores despesas",
        "quanto posso investir este mês",
    ]
    return _join([
        "Não tenho certeza do que você quer saber.",
        "Posso responder, por exemplo: " + "; ".join(suggestions) + ".",
    ])


_HANDLERS = {
    Intent.GREETING: _greeting,
    Intent.CAPABILITIES: _capabilities,
    Intent.OVERVIEW: _overview,
    Intent.SPENDING_CAPACITY: _spending_capacity,
    Intent.CATEGORY_SPEND: _category_spend,
    Intent.OVERSPENDING: _overspending,
    Intent.BIGGEST_EXPENSES: _biggest_expenses,
    Intent.BUDGETS: _budgets,
    Intent.GOALS: _goals,
    Intent.INVESTING: _investing,
    Intent.RECURRING: _recurring,
    Intent.BALANCE: _balance,
    Intent.INCOME: _income,
    Intent.UNKNOWN: _unknown,
}
