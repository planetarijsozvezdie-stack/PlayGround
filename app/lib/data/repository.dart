import '../core/event_rules.dart';
import 'models.dart';

abstract class Repository {
  Future<List<Company>> companies();

  Future<String?> selectedCompanyId();

  Future<void> selectCompany(String companyId);

  Future<String> setting(String key, String fallback);

  Future<void> setSetting(String key, String value);

  Future<List<Institution>> institutions(
    String companyId, {
    InstitutionType? type,
  });

  Future<void> saveInstitution(Institution value);

  Future<void> deleteInstitution(String id);

  Future<List<ChangeEntry>> institutionHistory(String institutionId);

  Future<List<Event>> events(String companyId, {EventStatus? status});

  Future<void> saveEvent(Event value);

  Future<void> completeEvent(String id);

  Future<void> cancelEvent(String id);

  Future<void> reopenEvent(String id);

  Future<void> deleteEvent(String id);

  Future<void> restoreEvent(String id);

  Future<List<Revenue>> revenues(String companyId);

  Future<void> addRevenue(Revenue value);

  Future<DashboardStats> stats(String companyId);

  Future<List<ProgramRecord>> programs(String companyId);

  Future<List<TemplateRecord>> templates(String companyId);

  Future<void> saveTemplate(TemplateRecord template);

  Future<List<DocumentRecord>> documents(String companyId);

  Future<void> addDocument(DocumentRecord value);

  Future<void> setDocumentSigned(String id, bool signed);

  Future<void> deleteDocument(String id);

  Future<int> pendingOutbox();

  bool get supportsFullBackup;

  Future<Map<String, dynamic>> exportBackup();

  Future<void> restoreBackup(Map<String, dynamic> backup);

  Future<void> dispose();
}
