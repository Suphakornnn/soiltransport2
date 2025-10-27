class Truck {
  final String plate;
  final String model;
  final String driver;
  final String status;
  final String location;
  final int mileage;
  final int fuel;
  final String nextService;

  Truck({
    required this.plate,
    required this.model,
    required this.driver,
    required this.status,
    required this.location,
    required this.mileage,
    required this.fuel,
    required this.nextService,
  });

  Map<String, dynamic> toMap() => {
    'plate': plate,
    'model': model,
    'driver': driver,
    'status': status,
    'location': location,
    'mileage': mileage,
    'fuel': fuel,
    'nextService': nextService,
  };
}
