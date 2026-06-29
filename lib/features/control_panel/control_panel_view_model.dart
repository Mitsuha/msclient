import 'package:flutter/foundation.dart';

import 'package:desktop/features/control_panel/control_panel_models.dart';
import 'package:desktop/features/control_panel/control_panel_service.dart';

class ControlPanelViewModel extends ChangeNotifier {
  ControlPanelViewModel({required ControlPanelService service})
    : this._(service);

  ControlPanelViewModel._(this._service);

  final ControlPanelService _service;

  ControlPanelSnapshot? _snapshot;
  bool _isWorking = false;
  String? _errorMessage;

  ControlPanelSnapshot? get snapshot => _snapshot;
  bool get isWorking => _isWorking;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    await _run(() => _service.loadSnapshot());
  }

  Future<void> refresh() => load();

  Future<void> initialize() async {
    await _run(() async {
      await _service.initializeLocalProxyEnv();
      return _service.loadSnapshot();
    });
  }

  Future<void> terminateConflicts() async {
    final conflicts = _snapshot?.conflicts ?? const <ConflictProcess>[];
    if (conflicts.isEmpty) {
      return;
    }

    await _run(() async {
      await _service.terminateConflicts(conflicts);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return _service.loadSnapshot();
    });
  }

  Future<void> _run(Future<ControlPanelSnapshot> Function() action) async {
    _isWorking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _snapshot = await action();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isWorking = false;
      notifyListeners();
    }
  }
}
