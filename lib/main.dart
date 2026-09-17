import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'providers/expense_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ExpnzApp());
}

class ExpnzApp extends StatefulWidget {
  const ExpnzApp({super.key});

  @override
  State<ExpnzApp> createState() => _ExpnzAppState();
}

class _ExpnzAppState extends State<ExpnzApp> {
  late final ExpenseProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ExpenseProvider();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AnimatedBuilder(
        animation: _provider,
        builder: (context, _) {
          return HomeScreen(provider: _provider);
        },
      ),
    );
  }
}
