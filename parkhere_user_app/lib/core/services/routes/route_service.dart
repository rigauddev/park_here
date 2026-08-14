class RouteService {
  /// Simula cálculo de rota
  /// Retorna tempo estimado em minutos
  Future<int> calculateRouteTime() async {
    await Future.delayed(const Duration(seconds: 1));

    // Mock: sempre retorna 18 minutos
    return 18;
  }
}
