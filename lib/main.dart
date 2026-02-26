import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart';

/// =======================
/// Geofence コールバック（トップレベル必須）
/// =======================
@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await notifications.initialize(settings: initSettings);

  final String stationNames = params.geofences.map((ActiveGeofence g) => g.id).join(', ');

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'geofence',
    'Geofence',
    channelDescription: 'Notify when entering the selected station area',
    importance: Importance.max,
    priority: Priority.high,
    vibrationPattern: Int64List.fromList(<int>[0, 800, 200, 800, 200, 1200]),
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

  final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await notifications.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: '降りる駅アラーム',
    body: '到着（または進入）しました: $stationNames / event=${params.event}',
    notificationDetails: details,
  );
}

////////////////////////////////////////////////////////////////////////////////

/// 駅データ
class Station {
  const Station(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;
}

////////////////////////////////////////////////////////////////////////////////

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Geofence Demo', theme: ThemeData(useMaterial3: true), home: const GeofencePage());
  }
}

////////////////////////////////////////////////////////////////////////////////

class GeofencePage extends StatefulWidget {
  const GeofencePage({super.key});

  @override
  State<GeofencePage> createState() => _GeofencePageState();
}

class _GeofencePageState extends State<GeofencePage> {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Station? _selected;
  String _log = '';
  StreamSubscription<Position>? _positionStream;

  ///
  final List<Station> _stations = const <Station>[
    Station('東京', 35.681236, 139.767125),
    Station('神田', 35.691690, 139.770883),
    Station('秋葉原', 35.698683, 139.774219),
    Station('御徒町', 35.707438, 139.774632),
    Station('上野', 35.713768, 139.777254),
    Station('鶯谷', 35.721484, 139.778969),
    Station('日暮里', 35.727772, 139.770987),
    Station('西日暮里', 35.732135, 139.766787),
    Station('田端', 35.738079, 139.761210),
    Station('駒込', 35.736489, 139.746875),
    Station('巣鴨', 35.733492, 139.739345),
    Station('大塚', 35.731401, 139.728662),
    Station('池袋', 35.728926, 139.710380),
    Station('目白', 35.721204, 139.706587),
    Station('高田馬場', 35.712777, 139.703643),
    Station('新大久保', 35.701273, 139.700309),
    Station('新宿', 35.690921, 139.700258),
    Station('代々木', 35.683061, 139.702042),
    Station('原宿', 35.670168, 139.702687),
    Station('渋谷', 35.658034, 139.701636),
    Station('恵比寿', 35.646690, 139.710106),
    Station('目黒', 35.633998, 139.715828),
    Station('五反田', 35.626446, 139.723444),
    Station('大崎', 35.619700, 139.728553),
    Station('品川', 35.628471, 139.738760),
    Station('高輪ゲートウェイ', 35.635191, 139.740083),
    Station('田町', 35.645736, 139.747575),
    Station('浜松町', 35.655646, 139.757091),
    Station('新橋', 35.666195, 139.758587),
    Station('有楽町', 35.675069, 139.763328),
  ];

  ///
  @override
  void initState() {
    super.initState();
    _initPlugins();
  }

  ///
  Future<void> _initPlugins() async {
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(settings: initSettings);

    await NativeGeofenceManager.instance.initialize();

    setState(() {
      _log = 'Initialized.';
    });
  }

  ///
  Future<void> _requestPermissions() async {
    await Permission.location.request();

    await Permission.locationAlways.request();

    await Permission.notification.request();

    setState(() {
      _log = 'Permissions requested. location/locationAlways/notification';
    });
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
  }

  ///
  Future<void> _registerSelectedStation() async {
    final Station? s = _selected;
    if (s == null) {
      setState(() => _log = '駅を選択してください');
      return;
    }

    final Geofence zone = Geofence(
      id: 'station_${s.name}',
      location: Location(latitude: s.lat, longitude: s.lng),
      radiusMeters: 500,
      triggers: <GeofenceEvent>{GeofenceEvent.enter},
      iosSettings: const IosGeofenceSettings(initialTrigger: true),
      androidSettings: const AndroidGeofenceSettings(
        initialTriggers: <GeofenceEvent>{GeofenceEvent.enter},
        expiration: Duration(days: 7),
        loiteringDelay: Duration(minutes: 1),
        notificationResponsiveness: Duration(seconds: 10),
      ),
    );

    try {
      await NativeGeofenceManager.instance.createGeofence(zone, geofenceCallback);

      setState(() => _log = 'Registered geofence: ${zone.id}');
      _startLocationStream();
    } on NativeGeofenceException catch (e) {
      setState(() => _log = 'NativeGeofenceException: code=${e.code} msg=${e.message}');
    } catch (e) {
      setState(() => _log = 'Error: $e');
    }
  }

  ///
  Future<void> _removeAllGeofences() async {
    await NativeGeofenceManager.instance.removeAllGeofences();
    _positionStream?.cancel();
    _positionStream = null;
    setState(() => _log = 'Removed all geofences.');
  }

  ///
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
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

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    await _notifications.show(
      id: 1,
      title: 'テスト通知',
      body: '通知が出れば OK（振動も確認）',
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  ///
  @override
  Widget build(BuildContext context) {
    final Station? selected = _selected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('この駅で降りタイマー（Geofence）'),
        actions: <Widget>[
          IconButton(onPressed: _showTestNotification, icon: const Icon(Icons.notifications_active), tooltip: '通知テスト'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('駅を選択', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            SizedBox(
              height: 84,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _stations.map((Station s) {
                    final bool isSel = selected?.name == s.name;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => setState(() {
                          _selected = s;
                          _log = 'Selected: ${s.name}';
                        }),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 24,
                              child: Text(
                                s.name.characters.take(2).toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                decoration: isSel ? TextDecoration.underline : TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text('選択中: ${selected?.name ?? "(未選択)"}'),

            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text('権限リクエスト'),
                ),
                ElevatedButton.icon(
                  onPressed: _registerSelectedStation,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('この駅で監視開始'),
                ),
                OutlinedButton.icon(
                  onPressed: _removeAllGeofences,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('全停止（全削除）'),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Text('ログ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(child: Text(_log)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
