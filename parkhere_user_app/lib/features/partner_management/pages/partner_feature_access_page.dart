import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/partner_profile_model.dart';
import '../providers/partner_profile_provider.dart';

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
  String? _message;

  @override
  void initState() {
    super.initState();
    _quantity = widget.requestedQuantity.clamp(1, 100);
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
      final pending = requests.cast<Map<String, dynamic>>().any(
        (row) =>
            row['feature_key'] == widget.featureKey &&
            row['status'] == 'pending_review',
      );
      if (mounted) setState(() => _hasPendingRequest = pending);
    } catch (_) {
      // The access summary remains usable if request history cannot be fetched.
    }
  }

  @override
  Widget build(BuildContext context) {
    final en = context.strings.isEnglish;
    final feature = widget.partner.featureDetails(widget.featureKey) ?? {};
    final paid = feature['is_paid'] == true;
    final price = (feature['price'] as num?)?.toDouble() ?? 0;
    final quantityBased = feature['quantity_based'] == true;
    final requestable = feature['requestable'] == true;
    final canRequest = widget.partner.role != 'operator';
    final resourceRequestsEnabled =
        !quantityBased || feature['is_enabled'] == true;
    final period = switch (feature['billing_period']) {
      'annual' => en ? 'year' : 'ano',
      'one_time' => en ? 'one-time' : 'pagamento único',
      _ => en ? 'month' : 'mês',
    };
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
                      const Divider(height: 28),
                      Text(
                        paid
                            ? 'R\$ ${(price * (quantityBased ? _quantity : 1)).toStringAsFixed(2)} / $period'
                            : (en
                                  ? 'Access currently locked'
                                  : 'Acesso bloqueado no momento'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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
              FilledButton.icon(
                onPressed:
                    _submitting ||
                        _hasPendingRequest ||
                        !paid ||
                        price <= 0 ||
                        !requestable ||
                        !canRequest ||
                        !resourceRequestsEnabled
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
                      : (en ? 'Request activation' : 'Solicitar liberação'),
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
                    ? 'The request is reviewed by ParkHere management. This action does not charge a payment method or activate the feature automatically.'
                    : 'A solicitação será analisada pela gestão do ParkHere. Ela não cobra automaticamente nem libera a funcionalidade sem aprovação.',
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
      await _api.postAuthorized('/partners/feature-requests', {
        'feature_key': widget.featureKey,
        'quantity': _quantity,
      }, token);
      if (!mounted) return;
      setState(() {
        _hasPendingRequest = true;
        _message = context.strings.isEnglish
            ? 'Request submitted. You can continue using the features already enabled.'
            : 'Solicitação enviada. Você pode continuar usando as funcionalidades já liberadas.';
      });
      ref.invalidate(partnerProfileProvider);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              '${context.strings.isEnglish ? 'Could not submit request' : 'Não foi possível solicitar'}: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
