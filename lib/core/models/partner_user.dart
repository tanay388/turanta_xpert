import 'partner_shift.dart';

enum UserRole {
  user,
  partner,
  supervisor,
  warehouseAdmin,
  admin,
}

enum UserStatus {
  active,
  pendingApproval,
  suspended,
  rejected,
  deactivated,
}

enum PartnerKycStatus {
  draft,
  submitted,
  approved,
  rejected,
}

UserRole userRoleFromApi(String? value) {
  switch (value) {
    case 'partner':
      return UserRole.partner;
    case 'supervisor':
      return UserRole.supervisor;
    case 'warehouse_admin':
      return UserRole.warehouseAdmin;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.user;
  }
}

UserStatus userStatusFromApi(String? value) {
  switch (value) {
    case 'pending_approval':
      return UserStatus.pendingApproval;
    case 'suspended':
      return UserStatus.suspended;
    case 'rejected':
      return UserStatus.rejected;
    case 'deactivated':
      return UserStatus.deactivated;
    default:
      return UserStatus.active;
  }
}

PartnerKycStatus? kycStatusFromApi(String? value) {
  switch (value) {
    case 'draft':
      return PartnerKycStatus.draft;
    case 'submitted':
      return PartnerKycStatus.submitted;
    case 'approved':
      return PartnerKycStatus.approved;
    case 'rejected':
      return PartnerKycStatus.rejected;
    default:
      return null;
  }
}

class PartnerUser {
  const PartnerUser({
    required this.id,
    required this.role,
    required this.status,
    this.name,
    this.phone,
    this.email,
    this.photo,
    this.gender,
    this.language,
    this.shiftId,
    this.shiftCode,
    this.shift,
    this.warehouseId,
    this.kycStatus,
    this.kycComplete = false,
    this.whatsappOptIn = true,
    this.pushOptIn = true,
  });

  final String id;
  final UserRole role;
  final UserStatus status;
  final String? name;
  final String? phone;
  final String? email;
  final String? photo;
  final String? gender;
  final String? language;
  final int? shiftId;
  final String? shiftCode;
  final PartnerShift? shift;
  final int? warehouseId;
  final PartnerKycStatus? kycStatus;
  final bool kycComplete;
  final bool whatsappOptIn;
  final bool pushOptIn;

  factory PartnerUser.fromJson(Map<String, dynamic> json) {
    final shiftJson = json['shift'];
    return PartnerUser(
      id: json['id'] as String,
      role: userRoleFromApi(json['role'] as String?),
      status: userStatusFromApi(json['status'] as String?),
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      photo: json['photo'] as String?,
      gender: json['gender'] as String?,
      language: json['language'] as String?,
      shiftId: (json['shiftId'] as num?)?.toInt(),
      shiftCode: json['shiftCode'] as String?,
      shift: shiftJson is Map<String, dynamic>
          ? PartnerShift.fromJson(shiftJson)
          : null,
      warehouseId: (json['warehouseId'] as num?)?.toInt(),
      kycStatus: kycStatusFromApi(json['kycStatus'] as String?),
      kycComplete: json['kycComplete'] as bool? ?? false,
      whatsappOptIn: json['whatsappOptIn'] as bool? ?? true,
      pushOptIn: json['pushOptIn'] as bool? ?? true,
    );
  }

  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Partner';
  }

  bool get needsLanguage => language == null || language!.trim().isEmpty;
  bool get needsKyc => !kycComplete;
  bool get isPendingApproval => status == UserStatus.pendingApproval;
  bool get isActive => status == UserStatus.active;
}

class PartnerKyc {
  const PartnerKyc({
    required this.userId,
    this.fullName,
    this.dateOfBirth,
    this.aadhaarFrontUrl,
    this.aadhaarBackUrl,
    this.panFrontUrl,
    this.panBackUrl,
    this.selfieUrl,
    this.bankAccountNumberMasked,
    this.bankIfsc,
    this.bankName,
    this.accountHolderName,
    this.panNumberMasked,
    this.aadhaarNumberMasked,
    this.gstNumber,
    this.uanNumber,
    this.status,
    this.rejectionReason,
    this.complete = false,
  });

  final String userId;
  final String? fullName;
  final String? dateOfBirth;
  final String? aadhaarFrontUrl;
  final String? aadhaarBackUrl;
  final String? panFrontUrl;
  final String? panBackUrl;
  final String? selfieUrl;
  final String? bankAccountNumberMasked;
  final String? bankIfsc;
  final String? bankName;
  final String? accountHolderName;
  final String? panNumberMasked;
  final String? aadhaarNumberMasked;
  final String? gstNumber;
  final String? uanNumber;
  final PartnerKycStatus? status;
  final String? rejectionReason;
  final bool complete;

  factory PartnerKyc.fromJson(Map<String, dynamic> json) {
    return PartnerKyc(
      userId: json['userId'] as String? ?? '',
      fullName: json['fullName'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      aadhaarFrontUrl: json['aadhaarFrontUrl'] as String?,
      aadhaarBackUrl: json['aadhaarBackUrl'] as String?,
      panFrontUrl: json['panFrontUrl'] as String?,
      panBackUrl: json['panBackUrl'] as String?,
      selfieUrl: json['selfieUrl'] as String?,
      bankAccountNumberMasked: json['bankAccountNumberMasked'] as String?,
      bankIfsc: json['bankIfsc'] as String?,
      bankName: json['bankName'] as String?,
      accountHolderName: json['accountHolderName'] as String?,
      panNumberMasked: json['panNumberMasked'] as String?,
      aadhaarNumberMasked: json['aadhaarNumberMasked'] as String?,
      gstNumber: json['gstNumber'] as String?,
      uanNumber: json['uanNumber'] as String?,
      status: kycStatusFromApi(json['status'] as String?),
      rejectionReason: json['rejectionReason'] as String?,
      complete: json['complete'] as bool? ?? false,
    );
  }
}

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? details;

  @override
  String toString() => message;
}
