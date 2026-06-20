import '../config/supabase_service.dart';
import '../models/db_models.dart';

class AlertsService {
  final _client = SupabaseService.client;

  Future<String?> _myCompanyId() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    final data = await _client
        .from('users')
        .select('company_id')
        .eq('id', user.id)
        .maybeSingle();
    return data?['company_id'] as String?;
  }

  Future<List<DbAlert>> getAlerts() async {
    final companyId = await _myCompanyId();
    if (companyId == null) return [];
    final data = await _client
        .from('alerts')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((e) => DbAlert.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final companyId = await _myCompanyId();
    if (companyId == null) return 0;
    final data = await _client
        .from('alerts')
        .select()
        .eq('company_id', companyId)
        .eq('is_read', false);
    return (data as List).length;
  }

  Future<void> markRead(String alertId) async {
    await _client
        .from('alerts')
        .update({'is_read': true})
        .eq('id', alertId);
  }

  Future<void> markAllRead() async {
    final companyId = await _myCompanyId();
    if (companyId == null) return;
    await _client
        .from('alerts')
        .update({'is_read': true})
        .eq('company_id', companyId)
        .eq('is_read', false);
  }

  /// Real-time stream of new alerts for the current company
  Stream<List<DbAlert>> alertsStream() async* {
    final companyId = await _myCompanyId();
    if (companyId == null) return;

    yield await getAlerts();

    yield* _client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('company_id', companyId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => DbAlert.fromJson(e)).toList());
  }
}
