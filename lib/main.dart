import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:vrouter/vrouter.dart';

import 'service/app_services.dart';
import 'service/profile/profile_manager.dart';
import 'ui/brightness_theme_data.dart';
import 'ui/router/mixin_routes.dart';
import 'ui/widget/brightness_observer.dart';
import 'util/l10n.dart';
import 'util/logger.dart';

Future<void> main() async {
  await initStorage();
  runZonedGuarded(
    () => runApp(MyApp()),
    (Object error, StackTrace stack) {
      if (!kLogMode) return;
      e('$error, $stack');
    },
    zoneSpecification: ZoneSpecification(
      handleUncaughtError: (_, __, ___, Object error, StackTrace stack) {
        if (!kLogMode) return;
        wtf('$error, $stack');
      },
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        if (!kLogMode) return;
        parent.print(zone, colorizeNonAnsi(line));
      },
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  final vRouterStateKey = GlobalKey<VRouterState>();

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (BuildContext context) => AppServices(
              vRouterStateKey: vRouterStateKey,
            ),
          ),
        ],
        child: _Router(vRouterStateKey: vRouterStateKey),
      );
}

class _Router extends StatelessWidget {
  const _Router({
    required this.vRouterStateKey,
    Key? key,
  }) : super(key: key);

  final GlobalKey<VRouterState> vRouterStateKey;

  @override
  Widget build(BuildContext context) => VRouter(
        key: vRouterStateKey,
        title: 'Mixin Wallet',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [
          ...L10n.delegate.supportedLocales,
        ],
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: <TargetPlatform, PageTransitionsBuilder>{
              TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
              TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
            },
          ),
        ),
        builder: (BuildContext context, Widget child) => BrightnessObserver(
          lightThemeData: lightBrightnessThemeData,
          child: child,
        ),
        routes: buildMixinRoutes(context),
      );
}

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder() : super();

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      child;
}
