import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:turanta_xpert/app/theme.dart';
import 'package:turanta_xpert/core/i18n/app_locale.dart';
import 'package:turanta_xpert/core/i18n/locale_provider.dart';
import 'package:turanta_xpert/core/i18n/localization_service.dart';
import 'package:turanta_xpert/core/models/partner_user.dart';
import 'package:turanta_xpert/features/auth/data/partner_auth_api.dart';
import 'package:turanta_xpert/features/auth/presentation/pending_approval_screen.dart';
import 'package:turanta_xpert/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:turanta_xpert/features/kyc/presentation/widgets/kyc_chrome.dart';
import 'package:turanta_xpert/features/kyc/presentation/widgets/kyc_inputs.dart';

/// Captures what the wizard would send.
class FakeApi extends PartnerAuthApi {
  FakeApi() : super(Dio());

  Map<String, dynamic>? sent;
  var uploads = 0;

  @override
  Future<PartnerKyc> upsertKyc(Map<String, dynamic> body) async {
    sent = body;
    return const PartnerKyc(userId: 'u1');
  }

  @override
  Future<({String key, String? previewUrl})> uploadKycImage(String path) async {
    uploads += 1;
    return (key: 'kyc/doc-$uploads', previewUrl: null);
  }
}

/// Stands in for the camera so the document steps can be walked in a test.
class _FakePicker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile('/tmp/doc.jpg');
}

class _FakeLocale extends LocaleController {
  @override
  AppLocale build() => AppLocale.en;
}

late FakeApi api;

Future<void> _pump(
  WidgetTester tester, {
  Widget screen = const KycWizardScreen(),
  AppLocale locale = AppLocale.en,
  Size size = const Size(390, 1000),
}) async {
  api = FakeApi();
  ImagePickerPlatform.instance = _FakePicker();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final translations = await tester.runAsync(
    () => LocalizationService.load(locale),
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: '/pending-approval',
        builder: (_, _) => const Scaffold(body: Text('pending')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        translationsProvider.overrideWith((_) async => translations!),
        localeProvider.overrideWith(_FakeLocale.new),
        partnerAuthApiProvider.overrideWith((_) => api),
      ],
      child: MaterialApp.router(routerConfig: router, theme: XpertTheme.light),
    ),
  );
  await tester.pumpAndSettle();
}

/// The TextField under a given AuthTextField label (labels are uppercased).
Finder _field(String label) => find.descendant(
  of: find
      .ancestor(of: find.text(label.toUpperCase()), matching: find.byType(Column))
      .first,
  matching: find.byType(TextField),
);

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> _upload(WidgetTester tester, String docLabel) async {
  await tester.tap(find.text(docLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gallery'));
  await tester.pumpAndSettle();
}

/// Fills every step with valid input and lands on Review.
Future<void> _fillToReview(WidgetTester tester) async {
  await tester.enterText(_field('Full name'), 'Tanay Deo');
  await tester.tap(find.text('Select date of birth'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await _continue(tester);

  await _upload(tester, 'Aadhaar front');
  await _upload(tester, 'Aadhaar back');
  await tester.enterText(_field('Aadhaar number'), '123456789012');
  await _continue(tester);

  await _upload(tester, 'PAN front');
  await _upload(tester, 'PAN back');
  await tester.enterText(_field('PAN number'), 'ABCDE1234F');
  await _continue(tester);

  await _upload(tester, 'Clear selfie');
  await _continue(tester);

  await tester.enterText(_field('Account number'), '12345678901');
  await tester.enterText(_field('Re-enter account number'), '12345678901');
  await tester.enterText(_field('IFSC'), 'HDFC0001234');
  await tester.enterText(_field('Bank name'), 'HDFC Bank');
  await tester.enterText(_field('Account holder name'), 'Tanay Deo');
}

void main() {
  group('KycInputs', () {
    test('PAN must be the real shape, not just ten characters', () {
      // The wizard used to accept any 10 characters.
      expect(KycInputs.panPattern.hasMatch('ABCDE1234F'), isTrue);
      expect(KycInputs.panPattern.hasMatch('1234567890'), isFalse);
      expect(KycInputs.panPattern.hasMatch('ABCDE12345'), isFalse);
    });

    test('IFSC must have the mandatory zero in position five', () {
      expect(KycInputs.ifscPattern.hasMatch('HDFC0001234'), isTrue);
      expect(KycInputs.ifscPattern.hasMatch('HDFC1001234'), isFalse);
      expect(KycInputs.ifscPattern.hasMatch('HDFC000123'), isFalse);
    });

    test('GST is 15 characters in the GSTIN shape', () {
      expect(KycInputs.gstPattern.hasMatch('27AAPFU0939F1ZV'), isTrue);
      expect(KycInputs.gstPattern.hasMatch('27AAPFU0939F1Z'), isFalse);
      expect(KycInputs.gstPattern.hasMatch('AAAAAAAAAAAAAAA'), isFalse);
    });

    test('Aadhaar grouping is display only', () {
      expect(KycInputs.bare('1234 5678 9012'), '123456789012');
    });
  });

  group('wizard', () {
    testWidgets('says how far there is to go', (tester) async {
      await _pump(tester);

      // Progress used to be one unlabelled bar with no step count anywhere.
      expect(find.text('Step 1 of 6'), findsOneWidget);
      expect(find.byType(KycStepper), findsOneWidget);
    });

    testWidgets('explains why each step is asking', (tester) async {
      await _pump(tester);

      expect(
        find.textContaining('exactly as it appears on your Aadhaar'),
        findsOneWidget,
      );
    });

    testWidgets('will not move on without a name', (tester) async {
      await _pump(tester);
      await _continue(tester);

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Step 1 of 6'), findsOneWidget);
    });

    testWidgets('leaving verification asks first', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // It was one unguarded tap that threw away a half-finished wizard.
      expect(find.text('Leave verification?'), findsOneWidget);
    });

    testWidgets('a document tile shows it has been filled', (tester) async {
      await _pump(tester);
      await tester.enterText(_field('Full name'), 'Tanay Deo');
      await tester.tap(find.text('Select date of birth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await _continue(tester);

      expect(find.text('Uploaded — tap to retake'), findsNothing);
      await _upload(tester, 'Aadhaar front');
      expect(find.text('Uploaded — tap to retake'), findsOneWidget);
    });

    testWidgets('rejects a PAN of the right length but the wrong shape', (
      tester,
    ) async {
      await _pump(tester);
      await _fillToReview(tester);
      await _continue(tester);

      // Jump straight to the PAN step from review and break it.
      await tester.tap(
        find.ancestor(
          of: find.text('PAN number'),
          matching: find.byType(KycReviewRow),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_field('PAN number'), '1234567890');
      await _continue(tester);

      expect(find.text('Enter a valid 10-character PAN'), findsOneWidget);
    });

    testWidgets('sends GST — the field the API always accepted', (
      tester,
    ) async {
      await _pump(tester);
      await _fillToReview(tester);
      await tester.enterText(_field('GST number (optional)'), '27AAPFU0939F1ZV');
      await _continue(tester);
      await tester.tap(find.text('Submit KYC'));
      await tester.pumpAndSettle();

      // It was declared on the DTO, stored on the entity, displayed on
      // Financial details — and never once sent by this app.
      expect(api.sent, isNotNull);
      expect(api.sent!['gstNumber'], '27AAPFU0939F1ZV');
    });

    testWidgets('sends every other field the DTO accepts', (tester) async {
      await _pump(tester);
      await _fillToReview(tester);
      await tester.enterText(_field('UAN (optional)'), '100234567890');
      await _continue(tester);
      await tester.tap(find.text('Submit KYC'));
      await tester.pumpAndSettle();

      final sent = api.sent!;
      expect(sent['fullName'], 'Tanay Deo');
      expect(sent['aadhaarNumber'], '123456789012'); // grouping stripped
      expect(sent['panNumber'], 'ABCDE1234F');
      expect(sent['bankAccountNumber'], '12345678901');
      expect(sent['bankIfsc'], 'HDFC0001234');
      expect(sent['uanNumber'], '100234567890');
      expect(sent['submit'], isTrue);
      for (final key in [
        'aadhaarFrontUrl',
        'aadhaarBackUrl',
        'panFrontUrl',
        'panBackUrl',
        'selfieUrl',
      ]) {
        expect(sent[key], isNotNull, reason: '$key should be uploaded');
      }
    });

    testWidgets('an omitted optional field is not sent as an empty string', (
      tester,
    ) async {
      await _pump(tester);
      await _fillToReview(tester);
      await _continue(tester);
      await tester.tap(find.text('Submit KYC'));
      await tester.pumpAndSettle();

      expect(api.sent!.containsKey('gstNumber'), isFalse);
      expect(api.sent!.containsKey('uanNumber'), isFalse);
    });

    testWidgets('review jumps back to the step that owns a line', (
      tester,
    ) async {
      await _pump(tester);
      await _fillToReview(tester);
      await _continue(tester);

      expect(find.text('Step 6 of 6'), findsOneWidget);
      await tester.tap(find.byType(KycReviewRow).first);
      await tester.pumpAndSettle();

      // Review was a wall of text with no way back short of stepping
      // backwards through the whole wizard.
      expect(find.text('Step 1 of 6'), findsOneWidget);
    });

    testWidgets('survives a small screen in Hindi', (tester) async {
      await _pump(tester, locale: AppLocale.hi, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });
  });

  group('pending approval', () {
    testWidgets('shows what has happened and what is left', (tester) async {
      await _pump(tester, screen: const PendingApprovalScreen());

      expect(find.text('Documents submitted'), findsOneWidget);
      expect(find.text('Under review'), findsOneWidget);
      expect(find.text('Ready to work'), findsOneWidget);
      // Nobody should sit here refreshing.
      expect(find.textContaining('send you a notification'), findsOneWidget);
    });

    testWidgets('sign out asks first', (tester) async {
      await _pump(tester, screen: const PendingApprovalScreen());

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget);
    });
  });
}
