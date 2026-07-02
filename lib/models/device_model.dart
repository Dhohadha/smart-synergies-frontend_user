class DeviceModel {
  final String deviceId;
  final String? name;
  final double line1;
  final double line2;
  final double line3;
  final int workingAerators;
  final int totalAerators;
  final bool isCalibrated;
  final double fixedCurrentPerAerator;
  final DateTime? lastCalibratedAt;
  final List<RelayStatus> relays;
  final bool isActive;
  final DateTime? lastSeen;
  final DateTime? inactiveSince;

  DeviceModel({
    required this.deviceId,
    this.name,
    required this.line1,
    required this.line2,
    required this.line3,
    required this.workingAerators,
    required this.totalAerators,
    required this.isCalibrated,
    required this.fixedCurrentPerAerator,
    this.lastCalibratedAt,
    required this.relays,
    this.isActive = false,
    this.lastSeen,
    this.inactiveSince,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      deviceId: json['deviceID'] ?? '',
      name: json['name'],
      line1: (json['currentReadings']?['line1'] ?? 0).toDouble(),
      line2: (json['currentReadings']?['line2'] ?? 0).toDouble(),
      line3: (json['currentReadings']?['line3'] ?? 0).toDouble(),
      workingAerators: json['workingAerators'] ?? 0,
      totalAerators: json['totalAerators'] ?? 0,
      isCalibrated: json['isCalibrated'] ?? false,
      fixedCurrentPerAerator: (json['fixedCurrentPerAerator'] ?? 0).toDouble(),
      lastCalibratedAt: json['lastCalibratedAt'] != null 
          ? DateTime.parse(json['lastCalibratedAt']) 
          : null,
      relays: (json['relays'] as List<dynamic>?)
              ?.map((r) => RelayStatus.fromJson(r))
              .toList() ??
          [],
      isActive: json['isActive'] ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
      inactiveSince: json['inactiveSince'] != null ? DateTime.parse(json['inactiveSince']) : null,
    );
  }

  DeviceModel copyWith({List<RelayStatus>? relays, String? name}) {
    return DeviceModel(
      deviceId: deviceId,
      name: name ?? this.name,
      line1: line1,
      line2: line2,
      line3: line3,
      workingAerators: workingAerators,
      totalAerators: totalAerators,
      isCalibrated: isCalibrated,
      fixedCurrentPerAerator: fixedCurrentPerAerator,
      lastCalibratedAt: lastCalibratedAt,
      relays: relays ?? this.relays,
      isActive: isActive,
      lastSeen: lastSeen,
      inactiveSince: inactiveSince,
    );
  }
}

class RelayStatus {
  final String name;
  final bool status;

  RelayStatus({required this.name, required this.status});

  factory RelayStatus.fromJson(Map<String, dynamic> json) {
    return RelayStatus(
      name: json['name'] ?? '',
      status: json['status'] ?? false,
    );
  }
}

