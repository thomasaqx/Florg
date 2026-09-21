import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:florg/main.dart';

import 'fakes.dart';

/// Monta o app com repositórios de mentira, já autenticado quando pedido.
///
/// Todos precisam de dublê: com o repositório real, metas e orçamentos ficam
/// esperando uma rede que não existe no `flutter test`, e o indicador de
/// carregamento faz `pumpAndSettle` rodar para sempre.
Future<FakeFinancialRepository> pumpApp(
  WidgetTester tester, {
  bool signedIn = true,
  FakeFinancialRepository? financial,
  FakeImportRepository? imports,
  FakeFloraRepository? flora,
  FakeGoalsRepository? goals,
  FakeBudgetRepository? budgets,
}) async {
  final repository = financial ?? FakeFinancialRepository();
  await tester.pumpWidget(
    FlorgBootstrap(
      authRepository: FakeAuthRepository(signedIn: signedIn),
      financialRepository: repository,
      importRepository: imports ?? FakeImportRepository(),
      floraRepository: flora ?? FakeFloraRepository(),
      goalsRepository: goals ?? FakeGoalsRepository(),
      budgetRepository: budgets ?? FakeBudgetRepository(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void useDesktopSize(WidgetTester tester, {Size size = const Size(1440, 900)}) {
  _useSize(tester, size);
}

/// Abaixo do breakpoint de 600px: barra inferior no lugar da lateral.
void useMobileSize(WidgetTester tester, {Size size = const Size(390, 844)}) {
  _useSize(tester, size);
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Navega até a conversa com a FLORA.
Future<void> openFlora(WidgetTester tester) async {
  await tester.tap(find.text('FLORA AI').first);
  await tester.pumpAndSettle();
}

/// Navega até a tela de metas.
Future<void> openGoals(WidgetTester tester) async {
  await tester.tap(find.text('Metas').first);
  await tester.pumpAndSettle();
}
