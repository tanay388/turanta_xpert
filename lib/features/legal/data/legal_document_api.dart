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
}

final legalDocumentApiProvider = Provider<LegalDocumentApi>((ref) {
  return LegalDocumentApi(ref.watch(dioProvider));
});

final legalDocumentsProvider = FutureProvider.autoDispose<List<LegalDocumentSummary>>((ref) {
  return ref.watch(legalDocumentApiProvider).mine();
});
