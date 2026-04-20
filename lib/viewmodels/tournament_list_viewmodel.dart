// ─────────────────────────────────────────────────────────────────────────────
// lib/viewmodels/tournament_list_viewmodel.dart  (UPDATED)
// Changes: Added login check — redirects to login page if not authenticated
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../core/constants/app_routes.dart';
import '../models/tournament_models.dart';
import '../repositories/tournament_repository.dart';

class TournamentListViewModel extends GetxController {
  final TournamentRepository _repo = TournamentRepository();

  final RxList<TournamentModel> tournaments = <TournamentModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoggedIn = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkLoginAndLoad();
  }

  Future<void> _checkLoginAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isLoggedIn.value = false;
      // Slight delay lets the page finish building before navigation
      Future.delayed(const Duration(milliseconds: 300), () {
        Get.snackbar(
          'Login Required',
          'Please login to view tournaments',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        Get.offNamed(AppRoutes.login);
      });
      return;
    }

    isLoggedIn.value = true;
    await loadTournaments();
  }

  Future<void> loadTournaments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    isLoading.value = true;
    try {
      tournaments.value = await _repo.getMyTournaments();
    } catch (e, stack) {
      print('🔥🔥🔥 LOAD TOURNAMENTS ERROR 🔥🔥🔥');
      print('Error: $e');
      print('Type: ${e.runtimeType}');
      print('Stack: $stack');
      Get.snackbar('Error', 'Failed to load tournaments: $e',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteTournament(String id) async {
    try {
      await _repo.deleteTournament(id);
      tournaments.removeWhere((t) => t.id == id);
      Get.snackbar('Deleted', 'Tournament removed',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Delete failed: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}