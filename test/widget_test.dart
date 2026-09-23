import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

import 'package:florg/main.dart';

import 'support/fakes.dart';
import 'support/pump.dart';

void main() {
  testWidgets('sem sessão, mostra o login e valida os campos', (tester) async {
    await pumpApp(tester, signedIn: false);

    expect(find.text('Entrar no FLORG'), findsOneWidget);

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Use ao menos 6 caracteres.'), findsOneWidget);
  });

  testWidgets('início cumprimenta pelo nome e soma o saldo real', (
    tester,
  ) async {
    useDesktopSize(tester);
    await pumpApp(tester);

    // O subtítulo trazia "Florg" fixo no lugar do nome de quem entrou.
    expect(find.text('Olá, Ana'), findsOneWidget);
    expect(find.text('Saldo total'), findsOneWidget);
    // Aparece no card de saldo e no card da conta.
    expect(find.text('R\$ 4.200,00'), findsWidgets);
  });

  testWidgets('conta sem receita no mês não mostra NaN na taxa', (
    tester,
  ) async {
    useDesktopSize(tester);
    await pumpApp(
      tester,
      financial: FakeFinancialRepository(transactions: const []),
    );

    expect(find.text('Sobrou do que entrou'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.textContaining('NaN'), findsNothing);
  });

  testWidgets('navega para transações e mostra a contagem', (tester) async {
    useDesktopSize(tester);
    await pumpApp(tester);

    await tester.tap(find.text('Transações').first);
    await tester.pumpAndSettle();

    expect(find.text('3 lançamentos em 1 conta(s).'), findsOneWidget);
  });

  testWidgets('o avatar abre Configurações, não Metas', (tester) async {
    useDesktopSize(tester);
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();

    // Regressão: o botão apontava para o índice 6, que é a tela de metas.
    expect(find.text('Orçamentos mensais'), findsOneWidget);
    expect(find.text('Metas'), findsOneWidget); // só o item do menu lateral
  });

  testWidgets('sidebar recolhe e volta sem exceção', (tester) async {
    useDesktopSize(tester, size: const Size(1280, 800));
    await pumpApp(tester);

    expect(find.text('Organizador financeiro'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-sidebar')));
    await tester.pumpAndSettle();
    expect(find.text('Organizador financeiro'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('toggle-sidebar')));
    await tester.pumpAndSettle();
    expect(find.text('Organizador financeiro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ocultar saldos esconde os valores do início', (tester) async {
    useDesktopSize(tester);
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocultar saldos por padrão'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Início').first);
    await tester.pumpAndSettle();
    expect(find.text('••••••'), findsWidgets);
  });

  testWidgets('a aba Importar pede uma planilha', (tester) async {
    useDesktopSize(tester);
    await pumpApp(tester);

    await tester.tap(find.text('Importar').first);
    await tester.pumpAndSettle();

    // Título da página e botão do card de ajuda na lateral.
    expect(find.text('Importar extrato'), findsWidgets);
    expect(find.text('Escolher planilha'), findsOneWidget);
    expect(find.text('Para qual conta'), findsOneWidget);
  });

  testWidgets('insights saem do extrato e não de conselho fixo', (
    tester,
  ) async {
    useDesktopSize(tester);
    await pumpApp(tester);

    await tester.tap(find.text('Insights').first);
    await tester.pumpAndSettle();

    // Alimentação dobrou entre os dois meses do extrato falso.
    expect(find.textContaining('Alimentação subiu'), findsOneWidget);
    // As recomendações inventadas do mock não existem mais.
    expect(find.textContaining('Starbucks'), findsNothing);
    expect(find.textContaining('Netflix'), findsNothing);
  });

  testWidgets('sem lançamentos, insights explica o que falta', (tester) async {
    useDesktopSize(tester);
    await pumpApp(
      tester,
      financial: FakeFinancialRepository(transactions: const []),
    );

    await tester.tap(find.text('Insights').first);
    await tester.pumpAndSettle();

    expect(find.text('Nada para analisar ainda'), findsOneWidget);
  });

  testWidgets('Configurações mostra o usuário logado, não um nome fixo', (
    tester,
  ) async {
    useDesktopSize(tester);
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();

    // Regressão: os campos vinham preenchidos com "Florg"/"ana@florg.com".
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('ana@florg.com'), findsOneWidget);
    expect(find.text('Florg'), findsNothing);
  });

  testWidgets('salvar o perfil manda nome e e-mail para a API', (tester) async {
    useDesktopSize(tester);
    final auth = FakeAuthRepository(signedIn: true);
    await tester.pumpWidget(
      FlorgBootstrap(
        authRepository: auth,
        financialRepository: FakeFinancialRepository(),
        importRepository: FakeImportRepository(),
        floraRepository: FakeFloraRepository(),
        goalsRepository: FakeGoalsRepository(),
        budgetRepository: FakeBudgetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.text('Ana Souza'), 'Ana Lima');
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pumpAndSettle();

    expect(auth.savedProfile?.name, 'Ana Lima');
    expect(find.text('Perfil atualizado.'), findsOneWidget);
  });

  testWidgets('perfil sem nome não é salvo', (tester) async {
    useDesktopSize(tester);
    final auth = FakeAuthRepository(signedIn: true);
    await tester.pumpWidget(
      FlorgBootstrap(
        authRepository: auth,
        financialRepository: FakeFinancialRepository(),
        importRepository: FakeImportRepository(),
        floraRepository: FakeFloraRepository(),
        goalsRepository: FakeGoalsRepository(),
        budgetRepository: FakeBudgetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.text('Ana Souza'), '');
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pumpAndSettle();

    expect(auth.savedProfile, isNull);
    expect(find.text('Informe seu nome.'), findsOneWidget);
  });

  testWidgets('backend fora do ar mostra erro em vez de não fazer nada', (
    tester,
  ) async {
    // Regressão: AuthController._submit só capturava ApiException. Qualquer
    // outra falha escapava pela tela de login, o `if (!ok)` nunca rodava e o
    // usuário clicava em "Entrar" sem ver nada acontecer.
    final auth = FakeAuthRepository(signedIn: false)
      ..loginFailure = http.ClientException('Connection refused');
    await tester.pumpWidget(
      FlorgBootstrap(
        authRepository: auth,
        financialRepository: FakeFinancialRepository(),
        importRepository: FakeImportRepository(),
        floraRepository: FakeFloraRepository(),
        goalsRepository: FakeGoalsRepository(),
        budgetRepository: FakeBudgetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'ana@florg.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-forte');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Não consegui falar com o servidor'),
      findsOneWidget,
    );
    // A URL do dublê não é a porta da API, então o erro precisa dizer qual é.
    expect(find.textContaining('porta 8000'), findsOneWidget);
  });

  testWidgets('em debug, a tela de login mostra para onde o app aponta', (
    tester,
  ) async {
    // Sem isso, descobrir que --dart-define ficou com a URL antiga é chute:
    // a URL base é resolvida na compilação e hot restart não a atualiza.
    await pumpApp(tester, signedIn: false);

    expect(find.textContaining('API: http://fake'), findsOneWidget);
  });

  testWidgets('cofre do sistema indisponível também vira mensagem', (
    tester,
  ) async {
    final auth = FakeAuthRepository(signedIn: false)
      ..loginFailure = MissingPluginException('flutter_secure_storage');
    await tester.pumpWidget(
      FlorgBootstrap(
        authRepository: auth,
        financialRepository: FakeFinancialRepository(),
        importRepository: FakeImportRepository(),
        floraRepository: FakeFloraRepository(),
        goalsRepository: FakeGoalsRepository(),
        budgetRepository: FakeBudgetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'ana@florg.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha-forte');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('cofre do sistema'), findsOneWidget);
  });

  testWidgets('sessão guardada que falha cai no login, não trava carregando', (
    tester,
  ) async {
    // restoreSession também só capturava ApiException: uma falha do cofre
    // deixava a tela de sessão girando para sempre.
    final auth = _BrokenStorageAuthRepository();
    await tester.pumpWidget(
      FlorgBootstrap(
        authRepository: auth,
        financialRepository: FakeFinancialRepository(),
        importRepository: FakeImportRepository(),
        floraRepository: FakeFloraRepository(),
        goalsRepository: FakeGoalsRepository(),
        budgetRepository: FakeBudgetRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrar no FLORG'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

/// Cofre do sistema que recusa qualquer leitura, como acontece no Linux sem
/// libsecret.
class _BrokenStorageAuthRepository extends FakeAuthRepository {
  @override
  Future<bool> get isAuthenticated async =>
      throw MissingPluginException('flutter_secure_storage');
}
