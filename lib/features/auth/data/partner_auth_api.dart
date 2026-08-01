import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/models/partner_user.dart';
import '../../../core/network/dio_client.dart';

class PartnerAuthApi {
  PartnerAuthApi(this._dio);
  final Dio _dio;

  Future<PartnerUser> getMe({String? referralCode}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/user',
        queryParameters: {
          'role': 'partner',
          if (referralCode != null && referralCode.trim().isNotEmpty)
            'referralCode': referralCode.trim(),
        },
      );
      return PartnerUser.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<PartnerUser> updateLanguage(String language) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/user/language',
        data: {'language': language},
      );
      return PartnerUser.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<PartnerUser> updateProfile({
    String? name,
    String? gender,
    String? phone,
    String? photoPath,
  }) async {
    try {
      final form = FormData();
      if (name != null) form.fields.add(MapEntry('name', name));
      if (gender != null) form.fields.add(MapEntry('gender', gender));
      if (phone != null) form.fields.add(MapEntry('phone', phone));
      if (photoPath != null && photoPath.isNotEmpty) {
        form.files.add(
          MapEntry(
            'photo',
            await MultipartFile.fromFile(
              photoPath,
              filename: photoPath.split('/').last,
            ),
          ),
        );
      }
      final res = await _dio.patch<Map<String, dynamic>>(
        '/user',
        data: form,
      );
      return PartnerUser.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<PartnerKyc> getKyc() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/partner/kyc');
      return PartnerKyc.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<PartnerKyc> upsertKyc(Map<String, dynamic> body) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/partner/kyc',
        data: body,
      );
      return PartnerKyc.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Edits bank / PAN / GST / UAN details (allowed even after approval).
  Future<PartnerKyc> updateFinancial(Map<String, dynamic> body) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/partner/kyc/financial',
        data: body,
      );
      return PartnerKyc.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Updates WhatsApp / push notification preferences.
  Future<PartnerUser> updatePreferences({
    bool? whatsappOptIn,
    bool? pushOptIn,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/user/preferences',
        data: {
          if (whatsappOptIn != null) 'whatsappOptIn': whatsappOptIn,
          if (pushOptIn != null) 'pushOptIn': pushOptIn,
        },
      );
      return PartnerUser.fromJson(res.data!);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Uploads a KYC document.
  ///
  /// KYC files are stored privately, so `url` is an opaque storage key — that
  /// is the value to submit with the KYC form. `previewUrl` is a short-lived
  /// signed link usable for showing the file right after upload; it expires
  /// and must never be persisted.
  Future<({String key, String? previewUrl})> uploadKycImage(
    String filePath,
  ) async {
    try {
      final form = FormData.fromMap({
        'objectType': 'kyc_image',
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/common/upload',
        data: form,
      );
      final key = res.data?['url'] as String?;
      if (key == null || key.isEmpty) {
        throw ApiException(message: 'Upload failed: missing file reference');
      }
      return (key: key, previewUrl: res.data?['previewUrl'] as String?);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  ApiException _mapDio(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is Map<String, dynamic>) {
        return ApiException(
          message: message['message']?.toString() ?? 'Request failed',
          code: message['code']?.toString(),
          statusCode: e.response?.statusCode,
          details: message,
        );
      }
      if (message is List && message.isNotEmpty) {
        return ApiException(
          message: message.first.toString(),
          statusCode: e.response?.statusCode,
        );
      }
      if (message is String) {
        return ApiException(
          message: message,
          code: data['code']?.toString(),
          statusCode: e.response?.statusCode,
          details: data,
        );
      }
    }

    // HTML / non-JSON usually means the wrong process is on this port.
    if (data is String && data.contains('<!doctype html')) {
      return ApiException(
        message:
            'API returned HTML instead of JSON. Check that NestJS is on '
            '${e.requestOptions.uri.origin} (not Vite/admin).',
        statusCode: e.response?.statusCode,
      );
    }

    final typeHint = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Request timed out talking to ${e.requestOptions.uri.origin}',
      DioExceptionType.connectionError =>
        'Cannot reach API at ${e.requestOptions.uri.origin}. Is NestJS running?',
      _ => e.message ?? e.error?.toString() ?? 'Network error',
    };

    return ApiException(
      message: typeHint,
      statusCode: e.response?.statusCode,
    );
  }
}

final partnerAuthApiProvider = Provider<PartnerAuthApi>((ref) {
  return PartnerAuthApi(ref.watch(dioProvider));
});
