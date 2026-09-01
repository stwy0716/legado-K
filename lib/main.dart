import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:legado_md3/constant/app_theme.dart';
import 'package:legado_md3/di/book_provider.dart';
import 'package:legado_md3/ui/main/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LegadoApp());
}

class LegadoApp extends StatelessWidget {
  const LegadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppTheme()..load()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => ReadProvider()),
      ],
      child: Consumer<AppTheme>(
        builder: (context, appTheme, _) {
          return MaterialApp(
            title: '阅读 MD3',
            debugShowCheckedModeBanner: false,
            theme: appTheme.lightTheme,
            darkTheme: appTheme.darkTheme,
            themeMode: appTheme.themeMode,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}
