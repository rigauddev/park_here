import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/managed_parking_model.dart';
import '../models/partner_operator_model.dart';
import '../providers/partner_operators_provider.dart';
import '../providers/partner_parking_provider.dart';

class PartnerShiftsPage extends ConsumerStatefulWidget {
  const PartnerShiftsPage({super.key});
  @override ConsumerState<PartnerShiftsPage> createState() => _PartnerShiftsPageState();
}

class _PartnerShiftsPageState extends ConsumerState<PartnerShiftsPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override void initState() { super.initState(); future = ref.read(partnerOperatorsProvider.notifier).fetchShifts(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escalas por estacionamento'), actions: [IconButton(onPressed: () => setState(() => future = ref.read(partnerOperatorsProvider.notifier).fetchShifts()), icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _create(context), icon: const Icon(Icons.add), label: const Text('Nova escala')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snapshot) {
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      if (snapshot.data!.isEmpty) return const Center(child: Text('Nenhuma escala cadastrada.'));
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [for (final shift in snapshot.data!) Card(child: ListTile(leading: const Icon(Icons.schedule), title: Text('${shift['operator_id']} · ${shift['parking_id']}'), subtitle: Text('${_date(shift['starts_at'])} até ${_date(shift['ends_at'])}')))]);
    }),
  );

  String _date(dynamic value) => DateTime.parse(value as String).toLocal().toString().substring(0, 16);

  Future<void> _create(BuildContext context) async {
    final parkings = ref.read(partnerParkingProvider).maybeWhen(data: (v) => v, orElse: () => <ManagedParkingModel>[]);
    final operators = ref.read(partnerOperatorsProvider).maybeWhen(data: (v) => v, orElse: () => <PartnerOperatorModel>[]);
    if (parkings.isEmpty || operators.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre operadores e estacionamentos antes de criar a escala.'))); return; }
    String parkingId = parkings.first.id!;
    final selected = <String>{operators.first.id};
    DateTime day = DateTime.now();
    TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 18, minute: 0);
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Criar escala'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: parkingId, decoration: const InputDecoration(labelText: 'Estacionamento'), items: [for (final p in parkings) DropdownMenuItem(value: p.id, child: Text(p.name))], onChanged: (v) => setLocal(() => parkingId = v!)),
        const SizedBox(height: 12), const Align(alignment: Alignment.centerLeft, child: Text('Operadores do turno')),
        for (final op in operators) CheckboxListTile(value: selected.contains(op.id), title: Text(op.name), subtitle: Text(op.email), contentPadding: EdgeInsets.zero, onChanged: (v) => setLocal(() => v == true ? selected.add(op.id) : selected.remove(op.id))),
        ListTile(title: const Text('Dia'), subtitle: Text('${day.day}/${day.month}/${day.year}'), trailing: const Icon(Icons.calendar_month), onTap: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setLocal(() => day = d); }),
        ListTile(title: const Text('Horário'), subtitle: Text('${start.format(context)} - ${end.format(context)}'), trailing: const Icon(Icons.access_time), onTap: () async { final s = await showTimePicker(context: context, initialTime: start); if (s == null) return; final e = await showTimePicker(context: context, initialTime: end); if (e != null) setLocal(() { start = s; end = e; }); }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Salvar'))],
    )));
    if (saved != true || selected.isEmpty) return;
    final starts = DateTime(day.year, day.month, day.day, start.hour, start.minute);
    final ends = DateTime(day.year, day.month, day.day, end.hour, end.minute);
    for (final operatorId in selected) {
      await ref.read(partnerOperatorsProvider.notifier).createShift(operatorId: operatorId, parkingId: parkingId, startsAt: starts, endsAt: ends);
    }
    if (mounted) setState(() => future = ref.read(partnerOperatorsProvider.notifier).fetchShifts());
  }
}
