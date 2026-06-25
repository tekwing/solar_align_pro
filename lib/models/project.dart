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
  DateTime createdAt;

  @HiveField(9)
  List<String>? photoPaths;

  @HiveField(10)
  double? estimatedAreaSqM;

  @HiveField(11)
  int? estimatedPanels;

  @HiveField(12)
  double? estimatedSystemKw;

  @HiveField(13)
  double? estimatedGenerationKwh;

  @HiveField(14)
  double? estimatedSavings;

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

  Project({
    String? id,
    required this.customerName,
    required this.phone,
    required this.address,
    this.latitude,
    this.longitude,
    this.suggestedTilt,
    this.finalAzimuth,
    this.photoPaths,
    this.estimatedAreaSqM,
    this.estimatedPanels,
    this.estimatedSystemKw,
    this.estimatedGenerationKwh,
    this.estimatedSavings,
    this.roofMaterial,
    this.rafterSpacing,
    this.mainPanelAmps,
    this.shadingLossPercentage,
    this.selectedTopologyName,
    this.parallelStrings,
    this.panelsInSeries,
    this.stringVoc,
    this.arrayImp,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();
}
