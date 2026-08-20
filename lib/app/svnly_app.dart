import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/localization/app_strings.dart';
import 'router.dart';

class SvnlyApp extends ConsumerWidget {
  const SvnlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SVNLY',
      debugShowCheckedModeBanner: false,
      theme: buildSvnlyTheme(),
      routerConfig: router,
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
