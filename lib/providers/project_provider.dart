import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../repositories/project_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

final projectListProvider = NotifierProvider<ProjectNotifier, List<Project>>(
  () {
    return ProjectNotifier();
  },
);

class ProjectNotifier extends Notifier<List<Project>> {
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

  Future<void> removeProject(String id) async {
    await ref.read(projectRepositoryProvider).deleteProject(id);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> updateProjectLocation(
    String id,
    double lat,
    double lng,
    double tilt,
  ) async {
    final project = state.firstWhere((p) => p.id == id);
    project.latitude = lat;
    project.longitude = lng;
    project.suggestedTilt = tilt;
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> addPhotoToProject(String projectId, String imagePath) async {
    final project = state.firstWhere((p) => p.id == projectId);
    List<String> currentPhotos = project.photoPaths ?? [];
    currentPhotos.add(imagePath);
    project.photoPaths = currentPhotos;
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> saveRoofEstimations(
    String projectId,
    double area,
    int panels,
    double systemKw,
    double generationKwh,
    double savings, {
    Map<String, dynamic>? topology, // NEW: Accept topology data
  }) async {
    final project = state.firstWhere((p) => p.id == projectId);
    project.estimatedAreaSqM = area;
    project.estimatedPanels = panels;
    project.estimatedSystemKw = systemKw;
    project.estimatedGenerationKwh = generationKwh;
    project.estimatedSavings = savings;

    if (topology != null) {
      int parallel = topology['parallelStrings'] as int;
      int series = topology['panelsInSeries'] as int;

      String configurationType = "Custom Configuration";
      if (parallel == 1 && series > 1) {
        configurationType = "All Series Configuration";
      } else if (series == 1 && parallel > 1) {
        configurationType = "All Parallel Configuration";
      } else if (parallel > 1 && series > 1) {
        configurationType = "Series and Parallel Configuration";
      } else if (parallel == 1 && series == 1) {
        configurationType = "Single Panel Configuration";
      }

      project.selectedTopologyName = configurationType;
      project.parallelStrings = parallel;
      project.panelsInSeries = series;
      project.stringVoc = topology['voc'] as double;
      project.arrayImp = topology['imp'] as double;
    }

    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> saveAlignment(String projectId, double azimuth) async {
    final project = state.firstWhere((p) => p.id == projectId);
    project.finalAzimuth = azimuth;
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> saveChecklist(
    String projectId,
    String roofMat,
    String spacing,
    int amps,
  ) async {
    final project = state.firstWhere((p) => p.id == projectId);
    project.roofMaterial = roofMat;
    project.rafterSpacing = spacing;
    project.mainPanelAmps = amps;
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }

  Future<void> saveShadingAnalysis(
    String projectId,
    double lossPercentage,
  ) async {
    final project = state.firstWhere((p) => p.id == projectId);
    project.shadingLossPercentage = lossPercentage;
    await ref.read(projectRepositoryProvider).updateProject(project);
    state = ref.read(projectRepositoryProvider).getAllProjects();
  }
}
