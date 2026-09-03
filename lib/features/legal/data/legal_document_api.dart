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

/// One document the partner must read and accept, with whether the version
/// they signed is still the current one.
class RequiredLegalDocument {
  const RequiredLegalDocument({
    required this.id,
    required this.name,
    required this.pdfUrl,
    required this.version,
    required this.accepted,
  });

  factory RequiredLegalDocument.fromJson(Map<String, dynamic> json) {
    return RequiredLegalDocument(
      id: json['id'] as int,
      name: json['name'] as String,
      pdfUrl: json['pdfUrl'] as String,
      version: json['version'] as String? ?? '',
      accepted: json['accepted'] as bool? ?? false,
    );
  }

  final int id;
  final String name;
  final String pdfUrl;
  final String version;
  final bool accepted;
}

class LegalAcceptanceStatus {
  const LegalAcceptanceStatus({
    required this.documents,
    required this.allAccepted,
  });

  factory LegalAcceptanceStatus.fromJson(Map<String, dynamic> json) {
    final raw = (json['documents'] as List<dynamic>? ?? const []);
    return LegalAcceptanceStatus(
      documents: raw
          .cast<Map<String, dynamic>>()
          .map(RequiredLegalDocument.fromJson)
          .toList(),
      allAccepted: json['allAccepted'] as bool? ?? false,
    );
  }

  final List<RequiredLegalDocument> documents;
  final bool allAccepted;
}

class LegalDocumentApi {
  LegalDocumentApi(this._dio);
  final Dio _dio;

  /// The documents this app shows in Settings.
  ///
  /// `app` is sent explicitly: the server used to work out which documents to
  /// return from the caller's account *role*, which has no answer for admin,
  /// supervisor or warehouse-admin — so signing in with any of those returned
  /// an empty list and the Legal section simply vanished.
  Future<List<LegalDocumentSummary>> mine() async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/legal-documents/mine',
        queryParameters: const {'app': 'XPERT'},
      );
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

  /// Documents the partner must accept before onboarding continues.
  Future<LegalAcceptanceStatus> requiredDocuments() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/partner/legal/documents');
      return LegalAcceptanceStatus.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException(
        message: e.message ?? 'Failed to load documents',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Records acceptance. Device details are added server-side from the headers
  /// [DeviceHeadersInterceptor] already attaches.
  Future<LegalAcceptanceStatus> accept(List<int> documentIds) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/partner/legal/accept',
        data: {'documentIds': documentIds},
      );
      return LegalAcceptanceStatus.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException(
        message: e.response?.data is Map
            ? (e.response!.data['message']?.toString() ??
                e.message ??
                'Failed to record acceptance')
            : e.message ?? 'Failed to record acceptance',
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

final requiredLegalDocumentsProvider =
    FutureProvider.autoDispose<LegalAcceptanceStatus>((ref) {
  return ref.watch(legalDocumentApiProvider).requiredDocuments();
});
