import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../reservation/models/reservation_enum.dart';
import '../../reservation/models/reservation_model.dart';
import '../../reservation/providers/reservation_provider.dart';
import '../models/pre_checkin_model.dart';
import '../../payments/pages/payment_page.dart';
import '../providers/checkout_privider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/api_feedback.dart';

class CheckinPage extends ConsumerStatefulWidget {
  final PreCheckinModel preCheckin;
  final VoidCallback? onPaymentSuccess;

  const CheckinPage({
    super.key,
    required this.preCheckin,
    this.onPaymentSuccess,
  });

  @override
  ConsumerState<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends ConsumerState<CheckinPage> {
  final _picker = ImagePicker();
  final Map<String, XFile?> _captured = {};
  bool frontPhoto = false;
  bool leftPhoto = false;
  bool rightPhoto = false;
  bool backPhoto = false;
  bool hasGuideIndication = false;
  bool _checkingIn = false;
  bool _locationValidated = false;
  bool _checkingLocation = true;
  String _checkinStep = '';
  final Set<String> _uploadedPhotoKinds = {};

  bool get allPhotosDone => frontPhoto && leftPhoto && rightPhoto && backPhoto;

  @override
  void initState() {
    super.initState();
    _validateLocationBeforeCapture();
  }

  Future<void> _validateLocationBeforeCapture() async {
    try {
      final position = await LocationService().getCurrentLocation();
      final distance = LocationService().calculateDistance(
        startLat: position.latitude,
        startLng: position.longitude,
        endLat: widget.preCheckin.parking.lat,
        endLng: widget.preCheckin.parking.lng,
      );
      if (!mounted) return;
      setState(() {
        _locationValidated = distance <= 70;
        _checkingLocation = false;
      });
      if (distance > 70) {
        await ApiFeedback.show(
          context,
          'A localização está a ${distance.round()} m do estacionamento. '
          'O check-in exige até 70 m. Confirme o ponto do estacionamento no mapa e tente novamente.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationValidated = false;
        _checkingLocation = false;
      });
      await ApiFeedback.show(context, '$error');
    }
  }

  Future<void> _capture(String kind, VoidCallback markDone) async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 30 * 1024 * 1024) {
        await ApiFeedback.show(context, 'A foto deve ter no máximo 30 MB.');
        return;
      }
      final token = ref.read(authProvider).accessToken;
      final reservationId = widget.preCheckin.reservationId;
      if (token != null && reservationId != null) {
        try {
          await _uploadPhoto(kind, photo, bytes, token, reservationId);
          _uploadedPhotoKinds.add(kind);
        } catch (error) {
          // Keep the camera result in the current session and retry before
          // check-in. A transient upload failure must not look like a dead
          // capture button.
          if (mounted) {
            await ApiFeedback.show(
              context,
              'Foto salva localmente. Vamos tentar enviar novamente ao concluir o check-in.',
            );
          }
        }
      }
      _captured[kind] = photo;
      markDone();
    } on PlatformException catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível abrir a câmera. Verifique a permissão do iPhone e tente novamente. ${error.message ?? ''}',
        );
      }
    } catch (error) {
      if (mounted) {
        await ApiFeedback.show(
          context,
          'Não foi possível registrar a foto: $error',
        );
      }
    }
  }

  Future<void> _showServiceSummary(BuildContext context) async {
    final pre = widget.preCheckin;

    final shouldOpenPayment = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom + 90,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra Uber
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                Text(
                  "Resumo do Check-in",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF102657),
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  "Estacionamento: ${pre.parking.name}",
                  style: const TextStyle(fontSize: 16),
                ),
                if (pre.reservationId != null) ...[
                  const SizedBox(height: 6),
                  Text('Código da reserva: ${pre.reservationId}'),
                ],

                const SizedBox(height: 10),

                Text(
                  "Plano escolhido: ${pre.plan.name.toUpperCase()}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF169FC4),
                  ),
                ),

                if (pre.plan.name == "hourly")
                  Text(
                    "⏱ Primeira hora: R\$ ${pre.parking.pricing.firstHourPrice}\n"
                    "➕ Hora adicional: R\$ ${pre.parking.pricing.additionalHourPrice}",
                    style: const TextStyle(fontSize: 16),
                  )
                else if (pre.plan.name == "daily")
                  Text(
                    "Valor: R\$ ${pre.parking.pricing.dailyPrice}",
                    style: const TextStyle(fontSize: 16),
                  )
                else if (pre.plan.name == "monthly")
                  Text(
                    "Valor: R\$ ${pre.parking.pricing.monthlyPrice}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                const SizedBox(height: 15),

                const Text(
                  "Serviços adicionais:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                Text(
                  'Valor total: R\$ ${pre.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                if (!pre.carWash && !pre.tourGuide && !pre.transport)
                  const Text("Nenhum serviço adicional selecionado."),

                if (pre.carWash)
                  _serviceItem(
                    "Lavagem pintura de veículos R\$${pre.parking.carWashPrice}",
                  ),
                if (pre.tourGuide)
                  _serviceItem(
                    "Guia turístico, R\$${pre.parking.tourGuidePrice}",
                  ),
                if (pre.transport)
                  _serviceItem("Transporte, R\$${pre.parking.transportPrice}"),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Esta reserva tem indicação de guia?'),
                  subtitle: const Text(
                    'A comissão é registrada somente quando houver indicação.',
                  ),
                  value: hasGuideIndication,
                  onChanged: (value) =>
                      setState(() => hasGuideIndication = value),
                ),

                const SizedBox(height: 15),

                const Divider(thickness: 2),

                const SizedBox(height: 15),

                if (pre.plan.name == "hourly")
                  Text(
                    "Total parcial: R\$ ${pre.total}\n",
                    // "Desconto: R\$ ${pre.discount}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF169FC4),
                    ),
                  ),
                if (pre.plan.name == "hourly")
                  Text(
                    "O valor será calculado no checkout, de acordo com o tempo estacionado.",
                    style: const TextStyle(
                      fontSize: 13,
                      // color: Color(0xFF169FC4),
                    ),
                  ),

                if (pre.plan.name != "hourly")
                  Text(
                    "Total: R\$ ${pre.total}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      // color: Color(0xFF169FC4),
                    ),
                  ),
                const SizedBox(height: 15),

                // Botão Confirmar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF169FC4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pop(sheetContext, pre.plan.name != 'hourly'),

                    child: Text(
                      pre.plan.name == 'hourly'
                          ? "Confirmar check-in"
                          : "Pagar e confirmar check-in",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (shouldOpenPayment == true) {
      await _openPaymentAndConfirmCheckin();
      return;
    }

    // Horários são cobrados no checkout. O check-in já foi confirmado pela
    // API, então persistimos a sessão local sem abrir pagamento.
    if (pre.plan.name == 'hourly') {
      _createReservation();
      ref.read(checkoutProvider.notifier).paymentSuccess();
      if (context.mounted) Navigator.pop(context, true);
    }
  }

  Widget _serviceItem(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parking = widget.preCheckin.parking;

    return Scaffold(
      appBar: AppBar(title: const Text("Check-in")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parking.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            const Text(
              "Tire 4 fotos obrigatórias do veículo:",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 15),

            _photoItem(
              "Frontal",
              frontPhoto,
              () => _capture('front', () => setState(() => frontPhoto = true)),
            ),

            _photoItem(
              "Lateral esquerda",
              leftPhoto,
              () => _capture('left', () => setState(() => leftPhoto = true)),
            ),

            _photoItem(
              "Lateral direita",
              rightPhoto,
              () => _capture('right', () => setState(() => rightPhoto = true)),
            ),

            _photoItem(
              "Traseira",
              backPhoto,
              () => _capture('rear', () => setState(() => backPhoto = true)),
            ),

            if (_checkingIn)
              Card(
                margin: const EdgeInsets.only(top: 12),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _checkinStep.isEmpty
                              ? 'Processando check-in...'
                              : _checkinStep,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF169FC4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _checkingIn || !allPhotosDone
                    ? null
                    : _completeCheckinBeforePayment,
                child: _checkingIn
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.preCheckin.plan.name == 'hourly'
                            ? "Concluir check-in"
                            : "Avançar para pagamento",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeCheckinBeforePayment() async {
    if (_checkingIn) return;
    if (!allPhotosDone) {
      await ApiFeedback.show(
        context,
        'Conclua as quatro fotos do veículo antes de finalizar o check-in.',
      );
      return;
    }
    if (!_locationValidated) {
      await ApiFeedback.show(
        context,
        'Confirme sua localização dentro do estacionamento antes de concluir.',
      );
      return;
    }
    setState(() {
      _checkingIn = true;
      _checkinStep = 'Enviando fotos do veículo...';
    });
    if (!await _uploadPendingPhotos()) {
      if (mounted) {
        setState(() {
          _checkingIn = false;
          _checkinStep = '';
        });
      }
      return;
    }
    if (mounted) setState(() => _checkinStep = 'Confirmando check-in...');
    final success = await _confirmBackendCheckin();
    if (mounted) {
      setState(() {
        _checkingIn = false;
        _checkinStep = '';
      });
    }
    if (success && mounted) {
      await ApiFeedback.show(
        context,
        'Check-in realizado com sucesso. O veículo foi registrado no estacionamento.',
        isError: false,
        title: 'Check-in concluído',
      );
      if (mounted) await _showServiceSummary(context);
    }
  }

  Future<void> _uploadPhoto(
    String kind,
    XFile photo,
    List<int> bytes,
    String token,
    String reservationId,
  ) {
    return ApiService().uploadAuthorizedFile(
      '/reservations/$reservationId/photos?kind=$kind',
      token,
      photo.name,
      bytes,
    );
  }

  Future<bool> _uploadPendingPhotos() async {
    final token = ref.read(authProvider).accessToken;
    final reservationId = widget.preCheckin.reservationId;
    if (token == null) {
      await ApiFeedback.show(context, 'Sessão expirada. Entre novamente.');
      return false;
    }
    if (reservationId == null || reservationId.isEmpty) {
      await ApiFeedback.show(
        context,
        'A reserva não foi sincronizada. Atualize a tela de reservas e tente novamente.',
      );
      return false;
    }
    for (final entry in _captured.entries) {
      if (_uploadedPhotoKinds.contains(entry.key) || entry.value == null) {
        continue;
      }
      try {
        final photo = entry.value!;
        final bytes = await photo.readAsBytes();
        await _uploadPhoto(entry.key, photo, bytes, token, reservationId);
        _uploadedPhotoKinds.add(entry.key);
      } catch (error) {
        if (!mounted) return false;
        await ApiFeedback.show(
          context,
          'Não foi possível enviar a foto ${entry.key}. Verifique a conexão e tente novamente.',
        );
        return false;
      }
    }
    return true;
  }

  Widget _photoItem(String label, bool done, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        done ? Icons.check_circle : Icons.camera_alt,
        color: done ? Colors.green : Colors.grey,
      ),
      title: Text(label),
      trailing: ElevatedButton(
        onPressed: done || _checkingLocation || !_locationValidated
            ? null
            : onTap,
        child: Text(done ? "OK" : "Capturar"),
      ),
    );
  }

  void _createReservation() {
    final pre = widget.preCheckin;

    final reservation = ReservationModel(
      id: pre.reservationId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      parkingName: pre.parking.name,
      plan: pre.plan,
      status: ReservationStatus.open,
      checkedIn: true,
      checkinAt: DateTime.now(),
      estimatedValue: pre.total,
      carWash: pre.carWash,
      tourGuide: pre.tourGuide,
      transport: pre.transport,
      firstHourPrice: pre.parking.pricing.firstHourPrice,
      additionalHourPrice: pre.parking.pricing.additionalHourPrice,
      checkinTime: DateTime.now(),
      hasUnpaidServices: false,
      unpaidServicesValue: 0.0,
      validUntil: DateTime.now().add(const Duration(hours: 12)),
      preCheckin: widget.preCheckin,
    );

    ref.read(reservationsProvider.notifier).createReservation(reservation);
  }

  Future<void> _openPaymentAndConfirmCheckin() async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          amount: widget.preCheckin.total,
          reservationId: widget.preCheckin.reservationId,
          payNow: true,
          onPaymentSuccess: () async {
            _createReservation();
            ref.read(checkoutProvider.notifier).paymentSuccess();
          },
        ),
      ),
    );
    if (paid == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<bool> _confirmBackendCheckin() async {
    final reservationId = widget.preCheckin.reservationId;
    final token = ref.read(authProvider).accessToken;
    if (token == null) {
      await ApiFeedback.show(context, 'Sessão expirada. Entre novamente.');
      return false;
    }
    if (reservationId == null || reservationId.isEmpty) {
      await ApiFeedback.show(
        context,
        'A reserva não foi sincronizada. Atualize a tela de reservas e tente novamente.',
      );
      return false;
    }
    try {
      final position = await LocationService().getCurrentLocation();
      await ApiService().postAuthorized(
        '/reservations/$reservationId/checkin?latitude=${position.latitude}&longitude=${position.longitude}',
        {},
        token,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check-in não concluído'),
          content: Text('$error', textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return false;
    }
  }
}
