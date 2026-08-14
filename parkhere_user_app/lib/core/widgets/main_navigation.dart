import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/pages/vehicles_page.dart';
import '../../features/account/pages/wallet_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/profile_page.dart';
import '../../features/parking_search/pages/home_map_page.dart';
import '../../features/parking_search/models/parking_model.dart';
import '../../features/parking_search/providers/parking_provider.dart';
import '../../features/partner_management/pages/partner_financial_locked_page.dart';
import '../../features/partner_management/pages/partner_management_home_page.dart';
import '../../features/partner_management/pages/partner_parking_map_page.dart';
import '../../features/partner_management/pages/partner_reservations_page.dart';
import '../../features/partner_management/pages/partner_users_page.dart';
import '../../features/reservation/pages/reservation_page.dart';
import '../../features/auth/models/auth_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../theme/app_theme.dart';

enum _MainArea {
  menu,
  map,
  services,
  reservations,
  management,
  users,
  financial,
  profile,
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  late _MainArea _selectedArea;
  int _servicesInitialIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedArea = _initialArea();
  }

  @override
  Widget build(BuildContext context) {
    final isWebLayout = MediaQuery.sizeOf(context).width >= 900;
    final isPartner =
        ref.watch(authProvider).accountType == AuthAccountType.partner;
    final page = _pageFor(_selectedArea, isPartner);

    if (isWebLayout) {
      return Scaffold(
        body: Row(
          children: [
            _WebMenu(
              selectedArea: _selectedArea,
              isPartner: isPartner,
              onSelected: _selectArea,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: _MobileDrawer(
        isPartner: isPartner,
        onSelected: (area, [serviceTabIndex]) {
          Navigator.pop(context);
          _selectArea(area, serviceTabIndex);
        },
      ),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileIndexFor(_selectedArea, isPartner),
        onDestinationSelected: (index) {
          setState(() => _selectedArea = _areaForMobileIndex(index, isPartner));
        },
        destinations: [
          if (!isPartner)
            const NavigationDestination(
              icon: Icon(Icons.menu),
              selectedIcon: Icon(Icons.menu_open),
              label: 'Menu',
            ),
          if (isPartner)
            const NavigationDestination(
              icon: Icon(Icons.business_center_outlined),
              selectedIcon: Icon(Icons.business_center),
              label: 'Gestão',
            )
          else
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Mapa',
            ),
          if (isPartner)
            const NavigationDestination(
              icon: Icon(Icons.local_parking_outlined),
              selectedIcon: Icon(Icons.local_parking),
              label: 'Vagas',
            )
          else
            const NavigationDestination(
              icon: Icon(Icons.widgets_outlined),
              selectedIcon: Icon(Icons.widgets),
              label: 'Serviços',
            ),
          if (isPartner)
            const NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number),
              label: 'Reservas',
            )
          else
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          if (isPartner)
            const NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock),
              label: 'Financeiro',
            ),
          if (isPartner)
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
        ],
      ),
    );
  }

  Widget _pageFor(_MainArea area, bool isPartner) {
    switch (area) {
      case _MainArea.menu:
        return const _MenuHubPage();
      case _MainArea.map:
        if (isPartner) return const PartnerParkingMapPage();
        return const HomeMapPage();
      case _MainArea.services:
        if (isPartner) return const PartnerManagementHomePage();
        return _ServicesHubPage(
          key: ValueKey(_servicesInitialIndex),
          initialIndex: _servicesInitialIndex,
        );
      case _MainArea.reservations:
        if (isPartner) return const PartnerReservationsPage();
        return const ReservationPage();
      case _MainArea.management:
        return const PartnerManagementHomePage();
      case _MainArea.users:
        return const PartnerUsersPage();
      case _MainArea.financial:
        return const PartnerFinancialLockedPage();
      case _MainArea.profile:
        return const ProfilePage();
    }
  }

  int _mobileIndexFor(_MainArea area, bool isPartner) {
    switch (area) {
      case _MainArea.menu:
        return isPartner ? 0 : 0;
      case _MainArea.map:
        return isPartner ? 1 : 1;
      case _MainArea.services:
        return isPartner ? 1 : 2;
      case _MainArea.reservations:
        return isPartner ? 2 : 3;
      case _MainArea.management:
        return isPartner ? 0 : 3;
      case _MainArea.users:
        return isPartner ? 0 : 3;
      case _MainArea.financial:
        return isPartner ? 3 : 3;
      case _MainArea.profile:
        return isPartner ? 4 : 3;
    }
  }

  _MainArea _areaForMobileIndex(int index, bool isPartner) {
    switch (index) {
      case 0:
        return isPartner ? _MainArea.management : _MainArea.menu;
      case 1:
        return isPartner ? _MainArea.map : _MainArea.map;
      case 2:
        return isPartner ? _MainArea.reservations : _MainArea.services;
      case 3:
        return isPartner ? _MainArea.financial : _MainArea.profile;
      case 4:
        return _MainArea.profile;
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

  _MainArea _initialArea() {
    final auth = ref.read(authProvider);
    return auth.accountType == AuthAccountType.partner
        ? _MainArea.management
        : _MainArea.map;
  }
}

class _WebMenu extends ConsumerWidget {
  final _MainArea selectedArea;
  final bool isPartner;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _WebMenu({
    required this.selectedArea,
    required this.isPartner,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                if (isPartner)
                  _MenuItem(
                    Icons.business_center_outlined,
                    'Minha empresa',
                    _MainArea.management,
                  ),
                if (!isPartner)
                  _MenuItem(Icons.dashboard_outlined, 'Menu', _MainArea.menu),
                _MenuItem(
                  isPartner ? Icons.local_parking_outlined : Icons.map_outlined,
                  isPartner ? 'Mapa de vagas' : 'Mapa',
                  _MainArea.map,
                ),
                _MenuItem(
                  Icons.confirmation_number_outlined,
                  isPartner ? 'Reservas recebidas' : 'Reservas',
                  _MainArea.reservations,
                ),
                if (isPartner)
                  _MenuItem(Icons.group_outlined, 'Usuarios', _MainArea.users),
                if (isPartner)
                  _MenuItem(
                    Icons.lock_outline,
                    'Financeiro Pro',
                    _MainArea.financial,
                  ),
              ],
              selectedArea: selectedArea,
              onSelected: onSelected,
            ),
            if (!isPartner)
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
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final bool isPartner;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _MobileDrawer({required this.isPartner, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('ParkHere', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (isPartner)
              ListTile(
                leading: const Icon(Icons.business_center_outlined),
                title: const Text('Minha empresa'),
                onTap: () => onSelected(_MainArea.management),
              ),
            if (!isPartner) ...[
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
            ],
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: Text(isPartner ? 'Reservas recebidas' : 'Reservas'),
              onTap: () => onSelected(_MainArea.reservations),
            ),
            if (isPartner)
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Usuarios'),
                onTap: () => onSelected(_MainArea.users),
              ),
            if (isPartner)
              ListTile(
                leading: const Icon(Icons.local_parking_outlined),
                title: const Text('Mapa de vagas'),
                onTap: () => onSelected(_MainArea.map),
              ),
            if (isPartner)
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Financeiro Pro'),
                onTap: () => onSelected(_MainArea.financial),
              )
            else ...[
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
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Perfil'),
              onTap: () => onSelected(_MainArea.profile),
            ),
            const Divider(),
            const _DrawerLogoutTile(),
          ],
        ),
      ),
    );
  }
}

class _DrawerLogoutTile extends ConsumerWidget {
  const _DrawerLogoutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text('Sair', style: TextStyle(color: Colors.red)),
      onTap: () async {
        await ref.read(authProvider.notifier).logout();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      },
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
            _CarWashServicesList(),
            _PromotionServicesList(serviceType: _PromotionServiceType.hotel),
            _PromotionServicesList(serviceType: _PromotionServiceType.tourism),
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

class _CarWashServicesList extends ConsumerWidget {
  const _CarWashServicesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkings = ref.watch(parkingProvider);

    return parkings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
      data: (items) {
        final carWashParkings = items
            .where((parking) => parking.hasCarWash)
            .toList();

        if (carWashParkings.isEmpty) {
          return const Center(child: Text('Nenhum lava jato disponível.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: carWashParkings.length,
          itemBuilder: (context, index) {
            final parking = carWashParkings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.softCyan,
                  foregroundColor: AppTheme.primary,
                  child: const Icon(Icons.local_car_wash),
                ),
                title: Text(parking.name),
                subtitle: Text(
                  'Lavagem a partir de R\$ ${parking.carWashPrice.toStringAsFixed(2)} | ${parking.availableSpots} vagas',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Contratação pelo app entra no próximo bloco.',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

enum _PromotionServiceType { hotel, tourism }

class _PromotionServicesList extends StatelessWidget {
  final _PromotionServiceType serviceType;

  const _PromotionServicesList({required this.serviceType});

  @override
  Widget build(BuildContext context) {
    final items = serviceType == _PromotionServiceType.hotel
        ? const [
            _PromotionItem(
              icon: Icons.hotel_outlined,
              title: 'Hotel Bahia Centro',
              subtitle:
                  'Diárias promocionais para quem reservou estacionamento.',
              tag: 'Hotel',
            ),
            _PromotionItem(
              icon: Icons.restaurant_outlined,
              title: 'Restaurante Terraço',
              subtitle:
                  'Oferta parceira próxima aos estacionamentos do centro.',
              tag: 'Gastronomia',
            ),
          ]
        : const [
            _PromotionItem(
              icon: Icons.tour_outlined,
              title: 'Tour histórico Salvador',
              subtitle:
                  'Passeio guiado com ponto de encontro no estacionamento.',
              tag: 'Passeio',
            ),
            _PromotionItem(
              icon: Icons.directions_boat_outlined,
              title: 'Experiência Baía de Todos-os-Santos',
              subtitle: 'Pacote turístico com reserva e pagamento pelo app.',
              tag: 'Turismo',
            ),
          ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in items)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.softCyan,
                    foregroundColor: AppTheme.primary,
                    child: Icon(item.icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text(item.tag),
                            backgroundColor: AppTheme.softCyan,
                            side: BorderSide.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PromotionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;

  const _PromotionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
  });
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
