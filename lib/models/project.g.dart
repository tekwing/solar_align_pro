// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjectAdapter extends TypeAdapter<Project> {
  @override
  final int typeId = 0;

  @override
  Project read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Project(
      id: fields[0] as String?,
      customerName: fields[1] as String,
      phone: fields[2] as String,
      address: fields[3] as String,
      latitude: fields[4] as double?,
      longitude: fields[5] as double?,
      suggestedTilt: fields[6] as double?,
      finalAzimuth: fields[7] as double?,
      createdAt: fields[8] as DateTime?,
      estimatedAreaSqM: fields[9] as double?,
      estimatedPanels: fields[10] as int?,
      estimatedSystemKw: fields[11] as double?,
      estimatedGenerationKwh: fields[12] as double?,
      estimatedSavings: fields[13] as double?,
      photoPaths: (fields[14] as List?)?.cast<String>(),
      roofMaterial: fields[15] as String?,
      rafterSpacing: fields[16] as String?,
      mainPanelAmps: fields[17] as int?,
      shadingLossPercentage: fields[18] as double?,
      selectedTopologyName: fields[19] as String?,
      parallelStrings: fields[20] as int?,
      panelsInSeries: fields[21] as int?,
      stringVoc: fields[22] as double?,
      arrayImp: fields[23] as double?,
      additionalNotes: fields[24] as String?,
      inverterType: fields[25] as String?,
      wireGauge: fields[26] as String?,
      batteryType: fields[27] as String?,
      batteryCapacityKwh: fields[28] as double?,
      batteryVoltage: fields[29] as double?,
      inverterPowerKw: fields[30] as double?,
      inverterVoltage: fields[31] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Project obj) {
    writer
      ..writeByte(32)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.customerName)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.suggestedTilt)
      ..writeByte(7)
      ..write(obj.finalAzimuth)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.estimatedAreaSqM)
      ..writeByte(10)
      ..write(obj.estimatedPanels)
      ..writeByte(11)
      ..write(obj.estimatedSystemKw)
      ..writeByte(12)
      ..write(obj.estimatedGenerationKwh)
      ..writeByte(13)
      ..write(obj.estimatedSavings)
      ..writeByte(14)
      ..write(obj.photoPaths)
      ..writeByte(15)
      ..write(obj.roofMaterial)
      ..writeByte(16)
      ..write(obj.rafterSpacing)
      ..writeByte(17)
      ..write(obj.mainPanelAmps)
      ..writeByte(18)
      ..write(obj.shadingLossPercentage)
      ..writeByte(19)
      ..write(obj.selectedTopologyName)
      ..writeByte(20)
      ..write(obj.parallelStrings)
      ..writeByte(21)
      ..write(obj.panelsInSeries)
      ..writeByte(22)
      ..write(obj.stringVoc)
      ..writeByte(23)
      ..write(obj.arrayImp)
      ..writeByte(24)
      ..write(obj.additionalNotes)
      ..writeByte(25)
      ..write(obj.inverterType)
      ..writeByte(26)
      ..write(obj.wireGauge)
      ..writeByte(27)
      ..write(obj.batteryType)
      ..writeByte(28)
      ..write(obj.batteryCapacityKwh)
      ..writeByte(29)
      ..write(obj.batteryVoltage)
      ..writeByte(30)
      ..write(obj.inverterPowerKw)
      ..writeByte(31)
      ..write(obj.inverterVoltage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
