import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../data/device_client.dart';
import '../data/device_monitor.dart';
import '../data/models.dart';
import 'common.dart';
import 'home_page.dart';

class PetDataPanel extends StatefulWidget {
  const PetDataPanel({super.key, required this.pet, this.createDeviceClient});
  final Pet pet;
  final DeviceClient Function()? createDeviceClient;

  @override
  State<PetDataPanel> createState() => _PetDataPanelState();
}

class _PetDataPanelState extends State<PetDataPanel>
    with WidgetsBindingObserver {
  final address = TextEditingController(text: 'http://192.168.4.1');
  late final monitor = DeviceMonitor(createClient: widget.createDeviceClient);
  bool hardware = false;
  bool foreground = true, visible = true;
  ValueListenable<TickerModeData>? _visibility;
  String? addressError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = TickerMode.getValuesNotifier(context);
    if (identical(notifier, _visibility)) return;
    _visibility?.removeListener(_visibilityChanged);
    _visibility = notifier..addListener(_visibilityChanged);
    _visibilityChanged();
  }

  void _visibilityChanged() {
    final next = _visibility!.value.enabled;
    if (visible != next) {
      visible = next;
      _syncConnection();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = state == AppLifecycleState.resumed;
    if (foreground == next) return;
    foreground = next;
    _syncConnection();
  }

  void _syncConnection() {
    if (hardware && foreground && visible) {
      _connect();
    } else {
      monitor.stop();
    }
  }

  void _connect() {
    Uri endpoint;
    try {
      endpoint = HttpDeviceClient.endpoint(address.text);
    } on FormatException {
      monitor.stop();
      setState(() => addressError = context.l.deviceAddressInvalid);
      return;
    }
    setState(() => addressError = null);
    unawaited(monitor.connect(endpoint));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visibility?.removeListener(_visibilityChanged);
    monitor.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            hardware ? context.l.hardwareData : context.l.gameData,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          OutlinedButton.icon(
            key: const ValueKey('toggle-pet-data'),
            onPressed: () {
              setState(() => hardware = !hardware);
              _syncConnection();
            },
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: Text(
              hardware ? context.l.showGameData : context.l.showHardwareData,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (!hardware) ...[
        StatsGrid(pet: widget.pet),
        SectionLabel(context.l.xp),
        Text('${widget.pet.xp % 100} / 100 · ${widget.pet.xp} XP'),
        const SizedBox(height: 8),
        PixelProgress(value: (widget.pet.xp % 100) / 100),
      ] else
        ListenableBuilder(
          listenable: monitor,
          builder: (context, _) => _hardwareData(context),
        ),
    ],
  );

  Widget _hardwareData(BuildContext context) {
    final l = context.l, snapshot = monitor.snapshot;
    String number(double? value, String unit, int digits) => value == null
        ? (snapshot == null ? l.noRecords : l.deviceSensorUnavailable)
        : '${value.toStringAsFixed(digits)} $unit';
    final status = switch (monitor.status) {
      DeviceStatus.idle => l.devicePaused,
      DeviceStatus.connecting => l.deviceConnecting,
      DeviceStatus.live => l.deviceReceiving,
      DeviceStatus.stale => l.deviceStale,
      DeviceStatus.unavailable => l.deviceConnectionFailed,
      DeviceStatus.invalid => l.deviceProtocolInvalid,
    };
    final cells = [
      (l.temperature, number(snapshot?.temperature, '°C', 1)),
      (l.humidity, number(snapshot?.humidity, '%RH', 1)),
      (l.light, number(snapshot?.light, 'lux', 0)),
      (
        l.deviceSoilContact,
        snapshot == null
            ? l.noRecords
            : switch (snapshot.soilLevel) {
                'high' => l.deviceSoilHigh,
                'low' => l.deviceSoilLow,
                _ => l.deviceSensorUnavailable,
              },
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.deviceWifiHelp,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('device-address'),
          controller: address,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: l.deviceAddress,
            errorText: addressError,
          ),
          onChanged: (_) {
            monitor.stop();
            setState(() => addressError = null);
          },
          onSubmitted: (_) => _connect(),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('connect-device'),
          onPressed: foreground && visible ? _connect : null,
          child: Text(l.deviceConnect),
        ),
        Semantics(
          liveRegion: true,
          child: Text(status, key: const ValueKey('device-status')),
        ),
        if (monitor.error != null)
          Text(
            monitor.error!,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        if (snapshot != null) ...[
          const SizedBox(height: 8),
          Text(
            snapshot.source == 'device'
                ? l.deviceSourceHardware
                : l.deviceSourceSimulation,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(l.deviceSequence(snapshot.sequence)),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (label, value) in cells)
                SizedBox(
                  width: (box.maxWidth - 10) / 2,
                  child: PaperCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${l.deviceTouch}: ${snapshot == null
              ? l.noRecords
              : snapshot.touchMask == null
              ? l.deviceSensorUnavailable
              : snapshot.touchMask == 0
              ? l.deviceTouchIdle
              : [for (var i = 0; i < 12; i++)
                  if (snapshot.touchMask! & (1 << i) != 0) 'ELE$i'].join(', ')}',
        ),
        if (snapshot?.commandCode != null)
          Text('${l.deviceLatestEvent}: ${snapshot!.commandCode}'),
        const SizedBox(height: 8),
        Text(
          l.deviceSoilHelp,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }
}
