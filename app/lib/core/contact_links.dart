import '../data/models.dart';

Uri institutionEmailUri({
  required Company company,
  required Institution institution,
}) {
  final subject = 'Планетарий «${company.shortName}» — сотрудничество';
  final greeting = institution.contactPerson.isEmpty
      ? 'Здравствуйте!'
      : 'Здравствуйте, ${institution.contactPerson}!';
  final body =
      '$greeting\n\n'
      'Пишем из планетария «${company.shortName}» (${company.city}). '
      'Хотим обсудить проведение программы для '
      '${institution.displayName}.\n\n'
      'С уважением,\n'
      '${company.signer}\n'
      '${company.phone}';
  return Uri(
    scheme: 'mailto',
    path: institution.email,
    queryParameters: {'subject': subject, 'body': body},
  );
}
