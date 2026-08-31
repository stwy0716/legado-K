import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'bookshelf_screen.dart';
import 'discover_screen.dart';
import 'subscribe_screen.dart';
import 'profile_screen.dart';
import 'local_import_screen.dart';
import 'backup_screen.dart';
import 'cache_manage_screen.dart';
import 'bookmark_screen.dart';
import 'replace_rule_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // 默认书架
  final PageController _pageController = PageController(initialPage: 1);

  final List<Widget> _screens = const [
    HomeScreen(),
    BookshelfScreen(),
    DiscoverScreen(),
    SubscribeScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookProvider>(context, listen: false).loadBooks();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/local_import':
        return MaterialPageRoute(builder: (_) => const LocalImportScreen());
      case '/backup':
        return MaterialPageRoute(builder: (_) => const BackupScreen());
      case '/cache':
        return MaterialPageRoute(builder: (_) => const CacheManageScreen());
      case '/bookmark':
        return MaterialPageRoute(builder: (_) => const BookmarkScreen());
      case '/replace':
        return MaterialPageRoute(builder: (_) => const ReplaceRuleScreen());
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => _buildMainScaffold());
        }
        return _onGenerateRoute(settings);
      },
    );
  }

  Widget _buildMainScaffold() {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions),
            label: '订阅',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
