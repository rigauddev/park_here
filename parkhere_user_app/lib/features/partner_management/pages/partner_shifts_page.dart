import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/managed_parking_model.dart';
import '../models/partner_operator_model.dart';
import '../providers/partner_operators_provider.dart';
import '../providers/partner_parking_provider.dart';

class PartnerShiftsPage extends ConsumerStatefulWidget {
  const PartnerShiftsPage({super.key});
  @override
  ConsumerState<PartnerShiftsPage> createState() => _PartnerShiftsPageState();
}

class _PartnerShiftsPageState extends ConsumerState<PartnerShiftsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() { super.initState(); _future = ref.read(partnerOperatorsProvider.notifier).fetchShifts(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escalas por estacionamento'), actions: [IconButton(onPressed: () => setState(() => _future = ref.read(partnerOperatorsProvider.notifier).fetchShifts()), icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _wizard, icon: const Icon(Icons.add), label: const Text('Nova escala')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      final operators = ref.read(partnerOperatorsProvider).maybeWhen(data: (v) => v, orElse: () => <PartnerOperatorModel>[]);
      final parkings = ref.read(partnerParkingProvider).maybeWhen(data: (v) => v, orElse: () => <ManagedParkingModel>[]);
      if (snapshot.data!.isEmpty) return const Center(child: Text('Nenhuma escala cadastrada.'));
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [for (final shift in snapshot.data!) Card(child: ListTile(leading: const Icon(Icons.schedule), title: Text(operators.where((o) => o.id == shift['operator_id']).firstOrNull?.name ?? 'Operador'), subtitle: Text('${parkings.where((p) => p.id == shift['parking_id']).firstOrNull?.name ?? 'Estacionamento'} • ${_date(shift['starts_at'])} até ${_date(shift['ends_at'])}')))]);
    }),
  );

  String _date(dynamic value) => DateTime.parse(value as String).toLocal().toString().substring(0, 16);

  Future<void> _wizard() async {
    final parkings = ref.read(partnerParkingProvider).maybeWhen(data: (v) => v, orElse: () => <ManagedParkingModel>[]);
    final operators = ref.read(partnerOperatorsProvider).maybeWhen(data: (v) => v, orElse: () => <PartnerOperatorModel>[]);
    if (parkings.isEmpty || operators.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre estacionamentos e operadores antes de criar a escala.'))); return; }
    String parkingId = parkings.first.id!; final selected = <String>{}; var step = 0; var startDate = DateTime.now(); var endDate = DateTime.now(); var opening = const TimeOfDay(hour: 7, minute: 0); var closing = const TimeOfDay(hour: 18, minute: 0);
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Nova escala mensal'),
      content: SizedBox(width: 480, child: Stepper(currentStep: step, onStepCancel: step == 0 ? null : () => setLocal(() => step--), onStepContinue: () async {
        if (step == 0) {
          final assigned = <String>{};
          for (final op in operators) { if ((await ref.read(partnerOperatorsProvider.notifier).fetchOperatorParkings(op.id)).contains(parkingId)) assigned.add(op.id); }
          if (!mounted) return;
          if (assigned.isEmpty) { ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Nenhum operador está associado a este estacionamento. Associe a equipe antes de criar a escala.'))); return; }
          setLocal(() { selected..clear()..addAll(assigned); step = 1; });
        } else if (step < 3) { setLocal(() => step++); } else { Navigator.pop(dialogContext); await _generate(parkingId, selected.toList(), startDate, endDate, opening, closing); }
      }, controlsBuilder: (context, d) => Row(children: [FilledButton(onPressed: d.onStepContinue, child: Text(step == 3 ? 'Gerar escala' : 'Próximo')), if (step > 0) TextButton(onPressed: d.onStepCancel, child: const Text('Voltar'))]), steps: [
        Step(isActive: step >= 0, title: const Text('Estacionamento'), content: DropdownButtonFormField<String>(initialValue: parkingId, items: [for (final p in parkings) DropdownMenuItem(value: p.id, child: Text(p.name))], onChanged: (v) => setLocal(() => parkingId = v!))),
        Step(isActive: step >= 1, title: const Text('Usuários e turno'), content: Column(children: [for (final op in operators) CheckboxListTile(value: selected.contains(op.id), title: Text(op.name), subtitle: Text(op.email), onChanged: (v) => setLocal(() => v == true ? selected.add(op.id) : selected.remove(op.id)))])),
        Step(isActive: step >= 2, title: const Text('Funcionamento'), content: Column(children: [ListTile(title: const Text('Abertura'), subtitle: Text(opening.format(context)), trailing: const Icon(Icons.login), onTap: () async { final v = await showTimePicker(context: context, initialTime: opening); if (v != null) setLocal(() => opening = v); }), ListTile(title: const Text('Fechamento'), subtitle: Text(closing.format(context)), trailing: const Icon(Icons.logout), onTap: () async { final v = await showTimePicker(context: context, initialTime: closing); if (v != null) setLocal(() => closing = v); })])),
        Step(isActive: step >= 3, title: const Text('Período'), content: ListTile(title: const Text('Dias da escala'), subtitle: Text('${startDate.day}/${startDate.month}/${startDate.year} até ${endDate.day}/${endDate.month}/${endDate.year}'), trailing: const Icon(Icons.date_range), onTap: () async { final v = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 366)), initialDateRange: DateTimeRange(start: startDate, end: endDate)); if (v != null) setLocal(() { startDate = v.start; endDate = v.end; }); })),
      ])),
    )));
  }

  Future<void> _generate(String parkingId, List<String> operators, DateTime first, DateTime last, TimeOfDay opening, TimeOfDay closing) async {
    if (operators.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione ao menos um operador.'))); return; } final minute = opening.hour * 60 + opening.minute; final closeMinute = closing.hour * 60 + closing.minute; final duration = (closeMinute > minute ? closeMinute - minute : 480).clamp(60, 480);
    try {
      final suggestion = await ref.read(partnerOperatorsProvider.notifier).suggestShifts(parkingId: parkingId, operatorIds: operators, startsOn: first, endsOn: last, dailyHours: duration / 60);
      final warning = suggestion['coverage_warning'] as String?;
      if (warning != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(warning)));
      for (final item in (suggestion['suggestions'] as List<dynamic>)) { final value = item as Map<String, dynamic>; await ref.read(partnerOperatorsProvider.notifier).createShift(operatorId: value['operator_id'] as String, parkingId: parkingId, startsAt: DateTime.parse(value['starts_at'] as String), endsAt: DateTime.parse(value['ends_at'] as String)); }
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível gerar a escala: $error'))); return; }
    if (mounted) setState(() => _future = ref.read(partnerOperatorsProvider.notifier).fetchShifts());
  }
}
