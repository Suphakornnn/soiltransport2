class Job2Model {
  final String? id;
  final dynamic date;
  final String? note;
  final String? code;
  final String? dropLocation;
  final String? plate;
  final double? pricePerTrip;
  final dynamic createdAt;
  final double? trips;
  final String? startTime;
  final double? fuelBaht;
  final double? incomeBaht;
  final String? endTime;
  final List<String>? drivers;
  final String? status;
  final dynamic updatedAt;

  Job2Model({
    this.id,
    this.date,
    this.note,
    this.code,
    this.dropLocation,
    this.plate,
    this.pricePerTrip,
    this.createdAt,
    this.trips,
    this.startTime,
    this.fuelBaht,
    this.incomeBaht,
    this.endTime,
    this.drivers,
    this.status,
    this.updatedAt,
  });

  factory Job2Model.fromJson(Map<String, dynamic> json) {
    return Job2Model(
      id: json['_id'] as String?,
      date: json['date'] as dynamic,
      note: json['note'] as String?,
      code: json['code'] as String?,
      dropLocation: json['dropLocation'] as String?,
      plate: json['plate'] as String?,
      pricePerTrip: json['pricePerTrip'] != null ? (json['pricePerTrip'] as num).toDouble() : null,
      createdAt: json['createdAt'] as dynamic,
      trips: json['trips'] != null ? (json['trips'] as num).toDouble() : null,
      startTime: json['startTime'] as String?,
      fuelBaht: json['fuelBaht'] != null ? (json['fuelBaht'] as num).toDouble() : null,
      incomeBaht: json['IncomeBaht'] != null ? (json['IncomeBaht'] as num).toDouble() : null,
      endTime: json['endTime'] as String?,
      drivers: json['drivers'] != null ? List<String>.from(json['drivers'] as List) : null,
      status: json['status'] as String?,
      updatedAt: json['updatedAt'] as dynamic,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (code != null) 'code': code,
      if (dropLocation != null) 'dropLocation': dropLocation,
      if (plate != null) 'plate': plate,
      if (pricePerTrip != null) 'pricePerTrip': pricePerTrip,
      if (createdAt != null) 'createdAt': createdAt,
      if (trips != null) 'trips': trips,
      if (startTime != null) 'startTime': startTime,
      if (fuelBaht != null) 'fuelBaht': fuelBaht,
      if (incomeBaht != null) 'IncomeBaht': incomeBaht,
      if (endTime != null) 'endTime': endTime,
      if (drivers != null) 'drivers': drivers,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}
