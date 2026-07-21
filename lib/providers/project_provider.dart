import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../repositories/project_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

class ProjectListNotifier extends Notifier<List<Project>> {
  @override
  List<Project> build() {
    return ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> createProject(String name, String phone, String address) async {
    final newProject = Project(
      customerName: name,
      phone: phone,
      address: address,
    );
    await ref.read(projectRepositoryProvider).addProject(newProject);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> updateProjectLocation(
    String id,
    double lat,
    double lon,
    double tilt,
  ) async {
    final project = state.firstWhere((p) => p.id == id);
    project.latitude = lat;
    project.longitude = lon;
    project.suggestedTilt = tilt;
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> saveRoofEstimations(
    String id,
    double area,
    int panels,
    double kw,
    double gen,
    double savings, {
    Map<String, dynamic>? topology,
  }) async {
    final project = state.firstWhere((p) => p.id == id);
    project.estimatedAreaSqM = area;
    project.estimatedPanels = panels;
    project.estimatedSystemKw = kw;
    project.estimatedGenerationKwh = gen;
    project.estimatedSavings = savings;

    if (topology != null) {
      project.selectedTopologyName = topology['name'] as String?;
      project.parallelStrings = topology['parallelStrings'] as int?;
      project.panelsInSeries = topology['panelsInSeries'] as int?;
      project.stringVoc = topology['voc'] as double?;
      project.arrayImp = topology['imp'] as double?;
    }

    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> saveAlignment(String id, double azimuth) async {
    final project = state.firstWhere((p) => p.id == id);
    project.finalAzimuth = azimuth;
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  // FIX: Explicitly named addPhotoToProject to resolve the Site Photo Screen error
  Future<void> addPhotoToProject(String id, String path) async {
    final project = state.firstWhere((p) => p.id == id);
    project.photoPaths ??= [];
    project.photoPaths!.add(path);
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> saveChecklist(
    String projectId,
    String roofMat,
    String spacing,
    int amps,
    String inverter,
    String wire,
    String notes,
    String batteryType,
    double? batteryCapacity,
    double? batteryVoltage,
    double? inverterPowerKw,
    double? inverterVoltage,
  ) async {
    final project = state.firstWhere((p) => p.id == projectId);

    project.roofMaterial = roofMat;
    project.rafterSpacing = spacing;
    project.mainPanelAmps = amps;
    project.inverterType = inverter;
    project.wireGauge = wire;
    project.additionalNotes = notes;

    project.batteryType = batteryType;
    project.batteryCapacityKwh = batteryCapacity;
    project.batteryVoltage = batteryVoltage;
    project.inverterPowerKw = inverterPowerKw;
    project.inverterVoltage = inverterVoltage;

    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> saveShadingAnalysis(String id, double shadingLoss) async {
    final project = state.firstWhere((p) => p.id == id);
    project.shadingLossPercentage = shadingLoss;
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> removeProject(String id) async {
    await ref.read(projectRepositoryProvider).deleteProject(id);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }
}

final projectListProvider =
    NotifierProvider<ProjectListNotifier, List<Project>>(
      ProjectListNotifier.new,
    );
