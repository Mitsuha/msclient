import 'package:desktop/app/app_service.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppService.deriveEnvironment', () {
    EnvironmentStatus derive({
      bool hasConflicts = false,
      bool certificateInstalled = true,
      bool hasLocalError = false,
    }) {
      return AppService.deriveEnvironment(
        hasConflicts: hasConflicts,
        certificateInstalled: certificateInstalled,
        hasLocalError: hasLocalError,
      );
    }

    test('everything healthy → ready', () {
      expect(derive(), EnvironmentStatus.ready);
    });

    test('missing certificate → rootCertificateMissing', () {
      expect(
        derive(certificateInstalled: false),
        EnvironmentStatus.rootCertificateMissing,
      );
    });

    test('missing certificate beats local error', () {
      expect(
        derive(certificateInstalled: false, hasLocalError: true),
        EnvironmentStatus.rootCertificateMissing,
      );
    });

    test('local error → error', () {
      expect(derive(hasLocalError: true), EnvironmentStatus.error);
    });

    test('conflicts beat everything else', () {
      expect(
        derive(
          hasConflicts: true,
          certificateInstalled: false,
          hasLocalError: true,
        ),
        EnvironmentStatus.conflict,
      );
    });
  });
}
