import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'project.g.dart';

@HiveType(typeId: 0)
class Project {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String customerName;

  @HiveField(2)
  String phone;

  @HiveField(3)
  String address;

  @HiveField(4)
  double? latitude;

  @HiveField(5)
  double? longitude;

  @HiveField(6)
  double? suggestedTilt;

  @HiveField(7)
  double? finalAzimuth;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  double? estimatedAreaSqM;

  @HiveField(10)
  int? estimatedPanels;

  @HiveField(11)
  double? estimatedSystemKw;

  @HiveField(12)
  double? estimatedGenerationKwh;

  @HiveField(13)
  double? estimatedSavings;

  @HiveField(14)
  List<String>? photoPaths;

  @HiveField(15)
  String? roofMaterial;

  @HiveField(16)
  String? rafterSpacing;

  @HiveField(17)
  int? mainPanelAmps;

  @HiveField(18)
  double? shadingLossPercentage;

  @HiveField(19)
  String? selectedTopologyName;

  @HiveField(20)
  int? parallelStrings;

  @HiveField(21)
  int? panelsInSeries;

  @HiveField(22)
  double? stringVoc;

  @HiveField(23)
  double? arrayImp;

  @HiveField(24)
  String? additionalNotes;

  @HiveField(25)
  String? inverterType;

  @HiveField(26)
  String? wireGauge;

  @HiveField(27)
  String? batteryType;

  @HiveField(28)
  double? batteryCapacityKwh;

  @HiveField(29)
  double? batteryVoltage;

  @HiveField(30)
  double? inverterPowerKw;

  @HiveField(31)
  double? inverterVoltage;

  Project({
    String? id,
    required this.customerName,
    required this.phone,
    required this.address,
    this.latitude,
    this.longitude,
    this.suggestedTilt,
    this.finalAzimuth,
    DateTime? createdAt,
    this.estimatedAreaSqM,
    this.estimatedPanels,
    this.estimatedSystemKw,
    this.estimatedGenerationKwh,
    this.estimatedSavings,
    this.photoPaths,
    this.roofMaterial,
    this.rafterSpacing,
    this.mainPanelAmps,
    this.shadingLossPercentage,
    this.selectedTopologyName,
    this.parallelStrings,
    this.panelsInSeries,
    this.stringVoc,
    this.arrayImp,
    this.additionalNotes,
    this.inverterType,
    this.wireGauge,
    this.batteryType,
    this.batteryCapacityKwh,
    this.batteryVoltage,
    this.inverterPowerKw,
    this.inverterVoltage,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();
}
