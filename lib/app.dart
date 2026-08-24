import 'package:bid_book/core/routing/app_router.dart';
import 'package:bid_book/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BidBookApp extends StatelessWidget {
  const BidBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bid&Book',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
