import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/acknowledgement_store.dart';

/// Where the adult-content acknowledgement stands.
enum AgeGatePhase {
  /// Reading the stored record. The splash holds here.
  checking,

  /// No current acknowledgement — show the gate.
  required,

  /// Acknowledged; the app is usable.
  accepted,

  /// They said they are under 18. Dead end.
  declined,
}

final acknowledgementStoreProvider = Provider<AcknowledgementStore>(
  (ref) => AcknowledgementStore(),
);

class AgeGateController extends StateNotifier<AgeGatePhase> {
  AgeGateController(this._store) : super(AgeGatePhase.checking);

  final AcknowledgementStore _store;

  /// Reads the stored acknowledgement. Called once at launch.
  Future<void> restore() async {
    final acknowledged = await _store.isAcknowledged();
    if (!mounted) return;
    state = acknowledged ? AgeGatePhase.accepted : AgeGatePhase.required;
  }

  Future<void> accept() async {
    await _store.acknowledge();
    if (!mounted) return;
    state = AgeGatePhase.accepted;
  }

  /// Clears any stored record as well as moving to the dead end, so a device
  /// that previously acknowledged does not stay acknowledged after someone
  /// tells us they are underage.
  Future<void> decline() async {
    await _store.clear();
    if (!mounted) return;
    state = AgeGatePhase.declined;
  }

  @visibleForTesting
  void setPhase(AgeGatePhase phase) => state = phase;
}

final ageGateControllerProvider =
    StateNotifierProvider<AgeGateController, AgeGatePhase>(
      (ref) => AgeGateController(ref.watch(acknowledgementStoreProvider)),
    );
