import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DiaryDetailScreen extends StatelessWidget {
  static String get routeName => '/detail';
  const DiaryDetailScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final id = GoRouterState.of(context).pathParameters['id'] ?? '';
    return Scaffold(
      body: Center(
        child: Text('path $id'),
      ),
    );
  }
}
