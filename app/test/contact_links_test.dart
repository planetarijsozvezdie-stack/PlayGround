import 'package:flutter_test/flutter_test.dart';
import 'package:planetarium_manager/core/contact_links.dart';
import 'package:planetarium_manager/core/email_templates.dart';
import 'package:planetarium_manager/data/seed.dart';

void main() {
  test('mailto содержит адрес, тему и данные компании', () {
    final bundle = buildSeedBundle(now: DateTime(2026, 10, 21));
    final company = bundle.companies.first;
    final institution = bundle.institutions.firstWhere(
      (item) => item.companyId == company.id,
    );

    final uri = institutionEmailUri(company: company, institution: institution);

    expect(uri.scheme, 'mailto');
    expect(uri.path, institution.email);
    expect(uri.queryParameters['subject'], contains(company.shortName));
    expect(uri.queryParameters['body'], contains(institution.displayName));
    expect(uri.queryParameters['body'], contains(company.signer));
  });

  test('пользовательский шаблон подставляет переменные', () {
    final bundle = buildSeedBundle(now: DateTime(2026, 10, 21));
    final company = bundle.companies.first;
    final institution = bundle.institutions.firstWhere(
      (item) => item.companyId == company.id,
    );

    final uri = institutionEmailUri(
      company: company,
      institution: institution,
      template: const EmailTemplate(
        subject: 'Тема для {{учреждение}}',
        body: '{{обращение}} Пишет {{компания}} из {{город}}.',
      ),
    );

    expect(uri.queryParameters['subject'], contains(institution.displayName));
    expect(
      uri.queryParameters['body'],
      contains('Пишет ${company.shortName} из ${company.city}.'),
    );
    expect(uri.queryParameters['body'], contains(institution.contactPerson));
  });
}
