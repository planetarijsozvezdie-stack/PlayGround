import '../data/models.dart';
import '../data/repository.dart';

const emailPlaceholders = <String, String>{
  '{{обращение}}': 'Здравствуйте, Имя!',
  '{{учреждение}}': 'Название учреждения',
  '{{компания}}': 'Название планетария',
  '{{город}}': 'Город',
  '{{подпись}}': 'Подпись',
  '{{телефон}}': '+7 …',
  '{{email}}': 'email@example.ru',
};

class EmailTemplate {
  const EmailTemplate({required this.subject, required this.body});

  final String subject;
  final String body;
}

String emailTemplateSubjectKey(String companyId) =>
    'email_template_subject_$companyId';

String emailTemplateBodyKey(String companyId) =>
    'email_template_body_$companyId';

EmailTemplate defaultEmailTemplate(Company company) => EmailTemplate(
  subject: 'Планетарий «{{компания}}» — сотрудничество',
  body:
      '{{обращение}}\n\n'
      'Пишем из планетария «{{компания}}» ({{город}}). '
      'Хотим обсудить проведение программы для {{учреждение}}.\n\n'
      'С уважением,\n'
      '{{подпись}}\n'
      '{{телефон}}',
);

Future<EmailTemplate> loadEmailTemplate(
  Repository repository,
  Company company,
) async {
  final defaults = defaultEmailTemplate(company);
  final subject = await repository.setting(
    emailTemplateSubjectKey(company.id),
    '',
  );
  final body = await repository.setting(emailTemplateBodyKey(company.id), '');
  return EmailTemplate(
    subject: subject.isEmpty ? defaults.subject : subject,
    body: body.isEmpty ? defaults.body : body,
  );
}

Future<void> saveEmailTemplate(
  Repository repository,
  Company company,
  EmailTemplate template,
) async {
  await repository.setSetting(
    emailTemplateSubjectKey(company.id),
    template.subject,
  );
  await repository.setSetting(emailTemplateBodyKey(company.id), template.body);
}

String fillEmailTemplate(
  String template, {
  required Company company,
  required Institution institution,
}) {
  final greeting = institution.contactPerson.isEmpty
      ? 'Здравствуйте!'
      : 'Здравствуйте, ${institution.contactPerson}!';
  return template
      .replaceAll('{{обращение}}', greeting)
      .replaceAll('{{учреждение}}', institution.displayName)
      .replaceAll('{{компания}}', company.shortName)
      .replaceAll('{{город}}', company.city)
      .replaceAll('{{подпись}}', company.signer)
      .replaceAll('{{телефон}}', company.phone)
      .replaceAll('{{email}}', company.email);
}
