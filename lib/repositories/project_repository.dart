import 'package:hive_flutter/hive_flutter.dart';
import '../models/project.dart';

class ProjectRepository {
  // This must exactly match the box name we opened in main.dart
  final String _boxName = 'projectsBox';

  // Helper to get the open box
  Box<Project> get _box => Hive.box<Project>(_boxName);

  /// Retrieves all projects currently saved in the local database
  List<Project> getAllProjects() {
    // Hive stores items in chronological order, we can reverse it so newest is on top
    return _box.values.toList().reversed.toList();
  }

  /// Saves a completely new project to the database
  Future<void> addProject(Project project) async {
    // We use the project.id as the Hive key so we can easily find it later
    await _box.put(project.id, project);
  }

  /// Updates an existing project (e.g., adding GPS, Photos, or Checklists)
  Future<void> updateProject(Project project) async {
    // .put() overwrites the existing entry with the updated one
    await _box.put(project.id, project);
  }

  /// Permanently removes a project from the device
  Future<void> deleteProject(String id) async {
    await _box.delete(id);
  }
}
