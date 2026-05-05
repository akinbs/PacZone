import '../models/zone_models.dart';

abstract class ScanService {
  Future<ZoneAnalysisResult> analyze(LocationInput input);
}
