import '../domain/dsp_profile.dart';

abstract class ProfileRepository {
  Future<DspProfile> load();
  Future<void> save(DspProfile profile);
}
