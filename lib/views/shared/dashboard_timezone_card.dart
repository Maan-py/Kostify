// lib/views/shared/dashboard_timezone_card.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/constants.dart';

class DashboardTimezoneCard extends StatefulWidget {
  final Color accentColor;

  const DashboardTimezoneCard({super.key, required this.accentColor});

  @override
  State<DashboardTimezoneCard> createState() => _DashboardTimezoneCardState();
}

class _DashboardTimezoneCardState extends State<DashboardTimezoneCard> {
  late String _selectedZoneId;
  late DateTime _now;
  Timer? _timer;

  final List<Map<String, String>> _zones = AppConstants.TIMEZONES;

  @override
  void initState() {
    super.initState();
    _selectedZoneId = _initialZoneId();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _initialZoneId() {
    final now = DateTime.now();
    final offsetMinutes = now.timeZoneOffset.inMinutes;
    final zoneName = now.timeZoneName.toUpperCase();

    switch (zoneName) {
      case 'WIB':
        return 'WIB';
      case 'WITA':
        return 'WITA';
      case 'WIT':
        return 'WIT';
    }

    if (offsetMinutes == 420) return 'WIB';
    if (offsetMinutes == 480) return 'WITA';
    if (offsetMinutes == 540) return 'WIT';
    if (offsetMinutes == 0 || offsetMinutes == 60) return 'London';

    return 'WIB';
  }

  int _zoneOffsetMinutes(String zoneId, DateTime reference) {
    switch (zoneId) {
      case 'WIB':
        return 7 * 60;
      case 'WITA':
        return 8 * 60;
      case 'WIT':
        return 9 * 60;
      case 'London':
        return _isLondonSummerTime(reference) ? 60 : 0;
      default:
        return 7 * 60;
    }
  }

  bool _isLondonSummerTime(DateTime date) {
    final start = _lastSunday(date.year, DateTime.march);
    final end = _lastSunday(date.year, DateTime.october);
    return !date.isBefore(start) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }

  DateTime _lastSunday(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0);
    return lastDay.subtract(Duration(days: lastDay.weekday % 7));
  }

  DateTime _currentTimeForZone(String zoneId) {
    final local = _now;
    final localOffset = local.timeZoneOffset.inMinutes;
    final targetOffset = _zoneOffsetMinutes(zoneId, local);
    final utc = local.subtract(Duration(minutes: localOffset));
    return utc.add(Duration(minutes: targetOffset));
  }

  String _displayLabel(String zoneId) => zoneId;

  @override
  Widget build(BuildContext context) {
    final time = _currentTimeForZone(_selectedZoneId);
    final timeFormat = DateFormat('HH:mm');
    return SizedBox(
      width: 180,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // const Text(
              //   'Waktu',
              //   style: TextStyle(
              //     color: Colors.black54,
              //     fontSize: 10,
              //     fontWeight: FontWeight.w500,
              //   ),
              // ),
              const SizedBox(height: 2),
              Text(
                timeFormat.format(time),
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: widget.accentColor.withOpacity(0.16)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedZoneId,
                isDense: true,
                isExpanded: false,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: widget.accentColor),
                dropdownColor: Colors.white,
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                items: _zones
                    .map(
                      (zone) => DropdownMenuItem<String>(
                        value: zone['id'],
                        child: Text(_displayLabel(zone['id'] ?? '')),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedZoneId = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
