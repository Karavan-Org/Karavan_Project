import 'package:dogo_app/widgets/didacticiel_guide_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deux espaces peuvent coexister un instant (transition, route empilée) : chacun a ses propres clés
/// de didacticiel, donc aucune « Duplicate GlobalKeys ».
void main() {
  Widget espace(CiblesDidacticiel cibles) => PorteeCiblesDidacticiel(
        cibles: cibles,
        child: Builder(
          builder: (context) => SizedBox(key: CiblesDidacticiel.de(context)!.grossisteKpi, height: 10),
        ),
      );

  testWidgets('deux espaces simultanés ne partagent pas leurs clés', (tester) async {
    final premier = CiblesDidacticiel();
    final second = CiblesDidacticiel();
    await tester.pumpWidget(MaterialApp(home: Column(children: [espace(premier), espace(second)])));

    expect(tester.takeException(), isNull);
    expect(premier.grossisteKpi.currentContext, isNotNull);
    expect(second.grossisteKpi.currentContext, isNotNull);
  });

  testWidgets('hors d\'un espace, aucune cible (le didacticiel garde sa position par défaut)', (tester) async {
    CiblesDidacticiel? lue;
    await tester.pumpWidget(Builder(builder: (context) {
      lue = CiblesDidacticiel.de(context);
      return const SizedBox();
    }));
    expect(lue, isNull);
  });
}
