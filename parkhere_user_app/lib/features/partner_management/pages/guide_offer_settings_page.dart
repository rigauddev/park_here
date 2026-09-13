import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class GuideOfferSettingsPage extends ConsumerStatefulWidget {
  const GuideOfferSettingsPage({super.key});

  @override
  ConsumerState<GuideOfferSettingsPage> createState() =>
      _GuideOfferSettingsPageState();
}

class _GuideOfferSettingsPageState
    extends ConsumerState<GuideOfferSettingsPage> {
  final _api = ApiService();
  final _periods = const ['daily', 'weekly', 'monthly', 'long_term'];
  final Map<String, TextEditingController> _values = {};
  final Map<String, String> _types = {};
  List<Map<String, dynamic>> _parkings = [];
  String? _parkingId;
  bool _accepts = false;
  bool _loading = true;
  bool _saving = false;

  String _copy(String portuguese, String english) =>
      context.strings.isEnglish ? english : portuguese;

  String _periodLabel(String period) => switch (period) {
    'daily' => _copy('Diária', 'Daily'),
    'weekly' => _copy('Semanal', 'Weekly'),
    'monthly' => _copy('Mensal', 'Monthly'),
    _ => _copy('Hora ou outros planos', 'Hourly or other plans'),
  };

  @override
  void initState() {
    super.initState();
    for (final period in _periods) {
      _values[period] = TextEditingController();
      _types[period] = 'percentage';
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) return;
    try {
      final rows = await _api.getAuthorized(
        '/partners/parking-management',
        token,
      );
      _parkings = rows.cast<Map<String, dynamic>>();
      _parkingId ??= _parkings.isEmpty ? null : _parkings.first['id'] as String;
      if (_parkingId != null) await _loadOffer(_parkingId!, token);
    } catch (error) {
      if (mounted) {
        _message(
          '${_copy('Não foi possível carregar as unidades', 'Could not load locations')}: $error',
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadOffer(String parkingId, String token) async {
    final offer = await _api.getAuthorizedMap(
      '/partners/parking-management/$parkingId/guide-offer',
      token,
    );
    final terms = (offer['offer_terms'] as Map?)?.cast<String, dynamic>() ?? {};
    _accepts = offer['accepts_affiliates'] == true;
    for (final period in _periods) {
      final term = (terms[period] as Map?)?.cast<String, dynamic>() ?? {};
      _types[period] = term['commission_type'] as String? ?? 'percentage';
      _values[period]!.text = term['commission_value']?.toString() ?? '';
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final token = ref.read(authProvider).accessToken;
    final parkingId = _parkingId;
    if (token == null || parkingId == null) return;
    final terms = <String, Map<String, dynamic>>{};
    for (final period in _periods) {
      final raw = _values[period]!.text.trim().replaceAll(',', '.');
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null ||
          value < 0 ||
          (_types[period] == 'percentage' && value > 100)) {
        _message(
          _copy(
            'Revise os valores. Percentuais devem ficar entre 0 e 100.',
            'Check the values. Percentages must be between 0 and 100.',
          ),
        );
        return;
      }
      terms[period] = {
        'commission_type': _types[period],
        'commission_value': value,
      };
    }
    if (_accepts &&
        (_periods.any((period) => !terms.containsKey(period)) ||
            terms.values.any(
              (term) => (term['commission_value'] as double) <= 0,
            ))) {
      _message(
        _copy(
          'Preencha uma comissão positiva para cada modalidade antes de aceitar afiliados.',
          'Set a positive commission for every plan before accepting affiliates.',
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.putAuthorized(
        '/partners/parking-management/$parkingId/guide-offer',
        {'accepts_affiliates': _accepts, 'terms': terms},
        token,
      );
      if (mounted) {
        _message(_copy('Oferta de afiliados salva.', 'Affiliate offer saved.'));
      }
    } catch (error) {
      if (mounted) {
        _message(
          '${_copy('Não foi possível salvar a oferta', 'Could not save the offer')}: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _copy('Afiliação e comissões', 'Affiliations and commissions'),
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _parkings.isEmpty
        ? Center(
            child: Text(
              _copy(
                'Cadastre uma unidade antes de configurar afiliados.',
                'Add a location before configuring affiliates.',
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _parkingId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _copy('Unidade', 'Location'),
                ),
                items: [
                  for (final parking in _parkings)
                    DropdownMenuItem(
                      value: parking['id'] as String,
                      child: Text(
                        parking['name'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    _parkingId = value;
                    _loading = true;
                  });
                  final token = ref.read(authProvider).accessToken;
                  if (token != null) await _loadOffer(value, token);
                  if (mounted) setState(() => _loading = false);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _accepts,
                title: Text(
                  _copy('Aceitar guias afiliados', 'Accept affiliated guides'),
                ),
                subtitle: Text(
                  _copy(
                    'Somente guias aprovados poderão indicar reservas desta unidade.',
                    'Only approved guides can refer reservations to this location.',
                  ),
                ),
                onChanged: (value) => setState(() => _accepts = value),
              ),
              const SizedBox(height: 8),
              Text(
                _copy('Comissão por plano', 'Commission by plan'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _copy(
                  'Informe quanto o guia recebe por uma indicação concluída. Deixe em branco para não oferecer comissão nessa modalidade.',
                  'Set the guide commission for a completed referral. Leave blank to disable that plan.',
                ),
              ),
              for (final period in _periods)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _periodLabel(period),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _types[period],
                                decoration: InputDecoration(
                                  labelText: _copy('Tipo', 'Type'),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'percentage',
                                    child: Text(
                                      _copy('Percentual', 'Percentage'),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fixed',
                                    child: Text(
                                      _copy('Valor fixo (R\$)', 'Fixed amount'),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _types[period] = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _values[period],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: _types[period] == 'percentage'
                                      ? _copy('Comissão (%)', 'Commission (%)')
                                      : _copy(
                                          'Comissão (R\$)',
                                          'Commission amount',
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_copy('Salvar oferta', 'Save offer')),
              ),
            ],
          ),
  );
}
