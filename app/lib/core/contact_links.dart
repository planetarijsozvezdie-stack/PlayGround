import '../data/models.dart';
import 'email_templates.dart';

Uri institutionEmailUri({
  required Company company,
  required Institution institution,
  EmailTemplate? template,
}) {
  final source = template ?? defaultEmailTemplate(company);
  final subject = fillEmailTemplate(
    source.subject,
    company: company,
    institution: institution,
  );
  final body = fillEmailTemplate(
    source.body,
    company: company,
    institution: institution,
  );
  return Uri(
    scheme: 'mailto',
    path: institution.email,
    queryParameters: {'subject': subject, 'body': body},
  );
}
