import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../providers/partner_operations_provider.dart';

Future<bool> showCashSessionDialog(
  BuildContext context,
  WidgetRef ref, {
  required List<Map<String, String>> parkingOptions,
  required bool open,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _CashSessionDialog(
      parkingOptions: parkingOptions,
      open: open,
    ),
  );
  return result == true;
}

class _CashSessionDialog extends ConsumerStatefulWidget {
  final List<Map<String, String>> parkingOptions;
  final bool open;
  const _CashSessionDialog({required this.parkingOptions, required this.open});

  @override
  ConsumerState<_CashSessionDialog> createState() => _CashSessionDialogState();
}

class _CashSessionDialogState extends ConsumerState<_CashSessionDialog> {
  final _parking = TextEditingController();
  final _convenience = TextEditingController();
  final _notes = TextEditingController();
  String? _parkingId;
  bool _busy = false;
  String? _error;
  bool _includeConvenience = false;

  @override
  void initState() {
    super.initState();
    _parkingId = widget.parkingOptions.isEmpty
        ? null
        : widget.parkingOptions.first['id'];
  }

  @override
  void dispose() {
    _parking.dispose();
    _convenience.dispose();
    _notes.dispose();
    super.dispose();
  }

  double _money(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  Future<void> _submit() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null) {
      setState(() => _error = 'Sessão expirada. Entre novamente.');
      return;
    }
    if (widget.open && _parkingId == null) {
      setState(() => _error = 'Selecione o estacionamento do turno.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.open) {
        await openPartnerCashSession(
          token: token,
          parkingId: _parkingId!,
          parkingOpeningCash: _money(_parking),
          convenienceOpeningCash: _includeConvenience ? _money(_convenience) : 0,
        );
      } else {
        await closePartnerCashSession(
          token: token,
          parkingClosingCash: _money(_parking),
          convenienceClosingCash: _includeConvenience ? _money(_convenience) : 0,
          closingNotes: _notes.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.open ? 'Abrir turno e caixa' : 'Fechar turno e caixa';
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.open
                    ? 'Informe o fundo de troco inicial para liberar as funções operacionais da unidade.'
                    : 'Informe os valores finais em dinheiro apurados no encerramento deste turno.',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              if (widget.open && widget.parkingOptions.isNotEmpty) ...[
                if (widget.parkingOptions.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: _parkingId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Unidade do turno',
                      prefixIcon: Icon(Icons.local_parking),
                    ),
                    items: [
                      for (final item in widget.parkingOptions)
                        DropdownMenuItem(
                          value: item['id'],
                          child: Text(item['name'] ?? item['id'] ?? ''),
                        ),
                    ],
                    onChanged: (value) => setState(() => _parkingId = value),
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Unidade do turno',
                      prefixIcon: Icon(Icons.local_parking),
                    ),
                    child: Text(
                      widget.parkingOptions.first['name'] ?? 'Estacionamento',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _parking,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: widget.open
                      ? 'Fundo de troco inicial (Estacionamento)'
                      : 'Valor final em dinheiro (Estacionamento)',
                  prefixText: 'R\$ ',
                  hintText: '0,00',
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Caixa separado para conveniência / loja'),
                value: _includeConvenience,
                onChanged: (val) => setState(() => _includeConvenience = val ?? false),
              ),
              if (_includeConvenience) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _convenience,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: widget.open
                        ? 'Fundo de troco inicial (Conveniência)'
                        : 'Valor final em dinheiro (Conveniência)',
                    prefixText: 'R\$ ',
                    hintText: '0,00',
                  ),
                ),
              ],
              if (!widget.open) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observações (opcional)'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (!widget.open)
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.open ? 'Abrir caixas' : 'Fechar turno'),
        ),
      ],
    );
  }
}
