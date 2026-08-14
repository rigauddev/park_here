class PartnerPaymentAccountSummary {
  final String provider;
  final String status;
  final String accountLabel;

  const PartnerPaymentAccountSummary({
    required this.provider,
    required this.status,
    required this.accountLabel,
  });

  factory PartnerPaymentAccountSummary.fromJson(Map<String, dynamic> json) {
    return PartnerPaymentAccountSummary(
      provider: json['provider'] as String? ?? 'mercado_pago',
      status: json['status'] as String? ?? 'pending_verification',
      accountLabel: json['account_label'] as String? ?? 'Conta do parceiro',
    );
  }
}

class PartnerProfileModel {
  final String tenantId;
  final String role;
  final String userEmail;
  final String? serviceType;
  final String? companyName;
  final String approvalStatus;
  final PartnerPaymentAccountSummary? paymentAccount;

  const PartnerProfileModel({
    required this.tenantId,
    required this.role,
    required this.userEmail,
    required this.serviceType,
    required this.companyName,
    required this.approvalStatus,
    required this.paymentAccount,
  });

  factory PartnerProfileModel.fromJson(Map<String, dynamic> json) {
    final paymentJson = json['payment_account'];

    return PartnerProfileModel(
      tenantId: json['tenant_id'] as String? ?? '',
      role: json['role'] as String? ?? '',
      userEmail: json['user_email'] as String? ?? '',
      serviceType: json['service_type'] as String?,
      companyName: json['company_name'] as String?,
      approvalStatus: json['approval_status'] as String? ?? 'missing_profile',
      paymentAccount: paymentJson is Map<String, dynamic>
          ? PartnerPaymentAccountSummary.fromJson(paymentJson)
          : null,
    );
  }

  String get serviceTypeLabel {
    switch (serviceType) {
      case 'parking':
        return 'Estacionamento';
      case 'car_wash':
        return 'Lava jato';
      case 'tour_guide':
        return 'Guia turistico';
      case 'tourism_company':
        return 'Empresa de turismo';
      case 'hotel':
        return 'Hotel';
      case 'restaurant':
        return 'Restaurante';
      case 'transport':
        return 'Transporte';
      default:
        return 'Tipo de servico pendente';
    }
  }

  String get approvalStatusLabel {
    switch (approvalStatus) {
      case 'approved':
        return 'Aprovado';
      case 'waiting_documents':
        return 'Aguardando documentos';
      case 'waiting_inspection':
        return 'Aguardando vistoria';
      case 'rejected':
        return 'Reprovado';
      case 'suspended':
        return 'Suspenso';
      case 'missing_profile':
        return 'Perfil pendente';
      default:
        return approvalStatus;
    }
  }
}
