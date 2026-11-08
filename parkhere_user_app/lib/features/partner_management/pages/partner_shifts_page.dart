import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/widgets/api_feedback.dart';
import '../../auth/providers/auth_provider.dart';
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
  static const _unitPalette = <Color>[
    Color(0xFF087EE1),
    Color(0xFF00897B),
    Color(0xFF8E24AA),
    Color(0xFFEF6C00),
    Color(0xFF3949AB),
    Color(0xFF00838F),
  ];
  late Future<List<Map<String, dynamic>>> _shiftsFuture;
  DateTime _selectedDay = DateTime.now();
  String? _parkingFilter;
  String? _operatorFilter;
  Future<List<PartnerOperatorModel>>? _eligibleOperatorsFuture;
  bool _weekView = false;

  String _text(String pt, String en) => context.strings.isEnglish ? en : pt;

  @override
  void initState() {
    super.initState();
    _shiftsFuture = ref.read(partnerOperatorsProvider.notifier).fetchShifts();
  }

  @override
  Widget build(BuildContext context) {
    final isOperator = ref.watch(authProvider).isOperator;
    final operators = ref
        .watch(partnerOperatorsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => <PartnerOperatorModel>[],
        );
    final parkings = ref
        .watch(partnerParkingProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => <ManagedParkingModel>[],
        );
    final parkingColors = <String, Color>{
      for (var index = 0; index < parkings.length; index++)
        parkings[index].id!: _unitPalette[index % _unitPalette.length],
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isOperator
              ? _text('Minha escala', 'My schedule')
              : _text('Escalas por unidade', 'Schedules by unit'),
        ),
        actions: [
          IconButton(
            tooltip: _text('Exportar escala em PDF', 'Export schedule as PDF'),
            onPressed: () => _exportPdf(parkings, operators),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: _text('Atualizar escala', 'Refresh schedule'),
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: isOperator
          ? null
          : FloatingActionButton.extended(
              onPressed: _wizard,
              icon: const Icon(Icons.add),
              label: Text(_text('Nova escala', 'New schedule')),
            ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _shiftsFuture,
        builder: (context, snapshot) {
          final allShifts = snapshot.data ?? const <Map<String, dynamic>>[];
          final calendarShifts = allShifts
              .where(
                (shift) =>
                    (_parkingFilter == null ||
                        shift['parking_id'] == _parkingFilter) &&
                    (_operatorFilter == null ||
                        shift['operator_id'] == _operatorFilter),
              )
              .toList();
          final dayShifts =
              allShifts.where((shift) {
                final date = DateTime.parse(
                  shift['starts_at'] as String,
                ).toLocal();
                return date.year == _selectedDay.year &&
                    date.month == _selectedDay.month &&
                    date.day == _selectedDay.day &&
                    (_parkingFilter == null ||
                        shift['parking_id'] == _parkingFilter) &&
                    (_operatorFilter == null ||
                        shift['operator_id'] == _operatorFilter);
              }).toList()..sort(
                (a, b) => (a['starts_at'] as String).compareTo(
                  b['starts_at'] as String,
                ),
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            children: [
              _ScheduleCalendar(
                selectedDay: _selectedDay,
                shifts: calendarShifts,
                parkingColors: parkingColors,
                weekView: _weekView,
                onWeekViewChanged: (value) => setState(() => _weekView = value),
                onDaySelected: (value) => setState(() => _selectedDay = value),
                onPageChanged: (value) => setState(() => _selectedDay = value),
              ),
              if (!isOperator && parkings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final parking in parkings)
                        Chip(
                          avatar: CircleAvatar(
                            backgroundColor: parkingColors[parking.id],
                            radius: 7,
                          ),
                          label: Text(
                            parking.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              if (!isOperator)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final parking = _parkingDropdown(parkings);
                    final operator = _operatorDropdown(operators);
                    if (constraints.maxWidth < 580) {
                      return Column(children: [parking, operator]);
                    }
                    return Row(
                      children: [
                        Expanded(child: parking),
                        const SizedBox(width: 12),
                        Expanded(child: operator),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_text('Turnos de', 'Shifts for')} ${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!isOperator)
                    TextButton.icon(
                      onPressed: () => _addShift(parkings, operators),
                      icon: const Icon(Icons.add),
                      label: Text(_text('Adicionar turno', 'Add shift')),
                    ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(
                      _text(
                        'Não foi possível carregar a escala.',
                        'Could not load the schedule.',
                      ),
                    ),
                    subtitle: Text('${snapshot.error}'),
                    trailing: IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                )
              else if (dayShifts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      _text(
                        'Nenhum turno cadastrado neste dia. A data continua visível no calendário; adicione um turno se houver cobertura necessária.',
                        'No shifts are scheduled for this day. The date remains visible; add a shift if coverage is needed.',
                      ),
                    ),
                  ),
                )
              else
                for (final shift in dayShifts)
                  _shiftCard(
                    shift,
                    operators,
                    parkings,
                    parkingColors,
                    isOperator,
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _parkingDropdown(List<ManagedParkingModel> parkings) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DropdownButtonFormField<String?>(
      initialValue: _parkingFilter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: _text('Unidade', 'Unit'),
        border: OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(_text('Todas as unidades', 'All units')),
        ),
        ...parkings.map(
          (parking) => DropdownMenuItem<String?>(
            value: parking.id,
            child: Text(parking.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (value) => setState(() {
        _parkingFilter = value;
        _operatorFilter = null;
        _eligibleOperatorsFuture = value == null
            ? null
            : _operatorsForParking(
                value,
                ref.read(partnerOperatorsProvider).value ?? const [],
              );
      }),
    ),
  );

  Widget _operatorDropdown(List<PartnerOperatorModel> operators) {
    if (_parkingFilter == null) return _operatorDropdownField(operators);
    _eligibleOperatorsFuture ??= _operatorsForParking(
      _parkingFilter!,
      operators,
    );
    return FutureBuilder<List<PartnerOperatorModel>>(
      future: _eligibleOperatorsFuture,
      builder: (context, snapshot) => _operatorDropdownField(
        snapshot.data ?? const [],
        loading: snapshot.connectionState == ConnectionState.waiting,
      ),
    );
  }

  Widget _operatorDropdownField(
    List<PartnerOperatorModel> operators, {
    bool loading = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DropdownButtonFormField<String?>(
      initialValue: _operatorFilter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: loading
            ? _text(
                'Carregando operadores habilitados…',
                'Loading enabled operators…',
              )
            : _text('Operador', 'Operator'),
        border: OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(_text('Todos os operadores', 'All operators')),
        ),
        ...operators.map(
          (operator) => DropdownMenuItem<String?>(
            value: operator.id,
            child: Text(operator.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: loading
          ? null
          : (value) => setState(() => _operatorFilter = value),
    ),
  );

  Widget _shiftCard(
    Map<String, dynamic> shift,
    List<PartnerOperatorModel> operators,
    List<ManagedParkingModel> parkings,
    Map<String, Color> parkingColors,
    bool isOperator,
  ) {
    final operator = operators
        .where((item) => item.id == shift['operator_id'])
        .firstOrNull;
    final parking = parkings
        .where((item) => item.id == shift['parking_id'])
        .firstOrNull;
    final startsAt = DateTime.parse(shift['starts_at'] as String).toLocal();
    final endsAt = DateTime.parse(shift['ends_at'] as String).toLocal();
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: parkingColors[shift['parking_id']]?.withValues(
            alpha: .14,
          ),
          child: Icon(
            operator == null ? Icons.person_add_alt : Icons.person_outline,
            color: parkingColors[shift['parking_id']],
          ),
        ),
        title: Text(operator?.name ?? 'Turno sem operador'),
        subtitle: Text(
          '${parking?.name ?? 'Unidade'} · ${_time(startsAt)}–${_time(endsAt)}',
        ),
        trailing: isOperator
            ? null
            : Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: 'Atribuir ou trocar operador e horário',
                    icon: const Icon(Icons.edit_calendar_outlined),
                    onPressed: () => _editShift(shift, operators),
                  ),
                  IconButton(
                    tooltip: 'Cancelar escala',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _cancelShift(shift),
                  ),
                ],
              ),
      ),
    );
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  void _reload() => setState(() {
    _shiftsFuture = ref.read(partnerOperatorsProvider.notifier).fetchShifts();
  });

  Future<void> _exportPdf(
    List<ManagedParkingModel> parkings,
    List<PartnerOperatorModel> operators,
  ) async {
    String parkingId = '';
    String operatorId = '';
    final selection = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(_text('Exportar escala', 'Export schedule')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: parkingId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _text('Unidade', 'Unit'),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(_text('Todas as unidades', 'All units')),
                  ),
                  for (final parking in parkings)
                    DropdownMenuItem(
                      value: parking.id!,
                      child: Text(
                        parking.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setLocal(() => parkingId = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: operatorId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _text('Operador', 'Operator'),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(_text('Todos os operadores', 'All operators')),
                  ),
                  for (final operator in operators)
                    DropdownMenuItem(
                      value: operator.id,
                      child: Text(
                        operator.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setLocal(() => operatorId = value ?? ''),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_text('Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_text('Gerar PDF', 'Generate PDF')),
            ),
          ],
        ),
      ),
    );
    if (selection != true) return;

    try {
      final shifts = await _shiftsFuture;
      final selected =
          shifts
              .where(
                (shift) =>
                    (parkingId.isEmpty || shift['parking_id'] == parkingId) &&
                    (operatorId.isEmpty || shift['operator_id'] == operatorId),
              )
              .toList()
            ..sort(
              (a, b) => (a['starts_at'] as String).compareTo(
                b['starts_at'] as String,
              ),
            );
      final pdf = pw.Document();
      final parkingGroups = <String, List<Map<String, dynamic>>>{};
      for (final shift in selected) {
        (parkingGroups[shift['parking_id'] as String] ??= []).add(shift);
      }
      final blocks = <pw.Widget>[
        pw.Text(
          'ParkHere · Escala de trabalho',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Gerado em ${_dateLabel(DateTime.now())}'),
        pw.SizedBox(height: 12),
        pw.Text(
          'Legenda: turno com nome = operador atribuído; “Turno sem operador” = cobertura pendente.',
        ),
        pw.SizedBox(height: 16),
      ];
      for (final entry in parkingGroups.entries) {
        final parking = parkings
            .where((item) => item.id == entry.key)
            .firstOrNull;
        blocks.add(
          pw.Header(level: 1, child: pw.Text(parking?.name ?? 'Unidade')),
        );
        blocks.add(
          pw.TableHelper.fromTextArray(
            headers: const ['Data', 'Início', 'Fim', 'Operador'],
            data: [
              for (final shift in entry.value)
                [
                  _dateLabel(
                    DateTime.parse(shift['starts_at'] as String).toLocal(),
                  ),
                  _time(DateTime.parse(shift['starts_at'] as String).toLocal()),
                  _time(DateTime.parse(shift['ends_at'] as String).toLocal()),
                  operators
                          .where((item) => item.id == shift['operator_id'])
                          .firstOrNull
                          ?.name ??
                      'Turno sem operador',
                ],
            ],
          ),
        );
        blocks.add(pw.SizedBox(height: 18));
      }
      if (selected.isEmpty) {
        blocks.add(
          pw.Text('Nenhum turno encontrado para os filtros selecionados.'),
        );
      }
      pdf.addPage(pw.MultiPage(build: (_) => blocks));
      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(context, 'Não foi possível gerar o PDF: $error');
      }
    }
  }

  Future<List<PartnerOperatorModel>> _operatorsForParking(
    String parkingId,
    List<PartnerOperatorModel> operators,
  ) async {
    final eligible = <PartnerOperatorModel>[];
    for (final operator in operators.where((item) => item.isActive)) {
      final parkingIds = await ref
          .read(partnerOperatorsProvider.notifier)
          .fetchOperatorParkings(operator.id);
      if (parkingIds.contains(parkingId)) eligible.add(operator);
    }
    return eligible;
  }

  Future<void> _editShift(
    Map<String, dynamic> shift,
    List<PartnerOperatorModel> operators,
  ) async {
    final parkingId = shift['parking_id'] as String;
    List<PartnerOperatorModel> eligible;
    try {
      eligible = await _operatorsForParking(parkingId, operators);
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível consultar os operadores: $error',
        );
      }
      return;
    }
    if (!mounted) return;
    var operatorId = shift['operator_id'] as String?;
    var startsAt = DateTime.parse(shift['starts_at'] as String).toLocal();
    var endsAt = DateTime.parse(shift['ends_at'] as String).toLocal();
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Editar turno'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: operatorId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Operador'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Turno sem operador'),
                    ),
                    if (operatorId != null &&
                        !eligible.any((item) => item.id == operatorId))
                      DropdownMenuItem<String?>(
                        value: operatorId,
                        child: const Text(
                          'Operador atual sem autorização ativa',
                        ),
                      ),
                    ...eligible.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setLocal(() => operatorId = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Início'),
                  subtitle: Text(
                    '${_dateLabel(startsAt)} · ${_time(startsAt)}',
                  ),
                  trailing: const Icon(Icons.schedule),
                  onTap: saving
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: startsAt,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startsAt),
                          );
                          if (time != null) {
                            setLocal(
                              () => startsAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          }
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fim'),
                  subtitle: Text('${_dateLabel(endsAt)} · ${_time(endsAt)}'),
                  trailing: const Icon(Icons.schedule),
                  onTap: saving
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: endsAt,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                          );
                          if (date == null || !context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endsAt),
                          );
                          if (time != null) {
                            setLocal(
                              () => endsAt = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setLocal(() => saving = true);
                      try {
                        await ref
                            .read(partnerOperatorsProvider.notifier)
                            .updateShift(
                              shiftId: shift['id'] as String,
                              operatorId: operatorId,
                              startsAt: startsAt,
                              endsAt: endsAt,
                            );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          _reload();
                          await ApiFeedback.show(
                            this.context,
                            'Turno atualizado.',
                            isError: false,
                          );
                        }
                      } catch (error) {
                        setLocal(() => saving = false);
                        if (dialogContext.mounted) {
                          await ApiFeedback.show(
                            dialogContext,
                            'Não foi possível atualizar: $error',
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addShift(
    List<ManagedParkingModel> parkings,
    List<PartnerOperatorModel> operators,
  ) async {
    if (parkings.isEmpty) return;
    var parkingId = _parkingFilter ?? parkings.first.id!;
    var operatorId = <String, String?>{parkingId: null};
    var startsAt = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      8,
    );
    var endsAt = startsAt.add(const Duration(hours: 8));
    String? coverageHint;
    try {
      final shifts = await _shiftsFuture;
      final dayShifts = shifts.where((shift) {
        if (shift['parking_id'] != parkingId) return false;
        final start = DateTime.parse(shift['starts_at'] as String).toLocal();
        return start.year == startsAt.year &&
            start.month == startsAt.month &&
            start.day == startsAt.day;
      }).toList();
      if (dayShifts.isNotEmpty) {
        dayShifts.sort(
          (a, b) => (a['ends_at'] as String).compareTo(b['ends_at'] as String),
        );
        final lastEnd = DateTime.parse(
          dayShifts.last['ends_at'] as String,
        ).toLocal();
        if (lastEnd.isAfter(startsAt)) {
          startsAt = lastEnd;
          endsAt = startsAt.add(const Duration(hours: 8));
          coverageHint =
              'Já existe turno nesta unidade. Sugestão: iniciar às ${_time(startsAt)} para cobrir a sequência; também é possível manter operadores no mesmo turno.';
        }
      }
    } catch (_) {}
    List<PartnerOperatorModel> eligible = [];
    try {
      eligible = await _operatorsForParking(parkingId, operators);
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Adicionar turno'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: parkingId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: parkings
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id!,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    setLocal(() => parkingId = value);
                    final values = await _operatorsForParking(value, operators);
                    if (dialogContext.mounted) {
                      setLocal(() {
                        eligible = values;
                        operatorId[value] = null;
                      });
                    }
                  },
                ),
                if (coverageHint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        coverageHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                DropdownButtonFormField<String?>(
                  key: ValueKey('shift-operator-$parkingId'),
                  initialValue: operatorId[parkingId],
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Operador'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Deixar turno aberto'),
                    ),
                    ...eligible.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setLocal(() => operatorId[parkingId] = value),
                ),
                ListTile(
                  title: const Text('Início'),
                  subtitle: Text(
                    '${_dateLabel(startsAt)} · ${_time(startsAt)}',
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(startsAt),
                    );
                    if (time != null) {
                      setLocal(
                        () => startsAt = DateTime(
                          _selectedDay.year,
                          _selectedDay.month,
                          _selectedDay.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  title: const Text('Fim'),
                  subtitle: Text('${_dateLabel(endsAt)} · ${_time(endsAt)}'),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(endsAt),
                    );
                    if (time != null) {
                      setLocal(
                        () => endsAt = DateTime(
                          _selectedDay.year,
                          _selectedDay.month,
                          _selectedDay.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(partnerOperatorsProvider.notifier)
                      .createShift(
                        operatorId: operatorId[parkingId],
                        parkingId: parkingId,
                        startsAt: startsAt,
                        endsAt: endsAt,
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _reload();
                } catch (error) {
                  if (dialogContext.mounted) {
                    await ApiFeedback.show(
                      dialogContext,
                      'Não foi possível adicionar o turno: $error',
                    );
                  }
                }
              },
              child: const Text('Criar turno'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelShift(Map<String, dynamic> shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar turno?'),
        content: const Text('O turno será removido da escala desta unidade.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar turno'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(partnerOperatorsProvider.notifier)
          .cancelShift(shift['id'] as String);
      if (mounted) {
        _reload();
      }
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível cancelar o turno: $error',
        );
      }
    }
  }

  Future<void> _wizard() async {
    final parkings = ref
        .read(partnerParkingProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => <ManagedParkingModel>[],
        );
    final operators = ref
        .read(partnerOperatorsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => <PartnerOperatorModel>[],
        );
    if (parkings.isEmpty) {
      await ApiFeedback.show(
        context,
        'Cadastre uma unidade antes de criar a escala.',
      );
      return;
    }

    String parkingId = parkings.first.id!;
    final selectedOperators = <String>{};
    var assignedOperatorIds = <String>{};
    var step = 0;
    var loadingOperators = false;
    var saving = false;
    var startDate = DateTime.now();
    var endDate = DateTime.now();
    var opening = const TimeOfDay(hour: 7, minute: 0);
    var closing = const TimeOfDay(hour: 18, minute: 0);
    var workRegime = parkings.first.workRegime;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(context).height * .88,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Criar escala',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Stepper(
                      currentStep: step,
                      onStepCancel: step == 0 || saving
                          ? null
                          : () => setLocal(() => step--),
                      onStepContinue: saving || loadingOperators
                          ? null
                          : () async {
                              if (step == 0) {
                                setLocal(() {
                                  loadingOperators = true;
                                });
                                final assigned = <String>{};
                                try {
                                  for (final operator in operators) {
                                    final unitIds = await ref
                                        .read(partnerOperatorsProvider.notifier)
                                        .fetchOperatorParkings(operator.id);
                                    if (unitIds.contains(parkingId)) {
                                      assigned.add(operator.id);
                                    }
                                  }
                                } catch (error) {
                                  if (mounted) {
                                    await ApiFeedback.show(
                                      this.context,
                                      'Não foi possível carregar operadores autorizados: $error',
                                    );
                                  }
                                  setLocal(() => loadingOperators = false);
                                  return;
                                }
                                setLocal(() {
                                  assignedOperatorIds = assigned;
                                  selectedOperators
                                    ..clear()
                                    ..addAll(assigned);
                                  loadingOperators = false;
                                  step = 1;
                                });
                              } else if (step < 3) {
                                setLocal(() => step++);
                              } else {
                                setLocal(() => saving = true);
                                Navigator.pop(dialogContext);
                                await _generate(
                                  parkingId,
                                  selectedOperators.toList(),
                                  startDate,
                                  endDate,
                                  opening,
                                  closing,
                                  workRegime,
                                );
                              }
                            },
                      controlsBuilder: (context, details) => Row(
                        children: [
                          FilledButton.icon(
                            onPressed: details.onStepContinue,
                            icon: loadingOperators || saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward),
                            label: Text(
                              step == 3 ? 'Gerar escala' : 'Continuar',
                            ),
                          ),
                          if (step > 0)
                            TextButton(
                              onPressed: details.onStepCancel,
                              child: const Text('Voltar'),
                            ),
                        ],
                      ),
                      steps: [
                        Step(
                          isActive: step >= 0,
                          title: const Text('Unidade'),
                          content: DropdownButtonFormField<String>(
                            initialValue: parkingId,
                            isExpanded: true,
                            items: [
                              for (final parking in parkings)
                                DropdownMenuItem(
                                  value: parking.id,
                                  child: Text(
                                    parking.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) => setLocal(() {
                              parkingId = value!;
                              workRegime = parkings
                                  .firstWhere((item) => item.id == value)
                                  .workRegime;
                              assignedOperatorIds = {};
                              selectedOperators.clear();
                            }),
                          ),
                        ),
                        Step(
                          isActive: step >= 1,
                          title: const Text('Operadores autorizados'),
                          content: loadingOperators
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                )
                              : assignedOperatorIds.isEmpty
                              ? const Text(
                                  'Nenhum operador habilitado nesta unidade. A escala será criada com turnos sem responsável, e poderá ser atualizada depois.',
                                )
                              : Column(
                                  children: [
                                    for (final operator in operators.where(
                                      (item) =>
                                          assignedOperatorIds.contains(item.id),
                                    ))
                                      CheckboxListTile(
                                        value: selectedOperators.contains(
                                          operator.id,
                                        ),
                                        title: Text(operator.name),
                                        subtitle: Text(operator.email),
                                        onChanged: (value) => setLocal(
                                          () => value == true
                                              ? selectedOperators.add(
                                                  operator.id,
                                                )
                                              : selectedOperators.remove(
                                                  operator.id,
                                                ),
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                  ],
                                ),
                        ),
                        Step(
                          isActive: step >= 2,
                          title: const Text('Funcionamento'),
                          content: Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: workRegime,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Modelo de jornada desta escala',
                                  helperText:
                                      'O modelo da unidade é a sugestão. Confirme ou escolha outro para esta geração.',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'commercial',
                                    child: Text('Horário comercial'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'three_shifts',
                                    child: Text('24h · três turnos de 8h'),
                                  ),
                                  DropdownMenuItem(
                                    value: '24h_on_3off',
                                    child: Text(
                                      'Plantão de 24h · 3 dias de folga',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'administrative_8h',
                                    child: Text('Administrativo · 8h por dia'),
                                  ),
                                ],
                                onChanged: (value) => setLocal(
                                  () => workRegime = value ?? 'commercial',
                                ),
                              ),
                              ListTile(
                                title: const Text('Abertura'),
                                subtitle: Text(opening.format(context)),
                                trailing: const Icon(Icons.login),
                                onTap: () async {
                                  final value = await showTimePicker(
                                    context: context,
                                    initialTime: opening,
                                  );
                                  if (value != null) {
                                    setLocal(() => opening = value);
                                  }
                                },
                              ),
                              ListTile(
                                title: const Text('Fechamento'),
                                subtitle: Text(closing.format(context)),
                                trailing: const Icon(Icons.logout),
                                onTap: () async {
                                  final value = await showTimePicker(
                                    context: context,
                                    initialTime: closing,
                                  );
                                  if (value != null) {
                                    setLocal(() => closing = value);
                                  }
                                },
                              ),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'O horário semanal salvo na unidade continua sendo a referência quando estiver configurado.',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Step(
                          isActive: step >= 3,
                          title: const Text('Período'),
                          content: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Período da escala'),
                            subtitle: Text(
                              '${_dateLabel(startDate)} até ${_dateLabel(endDate)}',
                            ),
                            trailing: const Icon(Icons.date_range),
                            onTap: () async {
                              final value = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 366),
                                ),
                                initialDateRange: DateTimeRange(
                                  start: startDate,
                                  end: endDate.isBefore(startDate)
                                      ? startDate
                                      : endDate,
                                ),
                              );
                              if (value != null) {
                                setLocal(() {
                                  startDate = value.start;
                                  endDate = value.end;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  String _timeLabel(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _generate(
    String parkingId,
    List<String> operatorIds,
    DateTime first,
    DateTime last,
    TimeOfDay opening,
    TimeOfDay closing,
    String workRegime,
  ) async {
    final progress = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ScheduleProgressDialog(),
    );
    try {
      final suggestion = await ref
          .read(partnerOperatorsProvider.notifier)
          .suggestShifts(
            parkingId: parkingId,
            operatorIds: operatorIds,
            startsOn: first,
            endsOn: last,
            dailyHours: workRegime == '24h_on_3off'
                ? 24
                : workRegime == 'commercial'
                ? (((closing.hour * 60 + closing.minute) -
                              (opening.hour * 60 + opening.minute))
                          .clamp(60, 480)) /
                      60
                : 8,
            openingTime: _timeLabel(opening),
            closingTime: _timeLabel(closing),
            workRegime: workRegime,
          );
      final warning = suggestion['coverage_warning'] as String?;
      final entries = suggestion['suggestions'] as List<dynamic>? ?? const [];
      if (entries.isEmpty) {
        throw Exception(
          'Não há dias de funcionamento no período selecionado. Confira os horários da unidade.',
        );
      }
      for (final entry in entries) {
        final shift = entry as Map<String, dynamic>;
        await ref
            .read(partnerOperatorsProvider.notifier)
            .createShift(
              operatorId: shift['operator_id'] as String?,
              parkingId: parkingId,
              startsAt: DateTime.parse(shift['starts_at'] as String),
              endsAt: DateTime.parse(shift['ends_at'] as String),
            );
      }
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await progress;
      if (!mounted) return;
      _reload();
      final message = warning == null || warning.isEmpty
          ? 'Escala criada com ${entries.length} turno(s).'
          : 'Escala criada. $warning';
      await ApiFeedback.show(context, message, isError: false);
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await progress;
      if (!mounted) return;
      await ApiFeedback.show(
        context,
        'Não foi possível criar a escala: $error',
      );
    }
  }
}

class _ScheduleProgressDialog extends StatefulWidget {
  const _ScheduleProgressDialog();

  @override
  State<_ScheduleProgressDialog> createState() =>
      _ScheduleProgressDialogState();
}

class _ScheduleProgressDialogState extends State<_ScheduleProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    contentPadding: const EdgeInsets.all(24),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.translate(
            offset: Offset((_controller.value - .5) * 44, 0),
            child: child,
          ),
          child: const Icon(
            Icons.directions_car_filled,
            size: 42,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),
        const LinearProgressIndicator(),
        const SizedBox(height: 14),
        const Text(
          'Organizando os turnos da unidade…',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _ScheduleCalendar extends StatelessWidget {
  const _ScheduleCalendar({
    required this.selectedDay,
    required this.shifts,
    required this.parkingColors,
    required this.weekView,
    required this.onWeekViewChanged,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime selectedDay;
  final List<Map<String, dynamic>> shifts;
  final Map<String, Color> parkingColors;
  final bool weekView;
  final ValueChanged<bool> onWeekViewChanged;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.strings.isEnglish;
    final monthNames = isEnglish
        ? const [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ]
        : const [
            'Janeiro',
            'Fevereiro',
            'Março',
            'Abril',
            'Maio',
            'Junho',
            'Julho',
            'Agosto',
            'Setembro',
            'Outubro',
            'Novembro',
            'Dezembro',
          ];
    final weekdayNames = isEnglish
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    final firstVisible = weekView
        ? _startOfWeek(selectedDay)
        : _startOfWeek(DateTime(selectedDay.year, selectedDay.month, 1));
    final dayCount = weekView ? 7 : 42;
    final colorScheme = Theme.of(context).colorScheme;
    int shiftCount(DateTime date) => shifts.where((shift) {
      final starts = DateTime.parse(shift['starts_at'] as String).toLocal();
      return starts.year == date.year &&
          starts.month == date.month &&
          starts.day == date.day;
    }).length;
    int openCount(DateTime date) => shifts.where((shift) {
      final starts = DateTime.parse(shift['starts_at'] as String).toLocal();
      return starts.year == date.year &&
          starts.month == date.month &&
          starts.day == date.day &&
          shift['operator_id'] == null;
    }).length;
    List<String> unitIds(DateTime date) => shifts
        .where((shift) {
          final starts = DateTime.parse(shift['starts_at'] as String).toLocal();
          return starts.year == date.year &&
              starts.month == date.month &&
              starts.day == date.day;
        })
        .map((shift) => shift['parking_id'] as String)
        .toSet()
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: isEnglish ? 'Previous' : 'Anterior',
                  onPressed: () => onPageChanged(
                    weekView
                        ? selectedDay.subtract(const Duration(days: 7))
                        : DateTime(selectedDay.year, selectedDay.month - 1, 1),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      weekView
                          ? '${_shortDate(firstVisible)} – ${_shortDate(firstVisible.add(const Duration(days: 6)))}'
                          : '${monthNames[selectedDay.month - 1]} ${selectedDay.year}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isEnglish ? 'Next' : 'Próximo',
                  onPressed: () => onPageChanged(
                    weekView
                        ? selectedDay.add(const Duration(days: 7))
                        : DateTime(selectedDay.year, selectedDay.month + 1, 1),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Center(
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(isEnglish ? 'Month' : 'Mês'),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(isEnglish ? 'Week' : 'Semana'),
                  ),
                ],
                selected: {weekView},
                onSelectionChanged: (value) => onWeekViewChanged(value.first),
              ),
            ),
            Row(
              children: [
                for (final label in weekdayNames)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dayCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                // Keep enough vertical room for the day, status badge and
                // unit markers on narrow phone screens.
                childAspectRatio: 0.9,
              ),
              itemBuilder: (context, index) {
                final date = firstVisible.add(Duration(days: index));
                final selected =
                    date.year == selectedDay.year &&
                    date.month == selectedDay.month &&
                    date.day == selectedDay.day;
                final inMonth = weekView || date.month == selectedDay.month;
                final count = shiftCount(date);
                final open = openCount(date);
                final bg = selected ? colorScheme.primary : Colors.transparent;
                final fg = selected
                    ? colorScheme.onPrimary
                    : (inMonth
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: .36));
                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: Material(
                    color: bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onDaySelected(date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color: fg,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (count > 0)
                            Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? colorScheme.onPrimary.withValues(
                                        alpha: .2,
                                      )
                                    : (open > 0
                                          ? colorScheme.errorContainer
                                          : colorScheme.primaryContainer),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? colorScheme.onPrimary
                                      : (open > 0
                                            ? colorScheme.onErrorContainer
                                            : colorScheme.onPrimaryContainer),
                                ),
                              ),
                            ),
                          if (unitIds(date).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final id in unitIds(date).take(4))
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            parkingColors[id] ??
                                            colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _LegendDot(
                  color: colorScheme.primaryContainer,
                  label: isEnglish ? 'Scheduled shift' : 'Turno escalado',
                ),
                _LegendDot(
                  color: colorScheme.errorContainer,
                  label: isEnglish ? 'Unassigned shift' : 'Turno sem operador',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DateTime _startOfWeek(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: date.weekday - 1));
  String _shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}
