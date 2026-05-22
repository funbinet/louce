// This is a basic Flutter widget test for LouceApp.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:louce/main.dart';
import 'package:louce/src/rust/frb_generated.dart';

class MockRustLibApi implements RustLibApi {
  @override
  Future<String> crateApiCdnDetect({required String targetUrl}) async => 'mock';

  @override
  Future<String> crateApiCloudProvider({required String target}) async => 'mock';

  @override
  Future<String> crateApiCtLogs({required String domain}) async => 'mock';

  @override
  Future<String> crateApiDnsBruteforce({
    required String domain,
    String? wordlistPath,
    required BigInt concurrency,
  }) async => 'mock';

  @override
  Future<String> crateApiFirebaseCheck({required String projectId}) async => 'mock';

  @override
  Future<String> crateApiMetadataProbe({required String targetIp}) async => 'mock';

  @override
  Future<String> crateApiReverseDns({required String cidr}) async => 'mock';

  @override
  Future<String> crateApiNetworkServicesAudit() async => 'mock';

  @override
  Future<String> crateApiRunStubAction({required String actionId}) async => 'mock';

  @override
  Future<String> crateApiS3Check({required String bucketName}) async => 'mock';

  @override
  Future<String> crateApiWildcardDetect({required String domain}) async => 'mock';

  @override
  Future<String> crateApiZoneTransfer({
    required String domain,
    String? nameserver,
  }) async => 'mock';
}

void main() {
  testWidgets('Smoke test for LouceApp welcome screen', (WidgetTester tester) async {
    // Initialize RustLib in mock mode for testing
    RustLib.initMock(api: MockRustLibApi());

    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: LouceApp()));

    // Verify that LOUCE logo/welcome text is present (navbar + welcome screen = 2)
    expect(find.text('LOUCE'), findsNWidgets(2));
    expect(find.text('Autonomous Bug Bounty Framework'), findsOneWidget);
  });
}
