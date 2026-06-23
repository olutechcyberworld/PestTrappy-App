/// Typed enumeration of every discrete event the ESP32 firmware publishes
/// to `pestTrapping/{deviceId}/events` and writes to `pest_trap.events`.
///
/// The five values below correspond exactly to the `eventType` strings defined
/// in the Phase 4 Backend Firmware Contract (Section 2.3, events payload).
/// [unknown] is a safe fallback that absorbs any future event type added to
/// the firmware without crashing existing app builds.
enum EventType {
  pestDetected,
  trapTriggered,
  killConfirmed,
  sensorError,
  sensorRecovered,
  unknown;

  /// Parses the raw string arriving from Supabase or the MQTT payload into a
  /// typed [EventType]. Unrecognised values map to [unknown] rather than
  /// throwing, so a firmware update that adds a sixth event type does not
  /// cause a crash in apps already deployed.
  static EventType fromString(String value) {
    switch (value) {
      case 'pestDetected':
        return EventType.pestDetected;
      case 'trapTriggered':
        return EventType.trapTriggered;
      case 'killConfirmed':
        return EventType.killConfirmed;
      case 'sensorError':
        return EventType.sensorError;
      case 'sensorRecovered':
        return EventType.sensorRecovered;
      default:
        return EventType.unknown;
    }
  }

  /// Returns the wire-format string as defined in the firmware contract.
  /// Used when constructing Supabase query filters against the `event_type`
  /// column.
  String toWireString() {
    switch (this) {
      case EventType.pestDetected:
        return 'pestDetected';
      case EventType.trapTriggered:
        return 'trapTriggered';
      case EventType.killConfirmed:
        return 'killConfirmed';
      case EventType.sensorError:
        return 'sensorError';
      case EventType.sensorRecovered:
        return 'sensorRecovered';
      case EventType.unknown:
        return 'unknown';
    }
  }

  /// Human-readable label for display in the event log UI.
  String get displayLabel {
    switch (this) {
      case EventType.pestDetected:
        return 'Pest Detected';
      case EventType.trapTriggered:
        return 'Trap Triggered';
      case EventType.killConfirmed:
        return 'Kill Confirmed';
      case EventType.sensorError:
        return 'Sensor Fault';
      case EventType.sensorRecovered:
        return 'Sensor Restored';
      case EventType.unknown:
        return 'Unknown Event';
    }
  }
}
