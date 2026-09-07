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
import '../../features/auth/providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../../features/partner_management/pages/parking_dashboard_page.dart';
import '../../features/partner_management/pages/guide_affiliations_page.dart';
import '../../features/partner_management/pages/guide_dashboard_page.dart';
import '../../features/partner_management/pages/admin_management_page.dart';

enum _MainArea {
  menu,
  map,
  services,
  reservations,
  vehicles,
  wallet,
  management,
  users,
  financial,
  dashboard,
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
  bool _menuExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedArea = _initialArea();
  }

  @override
  Widget build(BuildContext context) {
    final isWebLayout = MediaQuery.sizeOf(context).width >= 900;
    final auth = ref.watch(authProvider);
    final isPartner = auth.isPartnerSession;
    final isPartnerOwner = auth.isPartnerOwner;
    final isGuide = auth.isTourGuide;
    final isAdmin = auth.role == 'super_admin';
    if (isGuide &&
        (_selectedArea == _MainArea.financial ||
            _selectedArea == _MainArea.reservations)) {
      _selectedArea = _MainArea.management;
    } else if (isPartner &&
        !isPartnerOwner &&
        _selectedArea == _MainArea.financial) {
      _selectedArea = _MainArea.map;
    }
    final page = Navigator(
      key: ValueKey('${_selectedArea.name}:$_servicesInitialIndex'),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => _pageFor(
          _selectedArea,
          isPartner,
          isPartnerOwner,
          isGuide,
          isAdmin,
        ),
      ),
    );
    final topBar = AppBar(
      title: const Text('ParkHere'),
      actions: [
        if (!isWebLayout && _menuExpanded)
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Navegação',
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
      ],
      leading: isWebLayout
          ? IconButton(
              tooltip: _menuExpanded ? 'Ocultar menu' : 'Mostrar menu',
              icon: Icon(_menuExpanded ? Icons.menu_open : Icons.menu),
              onPressed: () => setState(() => _menuExpanded = !_menuExpanded),
            )
          : null,
    );

    if (isWebLayout) {
      return Scaffold(
        appBar: topBar,
        body: Row(
          children: [
            _WebMenu(
              expanded: _menuExpanded,
              selectedArea: _selectedArea,
              isPartner: isPartner,
              isPartnerOwner: isPartnerOwner,
              isGuide: isGuide,
              onSelected: _selectArea,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: topBar,
      drawer: _MobileDrawer(
        isPartner: isPartner,
        isPartnerOwner: isPartnerOwner,
        isGuide: isGuide,
        onSelected: (area, [serviceTabIndex]) {
          Navigator.pop(context);
          _selectArea(area, serviceTabIndex);
        },
      ),
      body: Row(
        children: [
          if (!_menuExpanded)
            _WebMenu(
              expanded: false,
              selectedArea: _selectedArea,
              isPartner: isPartner,
              isPartnerOwner: isPartnerOwner,
              isGuide: isGuide,
              onSelected: _selectArea,
            ),
          Expanded(child: page),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileIndexFor(
          _selectedArea,
          isPartner,
          isPartnerOwner,
          isGuide,
        ),
        onDestinationSelected: (index) {
          setState(
            () => _selectedArea = _areaForMobileIndex(
              index,
              isPartner,
              isPartnerOwner,
              isGuide,
            ),
          );
        },
        destinations: [
          if (!isPartner)
            const NavigationDestination(
              icon: Icon(Icons.menu),
              selectedIcon: Icon(Icons.menu_open),
              label: 'Menu',
            ),
          if (isPartner && (isPartnerOwner || isGuide))
            const NavigationDestination(
              icon: Icon(Icons.business_center_outlined),
              selectedIcon: Icon(Icons.business_center),
              label: 'Gestão',
            ),
          if (isPartner)
            NavigationDestination(
              icon: const Icon(Icons.local_parking_outlined),
              selectedIcon: const Icon(Icons.local_parking),
              label: isGuide ? 'Estacionamentos' : 'Vagas',
            )
          else
            const NavigationDestination(
              icon: Icon(Icons.widgets_outlined),
              selectedIcon: Icon(Icons.widgets),
              label: 'Serviços',
            ),
          if (isPartner && !isGuide)
            const NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              selectedIcon: Icon(Icons.confirmation_number),
              label: 'Reservas',
            ),
          if (!isPartner)
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Mapa',
            ),
          if (!isPartner || isGuide)
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          if (isPartner && isPartnerOwner && !isGuide)
            const NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock),
              label: 'Financeiro',
            ),
          if (isPartner && !isGuide)
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
        ],
      ),
    );
  }

  Widget _pageFor(
    _MainArea area,
    bool isPartner,
    bool isPartnerOwner,
    bool isGuide,
    bool isAdmin,
  ) {
    if (isAdmin) return const AdminManagementPage();
    switch (area) {
      case _MainArea.menu:
        return const _MenuHubPage();
      case _MainArea.map:
        if (isGuide) return const GuideAffiliationsPage();
        if (isPartner) return const PartnerParkingMapPage();
        return const HomeMapPage();
      case _MainArea.services:
        if (isPartner) return const PartnerManagementHomePage();
        return _ServicesHubPage(
          key: ValueKey(_servicesInitialIndex),
          initialIndex: _servicesInitialIndex,
        );
      case _MainArea.reservations:
        if (isGuide) return const GuideDashboardPage();
        if (isPartner) return const PartnerReservationsPage();
        return const ReservationPage();
      case _MainArea.vehicles:
        if (isPartner) return const ProfilePage();
        return const VehiclesPage();
      case _MainArea.wallet:
        if (isPartner) return const ProfilePage();
        return const WalletPage();
      case _MainArea.management:
        if (isGuide) return const GuideDashboardPage();
        return isPartnerOwner
            ? const PartnerManagementHomePage()
            : const PartnerParkingMapPage();
      case _MainArea.users:
        return isPartnerOwner ? const PartnerUsersPage() : const ProfilePage();
      case _MainArea.dashboard:
        if (isGuide) return const GuideDashboardPage();
        return isPartnerOwner
            ? const ParkingDashboardPage()
            : const PartnerParkingMapPage();
      case _MainArea.financial:
        return isPartnerOwner
            ? const PartnerFinancialLockedPage()
            : const PartnerParkingMapPage();
      case _MainArea.profile:
        return const ProfilePage();
    }
  }

  int _mobileIndexFor(
    _MainArea area,
    bool isPartner,
    bool isPartnerOwner,
    bool isGuide,
  ) {
    if (isGuide) return area == _MainArea.map ? 1 : 0;
    if (isPartner && !isPartnerOwner) {
      switch (area) {
        case _MainArea.map:
          return 0;
        case _MainArea.reservations:
          return 1;
        case _MainArea.vehicles:
        case _MainArea.wallet:
        case _MainArea.profile:
          return 2;
        default:
          return 0;
      }
    }

    switch (area) {
      case _MainArea.menu:
        return isPartner ? 0 : 0;
      case _MainArea.map:
        return isPartner ? 1 : 2;
      case _MainArea.services:
        return isPartner ? 1 : 1;
      case _MainArea.reservations:
        return isPartner ? 2 : 3;
      case _MainArea.vehicles:
      case _MainArea.wallet:
        return isPartner ? 4 : 2;
      case _MainArea.management:
        return isPartner ? 0 : 2;
      case _MainArea.users:
        return isPartner ? 0 : 2;
      case _MainArea.financial:
        return isPartner ? 3 : 2;
      case _MainArea.dashboard:
        return isPartner ? 0 : 2;
      case _MainArea.profile:
        return isPartner ? 4 : 3;
    }
  }

  _MainArea _areaForMobileIndex(
    int index,
    bool isPartner,
    bool isPartnerOwner,
    bool isGuide,
  ) {
    if (isGuide) {
      if (index == 1) return _MainArea.map;
      if (index == 2) return _MainArea.profile;
      return _MainArea.management;
    }
    if (isPartner && !isPartnerOwner) {
      switch (index) {
        case 0:
          return _MainArea.map;
        case 1:
          return _MainArea.reservations;
        case 2:
          return _MainArea.profile;
        default:
          return _MainArea.map;
      }
    }

    switch (index) {
      case 0:
        return isPartner ? _MainArea.management : _MainArea.menu;
      case 1:
        return isPartner ? _MainArea.map : _MainArea.services;
      case 2:
        return isPartner ? _MainArea.reservations : _MainArea.map;
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
    if (auth.role == 'super_admin') return _MainArea.management;
    if (!auth.isPartnerSession) return _MainArea.map;
    return auth.isTourGuide || auth.isPartnerOwner
        ? _MainArea.management
        : _MainArea.map;
  }
}

class _WebMenu extends ConsumerWidget {
  final bool expanded;
  final _MainArea selectedArea;
  final bool isPartner;
  final bool isPartnerOwner;
  final bool isGuide;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _WebMenu({
    this.expanded = true,
    required this.selectedArea,
    required this.isPartner,
    required this.isPartnerOwner,
    required this.isGuide,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: expanded ? 280 : 72,
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(expanded ? 16 : 4),
          children: [
            if (expanded)
              Text('ParkHere', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            _MenuCategory(
              expanded: expanded,
              title: 'Navegação',
              items: [
                if (isPartner && (isPartnerOwner || isGuide))
                  _MenuItem(
                    Icons.dashboard_outlined,
                    'Dashboard',
                    _MainArea.dashboard,
                  ),
                if (isPartner && isPartnerOwner)
                  _MenuItem(
                    Icons.business_center_outlined,
                    'Minha empresa',
                    _MainArea.management,
                  ),
                if (isGuide)
                  _MenuItem(
                    Icons.local_parking_outlined,
                    'Estacionamentos',
                    _MainArea.map,
                  )
                else
                  _MenuItem(
                    isPartner
                        ? Icons.local_parking_outlined
                        : Icons.map_outlined,
                    isPartner ? 'Mapa de vagas' : 'Mapa',
                    _MainArea.map,
                  ),
                if (isPartner && !isGuide)
                  _MenuItem(
                    Icons.confirmation_number_outlined,
                    'Reservas recebidas',
                    _MainArea.reservations,
                  ),
                if (isPartner && isPartnerOwner && !isGuide)
                  _MenuItem(Icons.group_outlined, 'Usuarios', _MainArea.users),
                if (isPartner && isPartnerOwner)
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
                expanded: expanded,
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
              expanded: expanded,
              title: 'Conta',
              items: [
                _MenuItem(Icons.person_outline, 'Perfil', _MainArea.profile),
                if (!isPartner)
                  _MenuItem(
                    Icons.directions_car_outlined,
                    'Veículos',
                    _MainArea.vehicles,
                  ),
                if (!isPartner)
                  _MenuItem(
                    Icons.account_balance_wallet_outlined,
                    'Minha carteira',
                    _MainArea.wallet,
                  ),
                if (!isPartner)
                  _MenuItem(
                    Icons.confirmation_number_outlined,
                    'Reservas',
                    _MainArea.reservations,
                  ),
              ],
              selectedArea: selectedArea,
              onSelected: onSelected,
            ),
            if (!expanded)
              IconButton(
                tooltip: 'Sair',
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout),
              ),
            if (expanded)
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
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final bool isPartner;
  final bool isPartnerOwner;
  final bool isGuide;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _MobileDrawer({
    required this.isPartner,
    required this.isPartnerOwner,
    required this.isGuide,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('ParkHere', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (isPartner && (isPartnerOwner || isGuide))
              ListTile(
                leading: const Icon(Icons.business_center_outlined),
                title: const Text('Minha empresa'),
                onTap: () => onSelected(_MainArea.management),
              ),
            if (isPartner && !isGuide)
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: const Text('Reservas recebidas'),
                onTap: () => onSelected(_MainArea.reservations),
              ),
            if (isPartner && isPartnerOwner && !isGuide)
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Usuarios'),
                onTap: () => onSelected(_MainArea.users),
              ),
            if (isPartner && !isGuide)
              ListTile(
                leading: const Icon(Icons.local_parking_outlined),
                title: const Text('Mapa de vagas'),
                onTap: () => onSelected(_MainArea.map),
              ),
            if (isGuide)
              ListTile(
                leading: const Icon(Icons.local_parking_outlined),
                title: const Text('Estacionamentos'),
                onTap: () => onSelected(_MainArea.map),
              ),
            if (isPartner && isPartnerOwner && !isGuide)
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Financeiro Pro'),
                onTap: () => onSelected(_MainArea.financial),
              )
            else if (!isPartner) ...[
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
            ExpansionTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Perfil'),
              childrenPadding: const EdgeInsets.only(left: 12),
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Meus dados'),
                  onTap: () => onSelected(_MainArea.profile),
                ),
                if (!isPartner) ...[
                  ListTile(
                    leading: const Icon(Icons.directions_car_outlined),
                    title: const Text('Veículos'),
                    onTap: () => onSelected(_MainArea.vehicles),
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Minha carteira'),
                    onTap: () => onSelected(_MainArea.wallet),
                  ),
                  ListTile(
                    leading: const Icon(Icons.confirmation_number_outlined),
                    title: const Text('Reservas'),
                    onTap: () => onSelected(_MainArea.reservations),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCategory extends StatelessWidget {
  final bool expanded;
  final String title;
  final List<_MenuItem> items;
  final _MainArea selectedArea;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _MenuCategory({
    this.expanded = true,
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
          if (expanded)
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
            if (!expanded)
              IconButton(
                tooltip: item.label,
                isSelected: selectedArea == item.area,
                onPressed: () => onSelected(item.area, item.serviceTabIndex),
                icon: Icon(item.icon),
              )
            else
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
