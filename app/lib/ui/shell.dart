import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/company_time.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'backup_dialog.dart';
import 'dialogs.dart';
import 'documents_screen.dart';
import 'home_screen.dart';
import 'notifications_dialog.dart';
import 'profile_dialog.dart';
import 'institutions_screen.dart';
import 'revenue_screen.dart';
import 'schedule_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.company});

  final Company company;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 640;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -0.8),
          radius: 1.3,
          colors: [Color(0xFF141A3C), CosmicColors.background],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(wide ? 24 : 0),
            child: Scaffold(
              floatingActionButton: _buildFab(context),
              appBar: AppBar(
                titleSpacing: 16,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.company.shortName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.company.city} · '
                      '${companyOffsetLabel(widget.company.timezone, DateTime.now())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: CosmicColors.muted,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Настройки расчётов',
                    onPressed: () => showSettingsDialog(context, ref),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.account_circle_outlined),
                    onSelected: (value) async {
                      if (value == 'profile' && context.mounted) {
                        await showProfileDialog(context, ref);
                      } else if (value == 'backup' && context.mounted) {
                        await showBackupDialog(context, ref);
                      } else if (value == 'notifications' && context.mounted) {
                        await showNotificationsDialog(context, ref);
                      } else if (value == 'switch') {
                        await ref.read(sessionProvider.notifier).clearCompany();
                      } else if (value == 'about' && context.mounted) {
                        showAboutDialog(
                          context: context,
                          applicationName: 'Планетарий Менеджер',
                          applicationVersion: '1.0.0',
                          applicationLegalese: 'ИП Марина Р. Р. · Планетарии «Лунный Дом» и «Созвездие»',
                          children: const [
                            SizedBox(height: 12),
                            Text(
                              'Данные хранятся локально на устройстве. '
                              'Google-интеграции и ИИ-помощник — в следующих версиях.',
                            ),
                          ],
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'profile',
                        child: Text('Профиль и безопасность'),
                      ),
                      PopupMenuItem(
                        value: 'backup',
                        child: Text('Резервная копия'),
                      ),
                      PopupMenuItem(
                        value: 'notifications',
                        child: Text('Напоминания'),
                      ),
                      PopupMenuItem(
                        value: 'switch',
                        child: Text('Сменить планетарий'),
                      ),
                      PopupMenuItem(
                        value: 'about',
                        child: Text('О приложении'),
                      ),
                    ],
                  ),
                ],
              ),
              body: IndexedStack(
                index: _index,
                children: [
                  HomeScreen(
                    company: widget.company,
                    onNavigate: (index) => setState(() => _index = index),
                  ),
                  ScheduleScreen(company: widget.company),
                  InstitutionsScreen(company: widget.company),
                  DocumentsScreen(company: widget.company),
                  RevenueScreen(company: widget.company),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (index) =>
                    setState(() => _index = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Главная',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Расписание',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book),
                    label: 'База',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.description_outlined),
                    selectedIcon: Icon(Icons.description),
                    label: 'Документы',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.payments_outlined),
                    selectedIcon: Icon(Icons.payments),
                    label: 'Выручка',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildFab(BuildContext context) {
    return switch (_index) {
      1 => FloatingActionButton.extended(
        onPressed: () => showAddEventDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Мероприятие'),
      ),
      2 => FloatingActionButton.extended(
        onPressed: () => showAddInstitutionDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Учреждение'),
      ),
      4 => FloatingActionButton.extended(
        onPressed: () => showAddRevenueDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Выручка'),
      ),
      _ => null,
    };
  }
}
