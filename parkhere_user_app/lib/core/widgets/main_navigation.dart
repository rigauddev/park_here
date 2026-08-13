import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/pages/vehicles_page.dart';
import '../../features/account/pages/wallet_page.dart';
import '../../features/auth/pages/profile_page.dart';
import '../../features/parking_search/pages/home_map_page.dart';
import '../../features/parking_search/models/parking_model.dart';
import '../../features/parking_search/providers/parking_provider.dart';
import '../../features/reservation/pages/reservation_page.dart';
import '../theme/app_theme.dart';

enum _MainArea { menu, map, services, reservations, profile }

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  _MainArea _selectedArea = _MainArea.map;
  int _servicesInitialIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isWebLayout = MediaQuery.sizeOf(context).width >= 900;
    final page = _pageFor(_selectedArea);

    if (isWebLayout) {
      return Scaffold(
        body: Row(
          children: [
            _WebMenu(selectedArea: _selectedArea, onSelected: _selectArea),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: _MobileDrawer(
        onSelected: (area, [serviceTabIndex]) {
          Navigator.pop(context);
          _selectArea(area, serviceTabIndex);
        },
      ),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileIndexFor(_selectedArea),
        onDestinationSelected: (index) {
          setState(() => _selectedArea = _areaForMobileIndex(index));
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu_open),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: 'Serviços',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _pageFor(_MainArea area) {
    switch (area) {
      case _MainArea.menu:
        return const _MenuHubPage();
      case _MainArea.map:
        return const HomeMapPage();
      case _MainArea.services:
        return _ServicesHubPage(
          key: ValueKey(_servicesInitialIndex),
          initialIndex: _servicesInitialIndex,
        );
      case _MainArea.reservations:
        return const ReservationPage();
      case _MainArea.profile:
        return const ProfilePage();
    }
  }

  int _mobileIndexFor(_MainArea area) {
    switch (area) {
      case _MainArea.menu:
        return 0;
      case _MainArea.map:
        return 1;
      case _MainArea.services:
        return 2;
      case _MainArea.reservations:
      case _MainArea.profile:
        return 3;
    }
  }

  _MainArea _areaForMobileIndex(int index) {
    switch (index) {
      case 0:
        return _MainArea.menu;
      case 1:
        return _MainArea.map;
      case 2:
        return _MainArea.services;
      case 3:
      default:
        return _MainArea.profile;
    }
  }

  void _selectArea(_MainArea area, [int? serviceTabIndex]) {
    setState(() {
      _selectedArea = area;
      if (serviceTabIndex != null) {
        _servicesInitialIndex = serviceTabIndex;
      }
    });
  }
}

class _WebMenu extends StatelessWidget {
  final _MainArea selectedArea;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _WebMenu({required this.selectedArea, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('ParkHere', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            _MenuCategory(
              title: 'Navegação',
              items: [
                _MenuItem(Icons.dashboard_outlined, 'Menu', _MainArea.menu),
                _MenuItem(Icons.map_outlined, 'Mapa', _MainArea.map),
                _MenuItem(
                  Icons.confirmation_number_outlined,
                  'Reservas',
                  _MainArea.reservations,
                ),
              ],
              selectedArea: selectedArea,
              onSelected: onSelected,
            ),
            _MenuCategory(
              title: 'Serviços',
              items: [
                _MenuItem(
                  Icons.local_parking,
                  'Estacionamento',
                  _MainArea.services,
                  serviceTabIndex: 0,
                ),
                _MenuItem(
                  Icons.local_car_wash,
                  'Lava jato',
                  _MainArea.services,
                  serviceTabIndex: 1,
                ),
                _MenuItem(
                  Icons.hotel_outlined,
                  'Hotéis',
                  _MainArea.services,
                  serviceTabIndex: 2,
                ),
                _MenuItem(
                  Icons.tour_outlined,
                  'Passeios turísticos',
                  _MainArea.services,
                  serviceTabIndex: 3,
                ),
              ],
              selectedArea: selectedArea,
              onSelected: onSelected,
            ),
            _MenuCategory(
              title: 'Conta',
              items: [
                _MenuItem(Icons.person_outline, 'Perfil', _MainArea.profile),
              ],
              selectedArea: selectedArea,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _MobileDrawer({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('ParkHere', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('Veículos'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehiclesPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Carteira'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: const Text('Reservas'),
              onTap: () => onSelected(_MainArea.reservations),
            ),
            ListTile(
              leading: const Icon(Icons.local_parking),
              title: const Text('Estacionamento'),
              onTap: () => onSelected(_MainArea.services, 0),
            ),
            ListTile(
              leading: const Icon(Icons.local_car_wash),
              title: const Text('Lava jato'),
              onTap: () => onSelected(_MainArea.services, 1),
            ),
            ListTile(
              leading: const Icon(Icons.hotel_outlined),
              title: const Text('Hotéis'),
              onTap: () => onSelected(_MainArea.services, 2),
            ),
            ListTile(
              leading: const Icon(Icons.tour_outlined),
              title: const Text('Passeios turísticos'),
              onTap: () => onSelected(_MainArea.services, 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCategory extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  final _MainArea selectedArea;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _MenuCategory({
    required this.title,
    required this.items,
    required this.selectedArea,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          for (final item in items)
            ListTile(
              selected: selectedArea == item.area,
              leading: Icon(item.icon),
              title: Text(item.label),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => onSelected(item.area, item.serviceTabIndex),
            ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final _MainArea area;
  final int? serviceTabIndex;

  const _MenuItem(this.icon, this.label, this.area, {this.serviceTabIndex});
}

class _MenuHubPage extends StatelessWidget {
  const _MenuHubPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _MenuActionCard(
            icon: Icons.directions_car_outlined,
            title: 'Veículos',
            subtitle: 'Gerencie o veículo ativo para reservas',
            page: VehiclesPage(),
          ),
          _MenuActionCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Carteira',
            subtitle: 'Cartões, Pix e método principal',
            page: WalletPage(),
          ),
          _MenuActionCard(
            icon: Icons.confirmation_number_outlined,
            title: 'Reservas',
            subtitle: 'Acompanhe reservas ativas e histórico',
            page: ReservationPage(),
          ),
        ],
      ),
    );
  }
}

class _ServicesHubPage extends StatelessWidget {
  final int initialIndex;

  const _ServicesHubPage({super.key, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Serviços'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.local_parking), text: 'Estacionamento'),
              Tab(icon: Icon(Icons.local_car_wash), text: 'Lava jato'),
              Tab(icon: Icon(Icons.hotel_outlined), text: 'Hotéis'),
              Tab(icon: Icon(Icons.tour_outlined), text: 'Passeios'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AvailableParkingsList(),
            _ServicePlaceholder(
              icon: Icons.local_car_wash,
              title: 'Lava jato',
              subtitle:
                  'Serviços de lavagem contratados no fluxo da reserva entram aqui.',
            ),
            _ServicePlaceholder(
              icon: Icons.hotel_outlined,
              title: 'Hotéis',
              subtitle:
                  'Banners e ofertas de hotéis parceiros serão listados neste submenu.',
            ),
            _ServicePlaceholder(
              icon: Icons.tour_outlined,
              title: 'Passeios turísticos',
              subtitle:
                  'Pacotes, guias e experiências turísticas entram neste submenu.',
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailableParkingsList extends ConsumerWidget {
  const _AvailableParkingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkings = ref.watch(parkingProvider);

    return parkings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
      data: (items) {
        final available =
            items.where((parking) => parking.availableSpots > 0).toList()
              ..sort((a, b) => b.availableSpots.compareTo(a.availableSpots));

        if (available.isEmpty) {
          return const Center(
            child: Text('Nenhum estacionamento disponivel no momento.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: available.length,
          itemBuilder: (context, index) {
            return _ParkingServiceCard(parking: available[index]);
          },
        );
      },
    );
  }
}

class _ParkingServiceCard extends StatelessWidget {
  final ParkingModel parking;

  const _ParkingServiceCard({required this.parking});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.softCyan,
          foregroundColor: AppTheme.primary,
          child: const Icon(Icons.local_parking),
        ),
        title: Text(parking.name),
        subtitle: Text(
          '${parking.availableSpots} vagas | R\$ ${parking.pricing.firstHourPrice.toStringAsFixed(2)} primeira hora',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            Text(parking.rating.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }
}

class _ServicePlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ServicePlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.softCyan,
                    foregroundColor: AppTheme.primary,
                    child: Icon(icon, size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  const _MenuActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.softCyan,
          foregroundColor: AppTheme.primary,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }
}
