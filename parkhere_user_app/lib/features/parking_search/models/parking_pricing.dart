class ParkingPricing {
  final double firstHourPrice;
  final double additionalHourPrice;

  final double dailyPrice;
  final double monthlyPrice;

  ParkingPricing({
    required this.firstHourPrice,
    required this.additionalHourPrice,
    required this.dailyPrice,
    required this.monthlyPrice,
  });

  factory ParkingPricing.fromJson(Map<String, dynamic> json) {
    return ParkingPricing(
      firstHourPrice: json["firstHourPrice"],
      additionalHourPrice: json["additionalHourPrice"],
      dailyPrice: json["dailyPrice"],
      monthlyPrice: json["monthlyPrice"],
    );
  }
}
