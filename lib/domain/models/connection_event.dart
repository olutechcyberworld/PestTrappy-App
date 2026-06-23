import 'package:equatable/equatable.dart';

/// A single device connection state transition, sourced from
/// `pest_trap.connection_events`. Every online/offline transition produces
/// a new append row in this table (never an upsert), creating a full
/// session history that can be browsed in the connection history screen
/// (Flutter Architecture Section 10.10).
///
/// Distinct from `pest_trap.device_state`, which holds only the current
/// state, this table holds the complete time-ordered log of all transitions.
class ConnectionEvent extends Equatable {
  final String deviceId;

  /// Connection transition state. Valid values: `"online"`, `"offline"`.
  final String status;

  /// UTC timestamp of when this transition was recorded by the firmware,
  /// corresponding to the `occurred_at` timestamptz column.
  final DateTime occurredAt;

  const ConnectionEvent({
    required this.deviceId,
    required this.status,
    required this.occurredAt,
  });

  /// Deserialises a `pest_trap.connection_events` row as returned by the
  /// Supabase Flutter SDK.
  factory ConnectionEvent.fromMap(Map<String, dynamic> map) {
    return ConnectionEvent(
      deviceId: map['device_id'] as String,
      status: map['status'] as String,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
    );
  }

  bool get isOnline => status == 'online';

  @override
  List<Object?> get props => [deviceId, status, occurredAt];

  @override
  String toString() =>
      'ConnectionEvent(deviceId: $deviceId, status: $status, '
      'occurredAt: $occurredAt)';
}
