import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:florg/src/models/navigation_item.dart';

import 'support/fakes.dart';
import 'support/pump.dart';

/// Abre cada tela nas três larguras e falha se alguma estourar o layout.
///
/// Um RenderFlex que transborda não quebra o app, então passava despercebido
/// até alguém abrir o FLORG no celular e ver a faixa listrada.
void main() {
  final sizes = <String, Size>{
    'celular': const Size(390, 844),
    'tablet': const Size(834, 1112),
    'desktop': const Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    group('em ${entry.key}', () {
      testWidgets('nenhuma tela estoura o layout', (tester) async {
        _useSize(tester, entry.value);
        await pumpApp(tester, goals: _goalsWithOne());

        for (var index = 0; index < appNavItems.length; index++) {
          await _openPage(tester, index, isCompact: entry.value.width < 900);
          expect(
            tester.takeException(),
            isNull,
            reason: 'tela "${appNavItems[index].label}" estourou em ${entry.key}',
          );
        }
      });
    });
  }

  testWidgets('no celular a barra inferior mostra cinco destinos', (
    tester,
  ) async {
    useMobileSize(tester);
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    // Quatro telas mais o "Mais": nove destinos numa barra de 390px viram
    // alvos que ninguém acerta.
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(NavigationDestination),
      ),
      findsNWidgets(mobileNavPages.length + 1),
    );
    expect(find.text('Mais'), findsOneWidget);
  });

  testWidgets('o menu "Mais" abre as telas que não cabem na barra', (
    tester,
  ) async {
    useMobileSize(tester);
    await pumpApp(tester);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();

    expect(find.text('Importar'), findsWidgets);
    expect(find.text('Configurações'), findsOneWidget);

    await tester.tap(find.text('Metas').last);
    await tester.pumpAndSettle();

    expect(find.text('Nova meta'), findsOneWidget);
  });

  testWidgets('no desktop a barra lateral aparece no lugar da inferior', (
    tester,
  ) async {
    useDesktopSize(tester);
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Organizador financeiro'), findsOneWidget);
  });

  testWidgets('a barra lateral rola quando a tela é baixa', (tester) async {
    // 9 itens de menu, o botão de sair e o card de ajuda não cabem em 700px
    // de altura; antes disso a Column estourava.
    _useSize(tester, const Size(1280, 700));
    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Organizador financeiro'), findsOneWidget);
  });
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Uma meta cadastrada, para a tela de Metas renderizar um card de verdade em
/// vez do estado vazio.
FakeGoalsRepository _goalsWithOne() {
  final repository = FakeGoalsRepository();
  repository.create(
    title: 'Reserva de emergência',
    targetAmount: 12000,
    savedAmount: 8160,
    deadline: DateTime(2026, 12, 1),
  );
  return repository;
}

Future<void> _openPage(
  WidgetTester tester,
  int index, {
  required bool isCompact,
}) async {
  final label = appNavItems[index].label;

  if (!isCompact || mobileNavPages.contains(index)) {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
    return;
  }

  await tester.tap(find.text('Mais'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
