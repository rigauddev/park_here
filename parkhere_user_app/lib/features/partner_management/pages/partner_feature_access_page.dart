import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/api_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/partner_profile_model.dart';
import '../providers/partner_profile_provider.dart';
import '../../payments/pages/payment_page.dart';

class PartnerFeatureAccessPage extends ConsumerStatefulWidget {
  final PartnerProfileModel partner;
  final String featureKey;
  final int requestedQuantity;

  const PartnerFeatureAccessPage({
    super.key,
    required this.partner,
    required this.featureKey,
    this.requestedQuantity = 1,
  });

  @override
  ConsumerState<PartnerFeatureAccessPage> createState() =>
      _PartnerFeatureAccessPageState();
}

class _PartnerFeatureAccessPageState
    extends ConsumerState<PartnerFeatureAccessPage> {
  final _api = ApiService();
  late int _quantity;
  bool _submitting = false;
  bool _hasPendingRequest = false;
  bool _paymentCompleted = false;
  String? _requestId;
  String? _message;
  String _billingPeriod = 'monthly';
  String _paymentMethod = 'pix';
  double? _requestTotal;
  PlatformFile? _receipt;

  @override
  void initState() {
    super.initState();
    _quantity = widget.requestedQuantity.clamp(1, 100);
    final configured = widget.partner.featureDetails(widget.featureKey) ?? {};
    final configuredPeriod = configured['billing_period'] as String?;
    _billingPeriod = configuredPeriod == 'annual' ? 'annual' : 'monthly';
    _loadRequestStatus();
  }

  Future<void> _loadRequestStatus() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      final requests = await _api.getAuthorized(
        '/partners/feature-requests',
        token,
      );
      final request = requests
          .cast<Map<String, dynamic>>()
          .where(
            (row) =>
                row['feature_key'] == widget.featureKey &&
                (row['status'] == 'pending_review' ||
                    row['status'] == 'pending_payment'),
          )
          .firstOrNull;
      if (mounted) {
        setState(() {
          _requestId = request?['id'] as String?;
          _hasPendingRequest = request?['status'] == 'pending_review';
          _paymentCompleted =
              request?['status'] == 'payment_received' ||
              request?['status'] == 'pending_review';
          if (request != null) {
            _billingPeriod =
                request['billing_period'] as String? ?? _billingPeriod;
            _paymentMethod =
                request['payment_method'] as String? ?? _paymentMethod;
            _requestTotal = (request['total_price'] as num?)?.toDouble();
          }
        });
      }
    } catch (_) {
      // The access summary remains usable if request history cannot be fetched.
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = context.strings.isEnglish;
    final feature = widget.partner.featureDetails(widget.featureKey) ?? {};
    final paid = feature['is_paid'] == true;
    final prices = (feature['billing_prices'] as Map<String, dynamic>?) ?? {};
    final legacyPrice = (feature['price'] as num?)?.toDouble() ?? 0;
    final price =
        (prices[_billingPeriod] as num?)?.toDouble() ??
        ((feature['billing_period'] == _billingPeriod) ? legacyPrice : 0);
    final quantityBased = feature['quantity_based'] == true;
    final requestable = feature['requestable'] == true;
    final canRequest = widget.partner.role != 'operator';
    final resourceRequestsEnabled =
        !quantityBased || feature['is_enabled'] == true;
    final period = switch (_billingPeriod) {
      'annual' => en ? 'year' : 'ano',
      _ => en ? 'month' : 'mês',
    };
    final rawTerms = (feature['payment_terms'] as Map<String, dynamic>?) ?? {};
    final terms =
        (rawTerms[_billingPeriod] as Map<String, dynamic>?) ??
        <String, dynamic>{
          'minimum_months': _billingPeriod == 'monthly' ? 6 : 12,
          'installments': 1,
          'discounts': <String, dynamic>{},
        };
    final minMonths =
        (terms['minimum_months'] as num?)?.toInt() ??
        (_billingPeriod == 'monthly' ? 6 : 12);
    final installments = (terms['installments'] as num?)?.toInt() ?? 1;
    final discount =
        ((terms['discounts'] as Map<String, dynamic>?)?[_paymentMethod] as num?)
            ?.toDouble() ??
        0;
    final name = en
        ? (feature['name_en'] as String? ?? widget.featureKey)
        : (feature['name'] as String? ?? widget.featureKey);
    final description = en
        ? (feature['description_en'] as String? ?? '')
        : (feature['description'] as String? ?? '');
    return Scaffold(
      appBar: AppBar(
        title: Text(en ? 'Feature access' : 'Acesso à funcionalidade'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, size: 36),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(description),
                      const SizedBox(height: 16),
                      ..._benefits(en, widget.featureKey).map(
                        (benefit) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(benefit)),
                            ],
                          ),
                        ),
                      ),
                      if (quantityBased) ...[
                        const SizedBox(height: 18),
                        Text(
                          en ? 'Additional quantity' : 'Quantidade adicional',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$_quantity',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              onPressed: _quantity < 100
                                  ? () => setState(() => _quantity++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (widget.featureKey == 'additional_units')
                        Text(
                          en
                              ? 'Monthly recurring charge'
                              : 'Cobrança mensal recorrente',
                          style: Theme.of(context).textTheme.titleSmall,
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _billingPeriod,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: en
                                ? 'Billing option'
                                : 'Modalidade de cobrança',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text(
                                en ? 'Monthly recurring' : 'Mensal recorrente',
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'annual',
                              child: Text(en ? 'Annual' : 'Anual'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _billingPeriod = value ?? 'monthly',
                          ),
                        ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'pix', label: Text('Pix')),
                          ButtonSegment(
                            value: 'credit_card',
                            label: Text(en ? 'Credit' : 'Crédito'),
                          ),
                          ButtonSegment(
                            value: 'debit_card',
                            label: Text(en ? 'Debit' : 'Débito'),
                          ),
                        ],
                        selected: {_paymentMethod},
                        onSelectionChanged: (value) =>
                            setState(() => _paymentMethod = value.first),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _submitting || !_paymentCompleted
                            ? null
                            : _chooseReceipt,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          _receipt?.name ??
                              (en
                                  ? 'Attach payment proof (PDF/JPG/PNG)'
                                  : 'Anexar comprovante (PDF/JPG/PNG)'),
                        ),
                      ),
                      const Divider(height: 28),
                      Text(
                        paid
                            ? 'R\$ ${(_requestTotal ?? _requestAmount()).toStringAsFixed(2)} / $period'
                            : (en
                                  ? 'Access currently locked'
                                  : 'Acesso bloqueado no momento'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (paid) ...[
                        const SizedBox(height: 6),
                        Text(
                          en
                              ? 'Minimum commitment: $minMonths months · up to $installments installment(s) · ${discount.toStringAsFixed(0)}% discount for this method.'
                              : 'Contratação mínima: $minMonths meses · até $installments parcela(s) · desconto de ${discount.toStringAsFixed(0)}% neste meio.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (widget.featureKey == 'additional_services') ...[
                        const SizedBox(height: 8),
                        Text(
                          en
                              ? 'One service is included. Each additional slot requires approval.'
                              : 'O primeiro serviço está incluído. Cada vaga adicional depende de aprovação.',
                        ),
                      ],
                      if (widget.featureKey == 'additional_units') ...[
                        const SizedBox(height: 8),
                        Text(
                          en
                              ? 'The first location is included. Each extra location includes two operator seats.'
                              : 'A primeira unidade está incluída. Cada unidade extra inclui duas vagas de operador.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              if (!_paymentCompleted && !_hasPendingRequest)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _pay,
                    icon: const Icon(Icons.lock_open),
                    label: Text(en ? 'Pay and continue' : 'Pagar e continuar'),
                  ),
                ),
              FilledButton.icon(
                onPressed:
                    _submitting ||
                        _hasPendingRequest ||
                        _receipt == null ||
                        !_paymentCompleted ||
                        (_requestId == null &&
                            (!paid ||
                                price <= 0 ||
                                !requestable ||
                                !canRequest ||
                                !resourceRequestsEnabled))
                    ? null
                    : _request,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.outgoing_mail),
                label: Text(
                  _submitting
                      ? (en ? 'Sending request…' : 'Enviando solicitação…')
                      : _hasPendingRequest
                      ? (en ? 'Request under review' : 'Solicitação em análise')
                      : (en
                            ? 'Submit proof for review'
                            : 'Enviar comprovante para análise'),
                ),
              ),
              if (!paid ||
                  price <= 0 ||
                  !resourceRequestsEnabled ||
                  !canRequest)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    en
                        ? (!canRequest
                              ? 'Only the partner manager can request this feature.'
                              : !resourceRequestsEnabled
                              ? 'System management has paused new quantity requests for this feature.'
                              : 'This feature is not configured as a paid add-on with a price yet. Contact system management.')
                        : (!canRequest
                              ? 'Somente o gestor do parceiro pode solicitar esta funcionalidade.'
                              : !resourceRequestsEnabled
                              ? 'A gestão do sistema pausou novas solicitações de quantidade para este recurso.'
                              : 'Esta funcionalidade ainda não está configurada como paga com valor. Procure a gestão do sistema.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                en
                    ? (_paymentCompleted
                          ? 'Payment registered. Attach the proof so ParkHere management can review and activate the feature.'
                          : 'Complete payment before attaching proof.')
                    : (_paymentCompleted
                          ? 'Pagamento registrado. Anexe o comprovante para a gestão ParkHere analisar e liberar a funcionalidade.'
                          : 'Conclua o pagamento antes de anexar o comprovante.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _request() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      var requestId = _requestId;
      if (requestId == null) {
        final response = await _api
            .postAuthorized('/partners/feature-requests', {
              'feature_key': widget.featureKey,
              'quantity': _quantity,
              'billing_period': _billingPeriod,
              'payment_method': _paymentMethod,
            }, token);
        requestId = response['id'] as String;
        if (mounted) {
          setState(() {
            _requestId = requestId;
            _requestTotal = (response['total_price'] as num?)?.toDouble();
          });
        }
      }
      final receipt = _receipt!;
      await _api.uploadAuthorizedFile(
        '/partners/feature-requests/$requestId/receipt',
        token,
        receipt.name,
        receipt.bytes!,
      );
      if (!mounted) return;
      setState(() {
        _hasPendingRequest = true;
        _message = context.strings.isEnglish
            ? 'Request submitted. You can continue using the features already enabled.'
            : 'Solicitação enviada. Você pode continuar usando as funcionalidades já liberadas.';
      });
      ref.invalidate(partnerProfileProvider);
      await ApiFeedback.show(
        context,
        context.strings.isEnglish
            ? 'Request submitted for payment review.'
            : 'Solicitação enviada para análise do comprovante.',
        isError: false,
      );
    } catch (error) {
      if (mounted) {
        final message =
            '${context.strings.isEnglish ? 'Could not submit request' : 'Não foi possível solicitar'}: $error';
        setState(() => _message = message);
        await ApiFeedback.show(context, message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pay() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      var requestId = _requestId;
      if (requestId == null) {
        final response = await _api
            .postAuthorized('/partners/feature-requests', {
              'feature_key': widget.featureKey,
              'quantity': _quantity,
              'billing_period': _billingPeriod,
              'payment_method': _paymentMethod,
            }, token);
        requestId = response['id'] as String;
        if (mounted) {
          setState(() {
            _requestId = requestId;
            _requestTotal = (response['total_price'] as num?)?.toDouble();
          });
        }
      }
      if (!mounted) return;
      final amount = _requestTotal ?? _requestAmount();
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            amount: amount,
            featureRequestId: requestId,
            paymentPurpose: 'feature_purchase',
            payNow: true,
            contractedModules: _contractedModules(context.strings.isEnglish),
            onPaymentSuccess: () async {
              if (!mounted) return;
              setState(() {
                _paymentCompleted = true;
                _message = context.strings.isEnglish
                    ? 'Payment completed. The requested capacity is available.'
                    : 'Pagamento concluído. A capacidade solicitada está disponível.';
              });
              ref.invalidate(partnerProfileProvider);
            },
          ),
        ),
      );
      if (paid == true && mounted) {
        setState(() => _paymentCompleted = true);
        await ApiFeedback.show(
          context,
          context.strings.isEnglish
              ? 'Payment approved. You can continue.'
              : 'Pagamento aprovado. Você pode continuar.',
          isError: false,
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) await ApiFeedback.show(context, '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  double _requestAmount() {
    final feature = widget.partner.featureDetails(widget.featureKey) ?? {};
    final prices = (feature['billing_prices'] as Map<String, dynamic>?) ?? {};
    final legacy = (feature['price'] as num?)?.toDouble() ?? 0;
    final unit = (prices[_billingPeriod] as num?)?.toDouble() ?? legacy;
    final quantity = feature['quantity_based'] == true ? _quantity : 1;
    final months = _billingPeriod == 'monthly' ? 6 : 1;
    return unit * quantity * months;
  }

  List<String> _benefits(bool en, String key) {
    final values = switch (key) {
      'additional_units' =>
        en
            ? [
                'Centralized management for every branch',
                'Separate services and teams by unit',
                'Combined and individual financial reports',
              ]
            : [
                'Gestão centralizada de todas as filiais',
                'Serviços e equipes separados por unidade',
                'Relatórios financeiros consolidados e individuais',
              ],
      'convenience_management' =>
        en
            ? [
                'Point of sale with categories and barcode search',
                'Stock control and shift closing report',
                'Non-fiscal receipt for each sale',
              ]
            : [
                'Ponto de venda com categorias e busca por código de barras',
                'Controle de estoque e fechamento do caixa',
                'Comprovante não fiscal para cada venda',
              ],
      _ =>
        en
            ? [
                'Unlock the complete workflow for your partner',
                'Secure data and role-based access',
                'Support for future improvements',
              ]
            : [
                'Libere o fluxo completo para seu parceiro',
                'Dados seguros e acesso por perfil',
                'Suporte para futuras melhorias',
              ],
    };
    return values;
  }

  List<Map<String, dynamic>> _contractedModules(bool en) => [
    for (final entry in widget.partner.features.entries)
      if (entry.value is Map<String, dynamic>)
        {
          'name': en
              ? ((entry.value as Map<String, dynamic>)['name_en'] as String? ??
                    entry.key)
              : ((entry.value as Map<String, dynamic>)['name'] as String? ??
                    entry.key),
          'is_enabled': entry.key == widget.featureKey
              ? _paymentCompleted
              : (entry.value as Map<String, dynamic>)['is_enabled'] == true,
          'amount': entry.key == widget.featureKey
              ? _requestAmount()
              : (((entry.value as Map<String, dynamic>)['billing_prices']
                                as Map<String, dynamic>?)?['monthly']
                            as num?)
                        ?.toDouble() ??
                    ((entry.value as Map<String, dynamic>)['price'] as num?)
                        ?.toDouble() ??
                    0,
        },
  ];

  Future<void> _chooseReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null || file.size > 30 * 1024 * 1024) {
      setState(
        () => _message = context.strings.isEnglish
            ? 'The file must be available in memory and no larger than 30 MB.'
            : 'O arquivo deve estar disponível para envio e ter no máximo 30 MB.',
      );
      return;
    }
    setState(() {
      _receipt = file;
      _message = null;
    });
  }
}
