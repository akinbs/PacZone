import 'scan_service.dart';
import 'zone_analyzer.dart';
import '../models/zone_models.dart';

class MockScanService implements ScanService {
  @override
  Future<ZoneAnalysisResult> analyze(LocationInput input) =>
      ZoneAnalyzer.analyze(input);
}
