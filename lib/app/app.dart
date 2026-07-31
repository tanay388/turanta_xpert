import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/i18n/locale_provider.dart';
import 'router.dart';
import 'theme.dart';

class TurantaXpertApp extends ConsumerWidget {
  const TurantaXpertApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Rebuild when locale / translation bundles change.
    ref.watch(translationsProvider);

    return MaterialApp.router(
      title: 'Turanta Xpert',
      debugShowCheckedModeBanner: false,
      theme: XpertTheme.light,
      routerConfig: router,
    );
  }
}
