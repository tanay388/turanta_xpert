import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/models/partner_user.dart' show ApiException;
import '../../../core/network/dio_client.dart';

class LegalDocumentSummary {
  const LegalDocumentSummary({
    required this.id,
    required this.name,
    required this.pdfUrl,
  });

  factory LegalDocumentSummary.fromJson(Map<String, dynamic> json) {
    return LegalDocumentSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      pdfUrl: json['pdfUrl'] as String,
    );
  }

  final int id;
  final String name;
  final String pdfUrl;
}

/// The two documents the sign-in consent line points at.
///
/// Either side can be null: an admin may not have tagged one yet, or may have
/// deactivated it. Callers render the sentence without that link rather than a
/// link that opens nothing.
class LegalConsentDocuments {
  const LegalConsentDocuments({this.privacyPolicy, this.terms});

  factory LegalConsentDocuments.fromJson(Map<String, dynamic> json) {
    LegalDocumentSummary? read(String key) {
      final value = json[key];
      if (value is! Map) return null;
      return LegalDocumentSummary.fromJson(Map<String, dynamic>.from(value));
    }

    return LegalConsentDocuments(
      privacyPolicy: read('privacyPolicy'),
      terms: read('terms'),
    );
  }

  final LegalDocumentSummary? privacyPolicy;
  final LegalDocumentSummary? terms;
}

class LegalDocumentApi {
  LegalDocumentApi(this._dio);
  final Dio _dio;

  Future<List<LegalDocumentSummary>> mine() async {
    try {
      final res = await _dio.get<List<dynamic>>('/legal-documents/mine');
      return (res.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(LegalDocumentSummary.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException(
        message: e.message ?? 'Failed to load documents',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Unauthenticated — this is read on the login screen, before a token exists.
  Future<LegalConsentDocuments> consent() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/legal-documents/consent',
        queryParameters: const {'app': 'XPERT'},
      );
      return LegalConsentDocuments.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException(
        message: e.message ?? 'Failed to load documents',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

final legalDocumentApiProvider = Provider<LegalDocumentApi>((ref) {
  return LegalDocumentApi(ref.watch(dioProvider));
});

final legalDocumentsProvider = FutureProvider.autoDispose<List<LegalDocumentSummary>>((ref) {
  return ref.watch(legalDocumentApiProvider).mine();
});

/// Not auto-disposed: the login screen is rebuilt on every keystroke in the
/// phone field, and the consent documents change about once a year.
final legalConsentProvider = FutureProvider<LegalConsentDocuments>((ref) {
  return ref.watch(legalDocumentApiProvider).consent();
});
