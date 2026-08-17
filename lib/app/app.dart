import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class PostmarkApp extends StatelessWidget {
  const PostmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Postmark',
      debugShowCheckedModeBanner: false,
      theme: buildPostmarkTheme(),
      routerConfig: appRouter,
    );
  }
}
