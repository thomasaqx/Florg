import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:florg/src/data/api_client.dart';
import 'package:florg/src/data/flora_controller.dart';
import 'package:florg/src/models/flora_models.dart';

import 'support/fakes.dart';
import 'support/pump.dart';

void main() {
  group('FloraController', () {
    test('envia a pergunta e guarda as duas mensagens', () async {
      final repository = FakeFloraRepository(answer: 'Sobram R\$ 7.544,10.');
      final controller = FloraController(repository: repository);

      await controller.send('Quanto posso gastar?');

      expect(controller.messages, hasLength(2));
      expect(controller.messages.first.isFromUser, isTrue);
      expect(controller.messages.first.status, ChatMessageStatus.sent);
      expect(controller.messages.last.content, 'Sobram R\$ 7.544,10.');
      expect(controller.isThinking, isFalse);
    });

    test('ignora mensagem em branco', () async {
      final repository = FakeFloraRepository();
      final controller = FloraController(repository: repository);

      await controller.send('   ');

      expect(controller.messages, isEmpty);
      expect(repository.sentMessages, isEmpty);
    });

    test('manda o histórico sem repetir a pergunta atual', () async {
      final repository = FakeFloraRepository();
      final controller = FloraController(repository: repository);

      await controller.send('Como estão minhas finanças?');
      await controller.send('E quanto posso gastar?');

      // Primeiro envio: nada antes dele. Segundo: a pergunta e a resposta
      // anteriores, e não a pergunta que está sendo feita.
      expect(repository.sentHistories.first, isEmpty);
      expect(repository.sentHistories.last, hasLength(2));
      expect(
        repository.sentHistories.last.map((item) => item.content),
        isNot(contains('E quanto posso gastar?')),
      );
    });

    test('falha marca a mensagem e guarda o erro', () async {
      final repository = FakeFloraRepository(
        failure: ApiException(503, 'FLORA indisponível'),
      );
      final controller = FloraController(repository: repository);

      await controller.send('Quanto posso gastar?');

      expect(controller.messages.single.hasFailed, isTrue);
      expect(controller.errorMessage, 'FLORA indisponível');
      expect(controller.isThinking, isFalse);
    });

    test('reenviar troca a bolha que falhou por uma nova', () async {
      final repository = FakeFloraRepository(
        failure: ApiException(503, 'fora do ar'),
      );
      final controller = FloraController(repository: repository);
      await controller.send('Quanto posso gastar?');

      repository.failure = null;
      await controller.retry(controller.messages.single);

      expect(controller.messages, hasLength(2));
      expect(controller.messages.first.hasFailed, isFalse);
    });

    test('limpar apaga a conversa do usuário anterior', () async {
      final controller = FloraController(repository: FakeFloraRepository());
      await controller.send('Quanto gastei com alimentação?');

      controller.clear();

      expect(controller.messages, isEmpty);
      expect(controller.isEmpty, isTrue);
    });

    test('status indisponível não derruba as sugestões padrão', () async {
      final controller = FloraController(
        repository: _FailingStatusRepository(),
      );

      await controller.loadStatus();

      expect(controller.suggestions, FloraStatus.fallback.suggestions);
      expect(controller.status.isLive, isFalse);
    });
  });

  group('tela da FLORA', () {
    testWidgets('mostra o estado vazio com as sugestões', (tester) async {
      useDesktopSize(tester);
      await pumpApp(tester);
      await openFlora(tester);

      expect(find.text('Pergunte alguma coisa\nsobre o seu dinheiro.'), findsOneWidget);
      expect(find.text('Como estão minhas finanças?'), findsWidgets);
      expect(find.text('Modo local'), findsOneWidget);
    });

    testWidgets('digitar e enviar mostra a pergunta e a resposta', (
      tester,
    ) async {
      useDesktopSize(tester);
      final flora = FakeFloraRepository(
        answer: 'Você gastou R\$ 1.240,00 com Alimentação.',
      );
      await pumpApp(tester, flora: flora);
      await openFlora(tester);

      await tester.enterText(
        find.byKey(const ValueKey('flora-input')),
        'Quanto gastei com alimentação?',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('flora-send')));
      await tester.pumpAndSettle();

      expect(find.text('Quanto gastei com alimentação?'), findsOneWidget);
      expect(
        find.text('Você gastou R\$ 1.240,00 com Alimentação.'),
        findsOneWidget,
      );
      expect(flora.sentMessages, ['Quanto gastei com alimentação?']);
    });

    testWidgets('tocar numa sugestão já envia a pergunta', (tester) async {
      useDesktopSize(tester);
      final flora = FakeFloraRepository();
      await pumpApp(tester, flora: flora);
      await openFlora(tester);

      await tester.tap(find.text('Quanto posso gastar?').first);
      await tester.pumpAndSettle();

      expect(flora.sentMessages, ['Quanto posso gastar?']);
    });

    testWidgets('erro de envio aparece na tela com opção de repetir', (
      tester,
    ) async {
      useDesktopSize(tester);
      final flora = FakeFloraRepository(
        failure: ApiException(503, 'FLORA fora do ar'),
      );
      await pumpApp(tester, flora: flora);
      await openFlora(tester);

      await tester.enterText(
        find.byKey(const ValueKey('flora-input')),
        'E aí?',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('flora-send')));
      await tester.pumpAndSettle();

      expect(find.text('FLORA fora do ar'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('o botão de enviar fica inerte sem texto', (tester) async {
      useDesktopSize(tester);
      final flora = FakeFloraRepository();
      await pumpApp(tester, flora: flora);
      await openFlora(tester);

      await tester.tap(find.byKey(const ValueKey('flora-send')));
      await tester.pumpAndSettle();

      expect(flora.sentMessages, isEmpty);
    });

    testWidgets('a FLORA abre pela barra inferior no celular', (tester) async {
      useMobileSize(tester);
      await pumpApp(tester);

      await tester.tap(find.text('FLORA AI').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('flora-input')), findsOneWidget);
    });
  });
}

/// Repositório cujo /ai/status falha, para o teste do fallback.
class _FailingStatusRepository extends FakeFloraRepository {
  @override
  Future<FloraStatus> status() async => throw ApiException(500, 'sem status');
}
