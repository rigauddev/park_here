import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/pages/vehicles_page.dart';
import '../../features/account/pages/wallet_page.dart';
import '../../features/help/pages/help_center_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/profile_page.dart';
import '../../features/parking_search/pages/home_map_page.dart';
import '../../features/parking_search/models/parking_model.dart';
import '../../features/parking_search/providers/parking_provider.dart';
import '../../features/partner_management/pages/partner_financial_page.dart';
import '../../features/partner_management/pages/partner_management_home_page.dart';
import '../../features/partner_management/pages/partner_parking_map_page.dart';
import '../../features/partner_management/pages/partner_reservations_page.dart';
import '../../features/partner_management/pages/partner_users_page.dart';
import '../../features/reservation/pages/reservation_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../i18n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../../features/partner_management/pages/parking_dashboard_page.dart';
import '../../features/partner_management/pages/guide_affiliations_page.dart';
import '../../features/partner_management/pages/guide_dashboard_page.dart';
import '../../features/partner_management/pages/guide_services_page.dart';
import '../../features/partner_management/pages/admin_management_page.dart';
import '../../features/partner_management/pages/partner_shifts_page.dart';
import '../../features/partner_management/providers/partner_operators_provider.dart';
import '../../features/partner_management/pages/convenience_pos_page.dart';
import '../../features/partner_management/pages/parking_convenience_page.dart';
import '../../features/partner_management/providers/partner_parking_provider.dart';
import '../../features/partner_management/providers/partner_profile_provider.dart';
import '../../features/partner_management/models/partner_profile_model.dart';
import '../../features/partner_management/pages/partner_feature_access_page.dart';

enum _MainArea {
  menu,
  map,
  services,
  reservations,
  vehicles,
  wallet,
  management,
  users,
  shifts,
  financial,
  dashboard,
  profile,
  help,
  conveniencePos,
  convenienceProducts,
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  late _MainArea _selectedArea;
  int _servicesInitialIndex = 0;
  int _adminSection = 0;
  bool _menuExpanded = true;
  DateTime? _lastBackPress;
  bool _operatorHasShiftToday = false;

  Future<bool> _handleBack() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pressione voltar novamente para sair.')),
      );
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _selectedArea = _initialArea();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadOperatorShiftAccess(),
    );
  }

  Future<void> _loadOperatorShiftAccess() async {
    if (!ref.read(authProvider).isOperator) return;
    try {
      final shifts = await ref
          .read(partnerOperatorsProvider.notifier)
          .fetchShifts();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final tomorrowStart = todayStart.add(const Duration(days: 1));
      final hasShiftToday = shifts.any((shift) {
        final starts = DateTime.parse(shift['starts_at'] as String).toLocal();
        final ends = DateTime.parse(shift['ends_at'] as String).toLocal();
        // A scheduled operator can use the operational menu for their whole
        // workday, even before the shift starts. The backend still enforces
        // authorization for each operation and unit.
        return starts.isBefore(tomorrowStart) && ends.isAfter(todayStart);
      });
      if (!mounted) return;
      setState(() {
        _operatorHasShiftToday = hasShiftToday;
        if (!hasShiftToday && !_isOperatorAllowedArea(_selectedArea)) {
          _selectedArea = _MainArea.shifts;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _operatorHasShiftToday = false;
        if (!_isOperatorAllowedArea(_selectedArea)) {
          _selectedArea = _MainArea.shifts;
        }
      });
    }
  }

  bool _isOperatorAllowedArea(_MainArea area) =>
      area == _MainArea.shifts ||
      area == _MainArea.profile ||
      area == _MainArea.wallet ||
      area == _MainArea.help;

  @override
  Widget build(BuildContext context) {
    final isWebLayout = MediaQuery.sizeOf(context).width >= 900;
    final auth = ref.watch(authProvider);
    final isPartner = auth.isPartnerSession;
    final isPartnerOwner = auth.isPartnerOwner;
    final isGuide = auth.isTourGuide;
    final isOperator = auth.isOperator;
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
      key: ValueKey(
        '${_selectedArea.name}:$_servicesInitialIndex:$_adminSection',
      ),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => _pageFor(
          _selectedArea,
          isPartner,
          isPartnerOwner,
          isGuide,
          isAdmin,
          isOperator,
          _operatorHasShiftToday,
          _adminSection,
        ),
      ),
    );
    final topBar = AppBar(
      title: const Text('ParkHere'),
      automaticallyImplyLeading: false,
      actions: isOperator
          ? [
              IconButton(
                tooltip: 'Atualizar acesso do turno',
                onPressed: _loadOperatorShiftAccess,
                icon: const Icon(Icons.sync),
              ),
            ]
          : const [],
      leading: isWebLayout
          ? IconButton(
              tooltip: _menuExpanded ? 'Ocultar menu' : 'Mostrar menu',
              icon: Icon(_menuExpanded ? Icons.menu_open : Icons.menu),
              onPressed: () => setState(() => _menuExpanded = !_menuExpanded),
            )
          : Builder(
              builder: (context) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
    );

    if (isWebLayout) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) async {
          if (await _handleBack()) SystemNavigator.pop();
        },
        child: Scaffold(
          appBar: topBar,
          body: Row(
            children: [
              _WebMenu(
                expanded: _menuExpanded,
                selectedArea: _selectedArea,
                isPartner: isPartner,
                isPartnerOwner: isPartnerOwner,
                isGuide: isGuide,
                isAdmin: isAdmin,
                isOperator: isOperator,
                operatorHasShiftToday: _operatorHasShiftToday,
                onSelected: _selectArea,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) async {
        if (await _handleBack()) SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: topBar,
        drawer: _MobileDrawer(
          isPartner: isPartner,
          isPartnerOwner: isPartnerOwner,
          isGuide: isGuide,
          isAdmin: isAdmin,
          isOperator: isOperator,
          operatorHasShiftToday: _operatorHasShiftToday,
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
                isAdmin: isAdmin,
                isOperator: isOperator,
                operatorHasShiftToday: _operatorHasShiftToday,
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
            isAdmin,
            isOperator,
            _operatorHasShiftToday,
          ),
          onDestinationSelected: (index) {
            setState(() {
              if (isAdmin) _adminSection = index;
              _selectedArea = _areaForMobileIndex(
                index,
                isPartner,
                isPartnerOwner,
                isGuide,
                isAdmin,
                isOperator,
                _operatorHasShiftToday,
              );
            });
          },
          destinations: [
            if (isAdmin) ...[
              const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Visão geral',
              ),
              const NavigationDestination(
                icon: Icon(Icons.business_outlined),
                label: 'Parceiros',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                label: 'Clientes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.approval_outlined),
                label: 'Aprovações',
              ),
              const NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                label: 'Taxas',
              ),
              const NavigationDestination(
                icon: Icon(Icons.extension_outlined),
                label: 'Módulos',
              ),
            ],
            if (!isAdmin && isOperator && !_operatorHasShiftToday) ...[
              const NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Escala',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
              const NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Repasse',
              ),
            ],
            if (!isAdmin && isPartner && (isPartnerOwner || isGuide))
              const NavigationDestination(
                icon: Icon(Icons.business_center_outlined),
                selectedIcon: Icon(Icons.business_center),
                label: 'Gestão',
              ),
            if (!isAdmin &&
                isPartner &&
                (!isOperator || _operatorHasShiftToday))
              NavigationDestination(
                icon: const Icon(Icons.local_parking_outlined),
                selectedIcon: const Icon(Icons.local_parking),
                label: isGuide ? 'Estacionamentos' : 'Vagas',
              )
            else if (!isAdmin && !isPartner)
              const NavigationDestination(
                icon: Icon(Icons.widgets_outlined),
                selectedIcon: Icon(Icons.widgets),
                label: 'Serviços',
              ),
            if (!isAdmin &&
                isPartner &&
                !isGuide &&
                (!isOperator || _operatorHasShiftToday))
              const NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number),
                label: 'Reservas',
              ),
            if (!isAdmin && !isPartner)
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Mapa',
              ),
            if (!isAdmin && !isPartner)
              const NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number),
                label: 'Reservas',
              ),
            if (!isAdmin && (!isPartner || isGuide))
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            if (!isAdmin && isPartner && isPartnerOwner && !isGuide)
              const NavigationDestination(
                icon: Icon(Icons.lock_outline),
                selectedIcon: Icon(Icons.lock),
                label: 'Financeiro',
              ),
            if (!isAdmin &&
                isPartner &&
                !isGuide &&
                (!isOperator || _operatorHasShiftToday))
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
          ],
        ),
      ),
    );
  }

  Widget _pageFor(
    _MainArea area,
    bool isPartner,
    bool isPartnerOwner,
    bool isGuide,
    bool isAdmin,
    bool isOperator,
    bool operatorHasShiftToday,
    int adminSection,
  ) {
    if (area == _MainArea.help) return const HelpCenterPage();
    if (isAdmin) return AdminManagementPage(initialSection: adminSection);
    if (isOperator && !operatorHasShiftToday && !_isOperatorAllowedArea(area)) {
      return const PartnerShiftsPage();
    }
    switch (area) {
      case _MainArea.menu:
        return const _MenuHubPage();
      case _MainArea.map:
        if (isGuide) return const GuideAffiliationsPage();
        if (isPartner) return const PartnerParkingMapPage();
        return const HomeMapPage();
      case _MainArea.services:
        if (isGuide) return const GuideServicesPage();
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
        return const WalletPage();
      case _MainArea.management:
        if (isGuide) return const GuideDashboardPage();
        return isPartnerOwner
            ? const PartnerManagementHomePage()
            : const PartnerParkingMapPage();
      case _MainArea.users:
        return isPartnerOwner ? const PartnerUsersPage() : const ProfilePage();
      case _MainArea.shifts:
        return isPartner ? const PartnerShiftsPage() : const ProfilePage();
      case _MainArea.dashboard:
        if (isGuide) return const GuideDashboardPage();
        return isPartnerOwner
            ? const ParkingDashboardPage()
            : const PartnerParkingMapPage();
      case _MainArea.financial:
        return isPartnerOwner
            ? const PartnerFinancialPage()
            : const PartnerParkingMapPage();
      case _MainArea.profile:
        return const ProfilePage();
      case _MainArea.help:
        return const HelpCenterPage();
      case _MainArea.conveniencePos:
        return const _ConvenienceEntryPage(pos: true);
      case _MainArea.convenienceProducts:
        return const _ConvenienceEntryPage(pos: false);
    }
  }

  int _mobileIndexFor(
    _MainArea area,
    bool isPartner,
    bool isPartnerOwner,
    bool isGuide,
    bool isAdmin,
    bool isOperator,
    bool operatorHasShiftToday,
  ) {
    if (isAdmin) return _adminSection.clamp(0, 5);
    if (isGuide) return area == _MainArea.map ? 1 : 0;
    if (isOperator && !operatorHasShiftToday) {
      switch (area) {
        case _MainArea.shifts:
          return 0;
        case _MainArea.profile:
          return 1;
        case _MainArea.wallet:
          return 2;
        case _MainArea.help:
          return 1;
        default:
          return 0;
      }
    }
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
        case _MainArea.help:
          return 2;
        default:
          return 0;
      }
    }

    switch (area) {
      case _MainArea.menu:
        return isPartner ? 0 : 0;
      case _MainArea.map:
        return isPartner ? 1 : 1;
      case _MainArea.services:
        return isPartner ? 1 : 0;
      case _MainArea.vehicles:
      case _MainArea.wallet:
        return isPartner ? 4 : 3;
      case _MainArea.management:
        return isPartner ? 0 : 3;
      case _MainArea.users:
      case _MainArea.shifts:
        return isPartner ? 0 : 3;
      case _MainArea.financial:
        return isPartner ? 3 : 3;
      case _MainArea.dashboard:
        return isPartner ? 0 : 3;
      case _MainArea.profile:
        return isPartner ? 4 : 3;
      case _MainArea.help:
        return isPartner ? 4 : 3;
      case _MainArea.reservations:
        return isPartner ? 2 : 2;
      case _MainArea.conveniencePos:
      case _MainArea.convenienceProducts:
        return isPartner ? 0 : 0;
    }
  }

  _MainArea _areaForMobileIndex(
    int index,
    bool isPartner,
    bool isPartnerOwner,
    bool isGuide,
    bool isAdmin,
    bool isOperator,
    bool operatorHasShiftToday,
  ) {
    if (isAdmin) return _MainArea.management;
    if (isGuide) {
      if (index == 1) return _MainArea.map;
      if (index == 2) return _MainArea.profile;
      return _MainArea.management;
    }
    if (isOperator && !operatorHasShiftToday) {
      switch (index) {
        case 0:
          return _MainArea.shifts;
        case 1:
          return _MainArea.profile;
        case 2:
          return _MainArea.wallet;
        default:
          return _MainArea.shifts;
      }
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
        return isPartner ? _MainArea.management : _MainArea.services;
      case 1:
        return isPartner ? _MainArea.map : _MainArea.map;
      case 2:
        return isPartner ? _MainArea.reservations : _MainArea.reservations;
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
      if (ref.read(authProvider).role == 'super_admin' &&
          serviceTabIndex != null) {
        _adminSection = serviceTabIndex.clamp(0, 5);
      }
      if (serviceTabIndex != null) {
        _servicesInitialIndex = serviceTabIndex;
      }
    });
  }

  _MainArea _initialArea() {
    final auth = ref.read(authProvider);
    if (auth.role == 'super_admin') return _MainArea.management;
    if (!auth.isPartnerSession) return _MainArea.map;
    if (auth.isOperator) return _MainArea.shifts;
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
  final bool isAdmin;
  final bool isOperator;
  final bool operatorHasShiftToday;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _WebMenu({
    this.expanded = true,
    required this.selectedArea,
    required this.isPartner,
    required this.isPartnerOwner,
    required this.isGuide,
    required this.isAdmin,
    required this.isOperator,
    required this.operatorHasShiftToday,
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
            if (isAdmin)
              _MenuCategory(
                expanded: expanded,
                title: 'Gestão do sistema',
                items: const [
                  _MenuItem(
                    Icons.dashboard_outlined,
                    'Visão geral',
                    _MainArea.management,
                    serviceTabIndex: 0,
                  ),
                  _MenuItem(
                    Icons.approval_outlined,
                    'Aprovações',
                    _MainArea.management,
                    serviceTabIndex: 1,
                  ),
                  _MenuItem(
                    Icons.payments_outlined,
                    'Taxas e planos',
                    _MainArea.management,
                    serviceTabIndex: 2,
                  ),
                  _MenuItem(
                    Icons.extension_outlined,
                    'Funcionalidades',
                    _MainArea.management,
                    serviceTabIndex: 3,
                  ),
                  _MenuItem(
                    Icons.business_outlined,
                    'Parceiros',
                    _MainArea.management,
                    serviceTabIndex: 4,
                  ),
                  _MenuItem(
                    Icons.people_outline,
                    'Clientes',
                    _MainArea.management,
                    serviceTabIndex: 5,
                  ),
                ],
                selectedArea: selectedArea,
                onSelected: onSelected,
              ),
            if (isAdmin) const Divider(height: 24),
            if (expanded)
              Text('ParkHere', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            if (!isAdmin && isPartner && !isGuide)
              _MenuCategory(
                expanded: expanded,
                title: 'Gestão',
                items: [
                  if (isPartner && isPartnerOwner)
                    _MenuItem(
                      Icons.business_center_outlined,
                      'Minha empresa',
                      _MainArea.management,
                    ),
                  if (isPartner && !isGuide)
                    _MenuItem(
                      Icons.schedule_outlined,
                      'Escalas',
                      _MainArea.shifts,
                    ),
                  if (isPartner && isPartnerOwner && !isGuide)
                    _MenuItem(
                      Icons.group_outlined,
                      'Usuarios',
                      _MainArea.users,
                    ),
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
            if (!isAdmin && isPartner && !isGuide)
              _MenuCategory(
                expanded: expanded,
                title: 'Operacional',
                items: [
                  if (!isOperator || operatorHasShiftToday)
                    _MenuItem(
                      Icons.local_parking_outlined,
                      'Mapa de vagas',
                      _MainArea.map,
                    ),
                  if (!isOperator || operatorHasShiftToday)
                    _MenuItem(
                      Icons.confirmation_number_outlined,
                      'Reservas',
                      _MainArea.reservations,
                    ),
                ],
                selectedArea: selectedArea,
                onSelected: onSelected,
              ),
            if (!isAdmin &&
                isPartner &&
                !isGuide &&
                (isPartnerOwner || (isOperator && operatorHasShiftToday)))
              _MenuCategory(
                expanded: expanded,
                title: 'Conveniência',
                items: [
                  _MenuItem(
                    Icons.point_of_sale_outlined,
                    'Ponto de venda',
                    _MainArea.conveniencePos,
                  ),
                  if (isPartnerOwner)
                    _MenuItem(
                      Icons.inventory_2_outlined,
                      'Produtos',
                      _MainArea.convenienceProducts,
                    ),
                ],
                selectedArea: selectedArea,
                onSelected: onSelected,
              ),
            if (!isAdmin && !isPartner)
              _MenuCategory(
                expanded: expanded,
                title: 'Navegação',
                items: [
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
            if (!isAdmin && isPartner && isGuide)
              _MenuCategory(
                expanded: expanded,
                title: 'Navegação',
                items: [
                  _MenuItem(
                    Icons.local_parking_outlined,
                    'Estacionamentos',
                    _MainArea.map,
                  ),
                  _MenuItem(
                    Icons.tour_outlined,
                    'Meus serviços',
                    _MainArea.services,
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
            if (!isAdmin)
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
                  _MenuItem(
                    Icons.account_balance_wallet_outlined,
                    isPartner ? 'Conta de repasse' : 'Minha carteira',
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
            _MenuCategory(
              expanded: expanded,
              title: context.strings.isEnglish ? 'Support' : 'Ajuda',
              items: [
                _MenuItem(
                  Icons.help_outline,
                  context.strings.isEnglish
                      ? 'Help center'
                      : 'Central de ajuda',
                  _MainArea.help,
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
  final bool isAdmin;
  final bool isOperator;
  final bool operatorHasShiftToday;
  final void Function(_MainArea area, [int? serviceTabIndex]) onSelected;

  const _MobileDrawer({
    required this.isPartner,
    required this.isPartnerOwner,
    required this.isGuide,
    required this.isAdmin,
    required this.isOperator,
    required this.operatorHasShiftToday,
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
            if (isAdmin) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Visão geral'),
                onTap: () => onSelected(_MainArea.management, 0),
              ),
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('Parceiros'),
                onTap: () => onSelected(_MainArea.management, 4),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Clientes'),
                onTap: () => onSelected(_MainArea.management, 5),
              ),
              ListTile(
                leading: const Icon(Icons.approval_outlined),
                title: const Text('Aprovações'),
                onTap: () => onSelected(_MainArea.management, 1),
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Taxas e planos'),
                onTap: () => onSelected(_MainArea.management, 2),
              ),
              ListTile(
                leading: const Icon(Icons.extension_outlined),
                title: const Text('Funcionalidades'),
                onTap: () => onSelected(_MainArea.management, 3),
              ),
            ] else ...[
              if (isPartner && !isGuide) ...[
                _MobileMenuGroup(
                  title: 'Gestão',
                  icon: Icons.business_center_outlined,
                  children: [
                    if (isPartnerOwner)
                      _MobileMenuItem(
                        icon: Icons.business_center_outlined,
                        title: 'Minha empresa',
                        onTap: () => onSelected(_MainArea.management),
                      ),
                    if (isPartnerOwner)
                      _MobileMenuItem(
                        icon: Icons.group_outlined,
                        title: 'Usuários',
                        onTap: () => onSelected(_MainArea.users),
                      ),
                    if (isPartnerOwner)
                      _MobileMenuItem(
                        icon: Icons.lock_outline,
                        title: 'Financeiro',
                        onTap: () => onSelected(_MainArea.financial),
                      ),
                    _MobileMenuItem(
                      icon: Icons.calendar_month_outlined,
                      title: 'Escala',
                      onTap: () => onSelected(_MainArea.shifts),
                    ),
                  ],
                ),
                _MobileMenuGroup(
                  title: 'Operacional',
                  icon: Icons.local_parking_outlined,
                  children: [
                    if (!isOperator || operatorHasShiftToday)
                      _MobileMenuItem(
                        icon: Icons.local_parking_outlined,
                        title: 'Mapa de vagas',
                        onTap: () => onSelected(_MainArea.map),
                      ),
                    if (!isOperator || operatorHasShiftToday)
                      _MobileMenuItem(
                        icon: Icons.confirmation_number_outlined,
                        title: 'Reservas',
                        onTap: () => onSelected(_MainArea.reservations),
                      ),
                  ],
                ),
                if (isPartnerOwner || (isOperator && operatorHasShiftToday))
                  _MobileMenuGroup(
                    title: 'Conveniência',
                    icon: Icons.storefront_outlined,
                    children: [
                      _MobileMenuItem(
                        icon: Icons.point_of_sale_outlined,
                        title: 'Ponto de venda',
                        onTap: () => onSelected(_MainArea.conveniencePos),
                      ),
                      if (isPartnerOwner)
                        _MobileMenuItem(
                          icon: Icons.inventory_2_outlined,
                          title: 'Produtos',
                          onTap: () =>
                              onSelected(_MainArea.convenienceProducts),
                        ),
                    ],
                  ),
              ] else if (isGuide) ...[
                ListTile(
                  leading: const Icon(Icons.local_parking_outlined),
                  title: const Text('Estacionamentos'),
                  onTap: () => onSelected(_MainArea.map),
                ),
                ListTile(
                  leading: const Icon(Icons.tour_outlined),
                  title: const Text('Meus serviços'),
                  onTap: () => onSelected(_MainArea.services),
                ),
              ] else ...[
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
                      leading: const Icon(Icons.confirmation_number_outlined),
                      title: const Text('Reservas'),
                      onTap: () => onSelected(_MainArea.reservations),
                    ),
                  ],
                  if (isPartner)
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: const Text('Conta de repasse'),
                      onTap: () => onSelected(_MainArea.wallet),
                    ),
                ],
              ),
            ],
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(
                context.strings.isEnglish ? 'Help center' : 'Central de ajuda',
              ),
              onTap: () => onSelected(_MainArea.help),
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

class _MobileMenuGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_MobileMenuItem> children;

  const _MobileMenuGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      leading: Icon(icon),
      title: Text(title),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: children,
    );
  }
}

class _MobileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MobileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 21),
      title: Text(title),
      onTap: onTap,
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
        children: [
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
          _MenuActionCard(
            icon: Icons.help_outline,
            title: context.strings.isEnglish
                ? 'Help center'
                : 'Central de ajuda',
            subtitle: context.strings.isEnglish
                ? 'Answers and guidance for using the app'
                : 'Respostas e orientações para usar o app',
            page: const HelpCenterPage(),
          ),
        ],
      ),
    );
  }
}

class _ConvenienceEntryPage extends ConsumerWidget {
  final bool pos;

  const _ConvenienceEntryPage({required this.pos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkings = ref.watch(partnerParkingProvider);
    final partner = ref.watch(partnerProfileProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: Text(pos ? 'Ponto de venda' : 'Produtos')),
      body: parkings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            partner != null && !partner.hasFeature('convenience_management')
            ? _lockedModule(context, partner)
            : Center(
                child: Text('Não foi possível carregar as unidades: $error'),
              ),
        data: (items) {
          if (partner != null &&
              !partner.hasFeature('convenience_management')) {
            return _lockedModule(context, partner);
          }
          final active = items.where((item) => item.id != null).toList();
          if (active.isEmpty) {
            return const Center(
              child: Text(
                'Cadastre uma unidade antes de acessar a conveniência.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final parking = active[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    pos
                        ? Icons.point_of_sale_outlined
                        : Icons.inventory_2_outlined,
                  ),
                  title: Text(parking.name),
                  subtitle: Text(parking.address),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final id = parking.id!;
                    final page = pos
                        ? ConveniencePosPage(
                            parkingId: id,
                            parkingName: parking.name,
                          )
                        : ParkingConveniencePage(
                            parkingId: id,
                            parkingName: parking.name,
                          );
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => page),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _lockedModule(BuildContext context, PartnerProfileModel partner) {
    final details = partner.featureDetails('convenience_management') ?? {};
    final price = (details['price'] as num?)?.toDouble() ?? 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  'Módulo de conveniência',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Venda produtos, controle estoque e gere comprovantes operacionais no caixa.',
                ),
                const SizedBox(height: 12),
                Text(
                  price > 0
                      ? 'A partir de R\$ ${price.toStringAsFixed(2)} por mês'
                      : 'Valor definido pela gestão do sistema.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PartnerFeatureAccessPage(
                        partner: partner,
                        featureKey: 'convenience_management',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Adicionar ao plano'),
                ),
              ],
            ),
          ),
        ),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HomeMapPage(initialParkingId: parking.id),
          ),
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
