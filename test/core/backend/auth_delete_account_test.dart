import 'package:flutter_test/flutter_test.dart';
import 'package:v_shots/core/backend/auth_service.dart';
import 'package:v_shots/core/backend/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleteAccount fails closed when Supabase is unavailable', () async {
    expect(SupabaseService.isAvailable, isFalse);
    final result = await AuthService.instance.deleteAccount();
    expect(result.isSuccess, isFalse);
    expect(result.error, isNotNull);
    expect(result.error!.toLowerCase(), contains('unavailable'));
  });
}
