import 'package:flutter_test/flutter_test.dart';
import 'package:turanta_xpert/app/router.dart';

PartnerGates gates({
  bool language = false,
  bool legal = false,
  bool kyc = false,
  bool pending = false,
  bool canUseHome = true,
}) => PartnerGates(
  needsLanguage: language,
  needsLegalAcceptance: legal,
  needsKyc: kyc,
  isPendingApproval: pending,
  canUseHome: canUseHome,
);

void main() {
  test('an approved partner owing a consent is held on the consent screen', () {
    // The live loop: home sent them to the consent screen, and the consent
    // screen sent them back, until the router threw a redirect loop and the
    // app showed "page not found".
    final owing = gates(legal: true);
    expect(partnerRedirect(owing, '/home'), '/legal-consent');
    expect(partnerRedirect(owing, '/legal-consent'), isNull);
  });

  test('gates are answered in order', () {
    expect(partnerDestination(gates(language: true, legal: true)), '/language');
    expect(partnerDestination(gates(legal: true, kyc: true)), '/legal-consent');
    expect(partnerDestination(gates(kyc: true)), '/kyc');
    expect(partnerDestination(gates(pending: true)), '/pending-approval');
    expect(partnerDestination(gates(canUseHome: false)), '/pending-approval');
    expect(partnerDestination(gates()), '/home');
  });

  test('a partner with nothing owed is let off the gate screens', () {
    for (final loc in [
      '/language',
      '/legal-consent',
      '/kyc',
      '/pending-approval',
    ]) {
      expect(partnerRedirect(gates(), loc), '/home');
    }
  });

  test('a partner with nothing owed is left wherever they are', () {
    for (final loc in ['/home', '/leave', '/jobs', '/profile/edit']) {
      expect(partnerRedirect(gates(), loc), isNull);
    }
  });

  test('a partner still owing one gate is pulled off the others', () {
    expect(partnerRedirect(gates(kyc: true), '/pending-approval'), '/kyc');
    expect(partnerRedirect(gates(kyc: true), '/leave'), '/kyc');
  });
}
