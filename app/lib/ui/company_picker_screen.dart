import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/company_time.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../theme.dart';

class CompanyPickerScreen extends ConsumerWidget {
  const CompanyPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _StarField()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [
                                CosmicColors.accent,
                                CosmicColors.accent2,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.public,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Планетарий Менеджер',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Выберите\nпланетарий',
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Данные компаний хранятся раздельно. '
                      'Переключиться можно в любой момент в профиле.',
                      style: TextStyle(
                        color: CosmicColors.muted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final company in session.companies) ...[
                      _CompanyCard(
                        company: company,
                        onSelect: () => ref
                            .read(sessionProvider.notifier)
                            .selectCompany(company),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 15,
                          color: CosmicColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Данные хранятся локально на устройстве. '
                            'Версия 1.0 · октябрь 2026',
                            style: TextStyle(
                              color: CosmicColors.muted.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.company, required this.onSelect});

  final Company company;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = _parseHex(company.accentHex);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: CosmicColors.surface,
        child: InkWell(
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: CosmicColors.line),
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent.withValues(alpha: 0.14), CosmicColors.surface],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.55)],
                        ),
                      ),
                      child: Icon(
                        company.id == 'c-lunny'
                            ? Icons.nightlight_round
                            : Icons.auto_awesome,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${company.city} · ${company.region}',
                            style: const TextStyle(
                              color: CosmicColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _MetaChip(
                            icon: Icons.schedule,
                            label: companyOffsetLabel(
                              company.timezone,
                              DateTime.now(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onSelect,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Выбрать'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CosmicColors.background2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CosmicColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CosmicColors.muted),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: CosmicColors.text2),
          ),
        ],
      ),
    );
  }
}

Color _parseHex(String hex) {
  final value = hex.replaceFirst('#', '');
  return Color(int.parse('FF$value', radix: 16));
}

class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.6, -0.7),
          radius: 1.4,
          colors: [Color(0xFF191F45), CosmicColors.background],
        ),
      ),
      child: CustomPaint(painter: _StarPainter()),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const points = [
      (0.08, 0.12, 1.4),
      (0.22, 0.34, 1.0),
      (0.15, 0.72, 1.6),
      (0.36, 0.08, 1.1),
      (0.48, 0.26, 0.9),
      (0.62, 0.14, 1.5),
      (0.74, 0.44, 1.0),
      (0.86, 0.22, 1.3),
      (0.92, 0.66, 1.7),
      (0.56, 0.78, 1.1),
      (0.32, 0.9, 1.2),
      (0.78, 0.86, 0.9),
      (0.68, 0.6, 0.8),
      (0.12, 0.48, 0.8),
    ];
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (final point in points) {
      final dx = size.width * point.$1;
      final dy = size.height * point.$2;
      canvas.drawCircle(Offset(dx, dy), point.$3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
