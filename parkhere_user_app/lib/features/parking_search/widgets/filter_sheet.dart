import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/filter_provider.dart';

class ParkingFilterSheet extends ConsumerWidget {
  const ParkingFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Filtros",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          SwitchListTile(
            title: const Text("Área coberta"),
            value: filter.covered,
            onChanged: (v) {
              ref.read(filterProvider.notifier).state =
                  filter.copyWith(covered: v);
            },
          ),

          SwitchListTile(
            title: const Text("Vagas VIP"),
            value: filter.vip,
            onChanged: (v) {
              ref.read(filterProvider.notifier).state =
                  filter.copyWith(vip: v);
            },
          ),

          SwitchListTile(
            title: const Text("Lavagem disponível"),
            value: filter.carWash,
            onChanged: (v) {
              ref.read(filterProvider.notifier).state =
                  filter.copyWith(carWash: v);
            },
          ),

          SwitchListTile(
            title: const Text("Guia turístico"),
            value: filter.tourGuide,
            onChanged: (v) {
              ref.read(filterProvider.notifier).state =
                  filter.copyWith(tourGuide: v);
            },
          ),

          SwitchListTile(
            title: const Text("Veículo para deslocamento"),
            value: filter.transport,
            onChanged: (v) {
              ref.read(filterProvider.notifier).state =
                  filter.copyWith(transport: v);
            },
          ),
        ],
      ),
    );
  }
}
