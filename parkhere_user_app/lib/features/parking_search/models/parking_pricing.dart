class ParkingPricing {
  final double firstHourPrice;
  final double additionalHourPrice;

  final double dailyPrice;
  final double monthlyPrice;
  final double weeklyPrice;
  final double coveredDailyPrice,
      uncoveredDailyPrice,
      coveredFirstHourPrice,
      uncoveredFirstHourPrice;

  ParkingPricing({
    required this.firstHourPrice,
    required this.additionalHourPrice,
    required this.dailyPrice,
    required this.monthlyPrice,
    this.weeklyPrice = 0,
    this.coveredDailyPrice = 0,
    this.uncoveredDailyPrice = 0,
    this.coveredFirstHourPrice = 0,
    this.uncoveredFirstHourPrice = 0,
  });

  factory ParkingPricing.fromJson(Map<String, dynamic> json) {
    return ParkingPricing(
      firstHourPrice: json["firstHourPrice"],
      additionalHourPrice: json["additionalHourPrice"],
      dailyPrice: json["dailyPrice"],
      monthlyPrice: json["monthlyPrice"],
      weeklyPrice: (json["weeklyPrice"] as num?)?.toDouble() ?? 0,
      coveredDailyPrice: (json["coveredDailyPrice"] as num?)?.toDouble() ?? 0,
      uncoveredDailyPrice:
          (json["uncoveredDailyPrice"] as num?)?.toDouble() ?? 0,
      coveredFirstHourPrice:
          (json["coveredFirstHourPrice"] as num?)?.toDouble() ?? 0,
      uncoveredFirstHourPrice:
          (json["uncoveredFirstHourPrice"] as num?)?.toDouble() ?? 0,
    );
  }
}
