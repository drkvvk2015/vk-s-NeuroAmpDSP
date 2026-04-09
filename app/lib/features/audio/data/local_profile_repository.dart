import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dsp_profile.dart';
import 'profile_repository.dart';

class LocalProfileRepository implements ProfileRepository {
  static const String _profileKey = 'dsp_profile_v1';

  @override
  Future<DspProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null || raw.isEmpty) {
      return DspProfile.defaultProfile();
    }
    return DspProfile.decode(raw);
  }

  @override
  Future<void> save(DspProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, profile.encode());
  }
}
