import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karavan_app/theme/app_theme.dart';
import 'package:karavan_app/utils/responsive.dart';

/// Pousse [page] par une MaterialPageRoute (transition cadrée du thème) sur un écran de [largeur].
Future<void> _ouvrir(WidgetTester tester, double largeur, Widget page) async {
  tester.view.physicalSize = Size(largeur, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cle = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(navigatorKey: cle, theme: AppTheme.lightTheme, home: const SizedBox()));
  cle.currentState!.push(MaterialPageRoute(builder: (_) => page));
  await tester.pumpAndSettle();
}

class _Sonde extends StatelessWidget {
  const _Sonde();

  @override
  Widget build(BuildContext context) =>
      Text('mq=${MediaQuery.sizeOf(context).width.round()}', key: const Key('sonde'));
}

void main() {
  testWidgets('sur mobile, la page occupe toute la largeur', (tester) async {
    await _ouvrir(tester, 400, const Scaffold(body: _Sonde()));
    expect(tester.getSize(find.byType(Scaffold)).width, 400);
    expect(find.text('mq=400'), findsOneWidget);
  });

  testWidgets('sur grand écran, la page est centrée sur la largeur de contenu', (tester) async {
    await _ouvrir(tester, 1400, const Scaffold(body: _Sonde()));
    final rect = tester.getRect(find.byType(Scaffold));
    expect(rect.width, Responsive.largeurContenu);
    expect(rect.center.dx, 700);
    // Les écrans dimensionnés sur MediaQuery restent dans leur colonne
    expect(find.text('mq=${Responsive.largeurContenu.round()}'), findsOneWidget);
  });

  testWidgets('PleineLargeur lève la limite et rend le MediaQuery de l\'écran', (tester) async {
    await _ouvrir(tester, 1400, const PleineLargeur(child: Scaffold(body: _Sonde())));
    expect(tester.getSize(find.byType(Scaffold)).width, 1400);
    expect(find.text('mq=1400'), findsOneWidget);
  });

  testWidgets('les marges latérales absorbent les touchers', (tester) async {
    var touche = false;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cle = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: cle,
      theme: AppTheme.lightTheme,
      home: GestureDetector(onTap: () => touche = true, child: const SizedBox.expand()),
    ));
    cle.currentState!.push(MaterialPageRoute(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 450));
    expect(touche, isFalse);
  });
}
