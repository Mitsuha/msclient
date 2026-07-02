import 'package:desktop/app/app_service.dart';
import 'package:desktop/app/models/app_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppService.deriveState', () {
    RuntimeState derive({
      bool hasConflicts = false,
      bool certificateInstalled = true,
      bool hasLocalError = false,
      bool isInitialized = true,
    }) {
      return AppService.deriveState(
        hasConflicts: hasConflicts,
        certificateInstalled: certificateInstalled,
        hasLocalError: hasLocalError,
        isInitialized: isInitialized,
      );
    }

    test('everything healthy → running', () {
      expect(derive(), RuntimeState.running);
    });

    test('not initialized → uninitialized', () {
      expect(derive(isInitialized: false), RuntimeState.uninitialized);
    });

    test('local error beats initialization state', () {
      expect(
        derive(hasLocalError: true, isInitialized: false),
        RuntimeState.error,
      );
    });

    test('missing certificate beats local error', () {
      expect(
        derive(certificateInstalled: false, hasLocalError: true),
        RuntimeState.rootCertificateMissing,
      );
    });

    test('conflicts beat everything else', () {
      expect(
        derive(
          hasConflicts: true,
          certificateInstalled: false,
          hasLocalError: true,
          isInitialized: false,
        ),
        RuntimeState.conflict,
      );
    });
  });
}
