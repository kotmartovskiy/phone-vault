import 'package:flutter_test/flutter_test.dart';
import 'package:phone_vault_client/main.dart';

void main() {
  testWidgets('Phone Vault home renders safety notice', (tester) async {
    await tester.pumpWidget(const PhoneVaultApp());
    expect(find.textContaining('Safety:'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Pair'), findsOneWidget);
  });
}
