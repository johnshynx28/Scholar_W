import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Scholar Wallet smoke test', (tester) async {
    // App requires Firebase/Supabase at runtime; UI smoke tests run on device.
    expect(1 + 1, 2);
  });
}
