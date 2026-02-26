import 'dart:async'; // ★追加
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart'; // ★追加
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Home());
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  String _log = '';

  StreamSubscription<Position>? _positionStream; // ★追加

  ///
  @override
  void initState() {
    super.initState();

    _initNotifications();
  }

  ///
  @override
  void dispose() {
    _positionStream?.cancel(); // ★追加
    super.dispose();
  }

  ///
  Future<void> _initNotifications() async {
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(settings: initSettings);

    setState(() => _log = 'Notifications initialized');
  }

  ///
  Future<void> _requestNotificationPermission() async {
    await Permission.notification.request();
    await Permission.location.request(); // ★追加（前景位置）
    setState(() => _log = 'Permission.notification + location requested'); // ★文言変更（任意）
  }

  ///
  void _startLocationStream() {
    _positionStream?.cancel();

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
        ).listen(
          (Position pos) {
            setState(() => _log = '現在地: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
          },
          onError: (Object e) {
            setState(() => _log = '位置取得エラー: $e');
          },
        );

    setState(() => _log = 'Location stream started...');
  }

  ///
  Future<void> _showTestNotification() async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test',
      'Test',
      channelDescription: 'test notification',
      importance: Importance.max,
      priority: Priority.high,
      vibrationPattern: Int64List.fromList(<int>[0, 400, 200, 400]),
    );

    await _notifications.show(
      id: 1,
      title: 'テスト通知',
      body: '通知が出れば OK（振動も確認）',
      notificationDetails: NotificationDetails(android: androidDetails),
    );

    setState(() => _log = 'Notification shown');
  }

  ///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step3: 通知テスト')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            ElevatedButton(onPressed: _requestNotificationPermission, child: const Text('通知権限リクエスト')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _startLocationStream, child: const Text('現在地ストリーム開始')), // ★追加
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _showTestNotification, child: const Text('テスト通知を出す')),
            const SizedBox(height: 24),
            Align(alignment: Alignment.centerLeft, child: Text('ログ: $_log')),
          ],
        ),
      ),
    );
  }
}
