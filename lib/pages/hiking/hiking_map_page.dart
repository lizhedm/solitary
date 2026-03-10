import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:provider/provider.dart';
import '../../utils/device_utils.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../models/hiking_record.dart';
import '../../services/api_service.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'dart:ui' as ui;
import 'sos_button.dart';
import 'route_feedback_page.dart';
import 'route_feedback_detail_page.dart';
import 'ask_question_page.dart';
import 'hiking_history_page.dart';
import '../../services/database_helper.dart';
import '../../services/location_manager.dart';

/// HikingMapPage - 徒步地图页面
/// 应用的核心页面，使用flutter_map显示地图，支持实时定位、徒步轨迹记录等功能
class HikingMapPage extends StatefulWidget {
  const HikingMapPage({super.key});

  @override
  State<HikingMapPage> createState() => _HikingMapPageState();
}

class _HikingMapPageState extends State<HikingMapPage>
    with WidgetsBindingObserver {
  // AMap 控制器
  AMapController? _amapController;
  // 地图是否准备就绪
  bool _isMapReady = false;
  // 是否正在初始化（显示加载界面）
  bool _isInitializing = true;
  // 错误信息（初始化失败时显示）
  String? _errorMessage;
  
  // 是否是模拟器
  bool _isSimulator = false;

  // 当前用户位置（使用LatLng格式）
  LatLng? _position;
  // 起点位置标记
  LatLng? _startMarkerPosition;
  // 徒步状态：IDLE（空闲）、RUNNING（进行中）、PAUSED（休息/暂停）
  String _hikingState = 'IDLE';
  // 是否激活SOS模式
  bool _isSOSActive = false;

  // 计时器相关变量
  Timer? _timer;
  DateTime? _startTime;
  Duration _accumulatedDuration = Duration.zero;
  Duration _currentDuration = Duration.zero;

  // 轨迹相关变量
  final List<LatLng> _pathPoints = [];
  bool _isTrackingLocation = false;
  
  // Statistics
  double _totalDistance = 0.0; // km
  int _calories = 0; // kcal
  int _elevationGain = 0; // m
  double? _startAltitude;
  double? _currentAltitude;

  // markers 状态，便于更新定位头像标记
  Set<Marker> _markers = <Marker>{};

  // 定位小蓝点样式
  MyLocationStyleOptions _myLocationStyleOptions = MyLocationStyleOptions(
    true,
    circleFillColor: const Color(0x332E7D32), // 半透明绿色
    circleStrokeColor: const Color(0xFF2E7D32), // 绿色边框
    circleStrokeWidth: 2.0,
  );

  // 是否在下一次定位更新时居中地图
  bool _centerOnNextLocation = false;

  // 位置更新流订阅
  StreamSubscription<Position>? _locationSubscription;

  // 初始地图位置（北京）
  static const LatLng _defaultPosition = LatLng(39.9042, 116.4074);

  // 附近的徒步者
  List<dynamic> _nearbyHikers = [];
  Timer? _nearbyUpdateTimer;
  
  // 图层配置
  bool _showFeedbacks = true;
  bool _showSOS = true;
  
  // 筛选条件
  int _feedbackDays = 3; // 默认最近3天
  int _minConfirms = 0; // 默认不过滤点赞数
  // 路况类型筛选（默认全选）
  final List<Map<String, dynamic>> _feedbackTypeOptions = [
    {'id': 'blocked', 'icon': Icons.block, 'label': '道路阻断', 'color': Colors.red},
    {'id': 'detour', 'icon': Icons.alt_route, 'label': '建议绕行', 'color': Colors.orange},
    {'id': 'weather', 'icon': Icons.cloud, 'label': '天气变化', 'color': Colors.blue},
    {'id': 'water', 'icon': Icons.water_drop, 'label': '水源位置', 'color': Colors.cyan},
    {'id': 'campsite', 'icon': Icons.nights_stay, 'label': '推荐营地', 'color': Colors.green},
    {'id': 'danger', 'icon': Icons.warning, 'label': '危险区域', 'color': Colors.deepOrange},
    {'id': 'supply', 'icon': Icons.store, 'label': '有补给点', 'color': Colors.purple},
    {'id': 'other', 'icon': Icons.more_horiz, 'label': '其他信息', 'color': Colors.grey},
  ];
  late Set<String> _selectedFeedbackTypes;

  // 是否已加载初始数据
  bool _initialDataLoaded = false;

  // 缓存标记
  final Map<int, Marker> _feedbackMarkersCache = {};
  final Map<int, Marker> _sosMarkersCache = {};

  @override
  void initState() {
    super.initState();
    _selectedFeedbackTypes = Set.from(_feedbackTypeOptions.map((e) => e['id']));
    _checkDevice();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
    // Start periodic nearby user updates
    _nearbyUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) => _updateNearbyHikers());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _nearbyUpdateTimer?.cancel();
    _locationSubscription?.cancel();
    _amapController?.disponse();
    super.dispose();
  }

  Future<void> _checkDevice() async {
    final isSim = await DeviceUtils.isSimulator();
    if (mounted) {
      setState(() {
        _isSimulator = isSim;
      });
    }
  }

  Future<void> _updateNearbyHikers() async {
    if (_position == null || _hikingState == 'IDLE') return;

    try {
      final response = await ApiService().post('/users/location', data: {
        'lat': _position!.latitude,
        'lng': _position!.longitude,
      });

      if (response.statusCode == 200 && response.data != null) {
        if (mounted) {
          setState(() {
            _nearbyHikers = response.data['nearbyUsers'] ?? [];
            _updateMapMarkers();
          });
        }
      }
    } catch (e) {
      debugPrint('Update location/nearby failed: $e');
    }
  }

  // Z-Index Constants
  static const double Z_INDEX_START = 50;
  static const double Z_INDEX_END = 60;
  static const double Z_INDEX_FEEDBACK = 80;
  static const double Z_INDEX_NEARBY = 90;
  static const double Z_INDEX_CURRENT_USER = 100;
  static const double Z_INDEX_SOS = 110;

  // 缓存头像标记，避免重复生成
  final Map<int, BitmapDescriptor> _avatarCache = {};
  // 缓存当前的周围用户标记，用于持久显示
  final Map<int, Marker> _nearbyMarkersCache = {};

  void _updateMapMarkers() async {
    // 1. 获取所有静态标记（Start, End, Current User等）
    // 移除所有动态管理的标记 (Feedback, Nearby, SOS) 以便重新添加
    final staticMarkers = _markers.where((m) {
      return m.zIndex != Z_INDEX_FEEDBACK && 
             m.zIndex != Z_INDEX_NEARBY && 
             m.zIndex != Z_INDEX_SOS;
    }).toSet();
    
    // 2. 更新周围用户标记缓存
    // 获取当前接口返回的所有用户ID集合
    final Set<int> currentUserIds = _nearbyHikers.map<int>((u) => u['id'] as int).toSet();
    
    // 移除已经不在附近的标记
    _nearbyMarkersCache.removeWhere((id, marker) => !currentUserIds.contains(id));

    // 更新或添加新的标记
    for (var user in _nearbyHikers) {
      final int userId = user['id'];
      final LatLng position = LatLng(user['lat'], user['lng']);
      
      // 尝试从头像缓存获取图标
      BitmapDescriptor? icon = _avatarCache[userId];
      
      // 如果没有图标缓存，且当前标记缓存中也没有该用户的标记（说明是新出现的）
      // 或者虽然有标记但没有图标（极端情况），则加载图标
      if (icon == null) {
        // 先检查是否有旧的标记可以使用（避免图标加载期间闪烁）
        if (_nearbyMarkersCache.containsKey(userId)) {
           icon = _nearbyMarkersCache[userId]!.icon;
        } else {
           // 如果完全是新的，先用默认图标占位
           final bytes = await _createAvatarMarkerBytes(
              user['nickname']?.substring(0, 1).toUpperCase() ?? '?', 
              size: 64, 
              color: Colors.blue
           );
           icon = BitmapDescriptor.fromBytes(bytes);
           
           // 异步加载真实头像
           _loadMarkerIcon(user).then((loadedIcon) {
              if (mounted && loadedIcon != null) {
                setState(() {
                  _avatarCache[userId] = loadedIcon;
                  // 图标加载完成后，更新缓存中的标记并触发刷新
                  if (_nearbyMarkersCache.containsKey(userId)) {
                     final oldMarker = _nearbyMarkersCache[userId]!;
                     _nearbyMarkersCache[userId] = Marker(
                        position: oldMarker.position, // 保持位置不变
                        icon: loadedIcon,
                        anchor: const Offset(0.5, 0.5),
                        infoWindow: InfoWindow(title: user['nickname']),
                        zIndex: Z_INDEX_NEARBY,
                     );
                     // 触发UI刷新
                     _updateMapMarkers();
                  }
                });
              }
           });
        }
      }

      // 更新位置和图标
      _nearbyMarkersCache[userId] = Marker(
        position: position,
        icon: icon, // 这里使用 icon (可能是默认的，也可能是缓存的真实头像)
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(title: user['nickname']),
        zIndex: Z_INDEX_NEARBY,
      );
    }

    if (mounted) {
      setState(() {
        // 合并 静态标记 和 所有动态标记缓存
        _markers = {
           ...staticMarkers, 
           ..._nearbyMarkersCache.values,
           ..._feedbackMarkersCache.values,
           ..._sosMarkersCache.values,
        };
      });
    }
  }

  Future<BitmapDescriptor?> _loadMarkerIcon(dynamic user) async {
    try {
        if (user['avatar'] != null && user['avatar'].toString().isNotEmpty) {
            String avatarUrl = user['avatar'];
            if (!avatarUrl.startsWith('http')) {
               avatarUrl = 'http://114.55.148.245:8000$avatarUrl';
            }
            final bytes = await _downloadAndCropAvatar(
                avatarUrl, 
                size: 64, 
                color: Colors.blue
            );
            return BitmapDescriptor.fromBytes(bytes);
        } else {
            final bytes = await _createAvatarMarkerBytes(
                user['nickname']?.substring(0, 1).toUpperCase() ?? '?', 
                size: 64, 
                color: Colors.blue
            );
            return BitmapDescriptor.fromBytes(bytes);
        }
    } catch (e) {
        return null;
    }
  }

  Future<Marker> _createNearbyMarker(dynamic user) async {
      // Deprecated, kept for interface compatibility if needed, but not used.
      return Marker(
         position: LatLng(user['lat'], user['lng']),
      );
  }

  /// 下载并裁剪网络头像
  Future<Uint8List> _downloadAndCropAvatar(
    String url, {
    int size = 128,
    Color color = const Color(0xFF2E7D32),
  }) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return await _avatarCircleBytesFromBytes(response.bodyBytes, size: size, borderColor: color);
      }
    } catch (e) {
      debugPrint('Download avatar error: $e');
    }
    // Return a default if failed, but we should handle exception above
    throw Exception('Failed to download image');
  }
  




  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle state: $state');
  }

  /// _initialize - 初始化方法
  /// 1. 请求定位权限 2. 初始化定位服务
  Future<void> _initialize() async {
    debugPrint('Starting initialization...');

    try {
      // 请求位置权限
      var status = await Permission.location.request();
      debugPrint('Location permission request result: $status');
      
      // On iOS, if user grants "When In Use" but we requested "Always" (via Permission.location),
      // status might not be granted. Check specifically.
      if (!status.isGranted && !status.isLimited) {
         final status2 = await Permission.locationWhenInUse.status;
         if (status2.isGranted || status2.isLimited) {
            status = status2;
         }
      }

      if ((status.isGranted || status.isLimited) && mounted) {
        _initLocation();
      } else {
        // 权限被拒绝，显示提示
        if (mounted) {
          setState(() {
            _errorMessage = '需要位置权限才能使用地图功能';
          });
        }
      }
    } catch (e) {
      debugPrint('Permission error: $e');
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// _initLocation - 初始化定位服务
  void _initLocation() async {
    if (!mounted) return;
    try {
      // 检查定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location service not enabled');
        return;
      }

      // 不再启动 Geolocator 位置更新流，依赖高德地图的定位回调
      // 保留 _locationSubscription 为 null
      debugPrint('Location service enabled, relying on AMap location updates');
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  /// _updateLocation - 更新位置
  void _updateLocation(Position newPos) {
    if (!mounted) return;

    final newLatLng = LatLng(newPos.latitude, newPos.longitude);

    // 检查坐标有效性，忽略无效的0,0坐标
    if (!_isValidCoordinate(newLatLng)) {
      debugPrint('收到无效的定位坐标，忽略');
      return;
    }

    setState(() {
      _position = newLatLng;
      if (_hikingState == 'RUNNING') {
        _pathPoints.add(newLatLng);
      }
    });

    // 添加头像标记
    _addAvatarMarker(newLatLng);
  }

  /// 检查坐标是否有效（不在0,0附近）
  bool _isValidCoordinate(LatLng latLng) {
    return latLng.latitude.abs() > 0.001 && latLng.longitude.abs() > 0.001;
  }

  /// _onLocationChanged - 高德地图定位回调
  void _onLocationChanged(AMapLocation location) {
    debugPrint(
      '高德定位: ${location.latLng.latitude}, ${location.latLng.longitude}',
    );

    // 检查坐标有效性，忽略无效的0,0坐标
    if (!_isValidCoordinate(location.latLng)) {
      debugPrint('收到无效的定位坐标，忽略');
      return;
    }

    // 更新位置
    setState(() {
      _position = location.latLng;
      // 如果在徒步模式，将位置添加到路径点
      if (_hikingState == 'RUNNING') {
        if (_pathPoints.isNotEmpty) {
          _totalDistance += _calculateDistance(_pathPoints.last, location.latLng);
        }
        _pathPoints.add(location.latLng);
        
        // Update altitude
        if (location.altitude != null) {
          double alt = location.altitude!;
          _currentAltitude = alt;
          if (_startAltitude == null) {
            _startAltitude = alt;
          }
          if (_startAltitude != null) {
            _elevationGain = (alt - _startAltitude!).round();
          }
        }
      }
    });
    // 添加头像标记
    _addAvatarMarker(location.latLng);

    // 如果用户点击了定位按钮，移动地图到当前位置
    if (_centerOnNextLocation) {
      _amapController?.moveCamera(
        CameraUpdate.newLatLngZoom(location.latLng, 17),
      );
      setState(() {
        _centerOnNextLocation = false;
      });
    }
    
    // 首次定位成功后，加载一次周边路况
    if (!_initialDataLoaded) {
       _initialDataLoaded = true;
       _loadFeedbacksAndSOS(center: location.latLng);
    }
  }
  
  // 添加地图视野变化监听
  void _onCameraMoveEnd(CameraPosition position) {
     _loadFeedbacksAndSOS(center: position.target);
  }

  /// _locateToCurrentPosition - 定位到当前位置
  Future<void> _locateToCurrentPosition() async {
    debugPrint('Location button pressed');

    // 1. Check/Request Permission
    // Check both location (group) and specific whenInUse to handle iOS nuances
    var status = await Permission.location.status;
    if (!status.isGranted && !status.isLimited) {
      status = await Permission.locationWhenInUse.status;
    }
    
    if (!status.isGranted && !status.isLimited) {
      // Try requesting
      status = await Permission.location.request();
      
      // If still not granted, check if it's because we only got WhenInUse (which is fine for this)
      if (!status.isGranted && !status.isLimited) {
         status = await Permission.locationWhenInUse.status;
      }

      if (!status.isGranted && !status.isLimited) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('需要位置权限才能定位')));
        }
        return;
      }
    }
    
    // 2. Check Service Status (Optional, sometimes Geolocator check fails on iOS even if enabled)
    // We can skip strict Geolocator service check if we trust AMap or want to avoid false negatives.
    // However, checking enabled is good practice. 
    // On iOS, sometimes isLocationServiceEnabled returns false if permission is not determined yet?
    // Let's rely on AMap callbacks mostly, but basic check is fine.
    
    // 3. Check if we already have a valid position from AMap callback
    if (_position != null && _isValidCoordinate(_position!)) {
      _amapController?.moveCamera(CameraUpdate.newLatLngZoom(_position!, 17));
      _addAvatarMarker(_position!);
      return;
    }

    // 4. If no position yet, set flag to center on next update
    setState(() {
      _centerOnNextLocation = true;
    });

    // 5. Force AMap to locate? AMap usually auto-locates if myLocationEnabled is true.
    // But we can also try Geolocator as fallback/accelerator
    _getLocationWithGeolocator();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在定位...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 使用geolocator获取位置作为后备方案
  Future<void> _getLocationWithGeolocator() async {
    try {
      debugPrint('使用geolocator获取位置...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).timeout(const Duration(seconds: 5));

      final latLng = LatLng(position.latitude, position.longitude);
      debugPrint('geolocator定位: ${latLng.latitude}, ${latLng.longitude}');

      if (!_isValidCoordinate(latLng)) {
        debugPrint('geolocator返回无效坐标');
        return;
      }

      // 更新位置
      if (mounted) {
        setState(() {
          _position = latLng;
        });
      }

      // 移动地图到当前位置
      _amapController?.moveCamera(CameraUpdate.newLatLngZoom(latLng, 17));

      // 添加头像标记
      _addAvatarMarker(latLng);

      // 如果之前设置了等待标志，清除它
      if (_centerOnNextLocation) {
        setState(() {
          _centerOnNextLocation = false;
        });
      }
    } catch (e) {
      debugPrint('geolocator定位失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('定位失败: $e')));
      }
    }
  }

  /// 生成头像 Marker 的 PNG bytes（圆形带文字首字母）
  Future<Uint8List> _createAvatarMarkerBytes(
    String label, {
    int size = 128,
    Color color = const Color(0xFF2E7D32),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final double dSize = size.toDouble();

    // 背景圆
    final Paint bgPaint = Paint()..color = color;
    final Offset center = Offset(dSize / 2, dSize / 2);
    canvas.drawCircle(center, dSize / 2, bgPaint);

    // 白色内圈（边框效果）
    final Paint borderPaint = Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawCircle(center, dSize * 0.44, borderPaint);

    // 文本（首字母）
    final ui.ParagraphStyle paragraphStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontWeight: ui.FontWeight.bold,
    );
    final ui.TextStyle textStyle = ui.TextStyle(
      color: color,
      fontSize: dSize * 0.45,
    );
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(label);
    final ui.Paragraph paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: dSize));
    // 将文本绘制到中心位置
    final double textY = (dSize - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, Offset(0, textY));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size, size);
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  /// 添加头像标记到指定位置
  Future<void> _addAvatarMarker(LatLng position) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      User? currentUser = authProvider.user;
      BitmapDescriptor? descriptor;
      if (currentUser != null && currentUser.avatar != null) {
        final avatarUrl =
            '${currentUser.avatar!}?v=${authProvider.avatarVersion}';
        try {
          final token = authProvider.token;
          final headers = token != null
              ? {'Authorization': 'Bearer $token'}
              : null;
          final resp = await http.get(Uri.parse(avatarUrl), headers: headers);
          if (resp.statusCode == 200) {
            final circleBytes = await _avatarCircleBytesFromBytes(
              resp.bodyBytes,
            );
            descriptor = BitmapDescriptor.fromBytes(circleBytes);
          }
        } catch (_) {
          descriptor = null;
        }
      }
      if (descriptor == null) {
        // 备用：使用默认的圆形图标带字母U
        final String initial = 'U';
        final bytes = await _createAvatarMarkerBytes(initial, size: 64);
        descriptor = BitmapDescriptor.fromBytes(bytes);
      }
      if (mounted) {
        setState(() {
          // 仅移除当前用户的标记（通过zIndex=Z_INDEX_CURRENT_USER识别）
          // 之前的逻辑是根据anchor移除，这会错误地移除周围用户（也是0.5,0.5）
          _markers.removeWhere(
            (marker) => marker.zIndex == Z_INDEX_CURRENT_USER,
          );
          // 添加新的头像标记
          _markers.add(
            Marker(
              position: position,
              icon: descriptor!,
              anchor: const Offset(0.5, 0.5),
              zIndex: Z_INDEX_CURRENT_USER, // 当前用户标记具有最高层级
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Create avatar marker failed: $e');
    }
  }

  // End marker helper: create an end marker with 'E' inside a circle
  Future<Uint8List> _createEndMarkerBytes(String label, {int size = 32}) async {
    // For simplicity, reuse the same style as the start marker but with arbitrary label
    return await _createStartMarkerBytes(label, size: size);
  }

  // Add an End marker at the given position, to correspond with Start marker
  Future<void> _addEndMarker(LatLng position) async {
    try {
      final bytes = await _createEndMarkerBytes('E', size: 32);
      final descriptor = BitmapDescriptor.fromBytes(bytes);
      if (mounted) {
        setState(() {
          // Use a distinct anchor to avoid conflicting with Start marker (0.5,0.5))
          _markers.removeWhere(
            (marker) => marker.anchor == const Offset(0.75, 0.5),
          );
          _markers.add(
            Marker(
              position: position,
              icon: descriptor,
              anchor: const Offset(0.75, 0.5), // 与 Start 区分开
              zIndex: Z_INDEX_END,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Create end marker failed: $e');
    }
  }

  /// 将图片字节转换为圆形标记图标的字节流（支持自定义边框颜色）
  Future<Uint8List> _avatarCircleBytesFromBytes(
      Uint8List imageBytes, {
      int size = 64, 
      Color borderColor = const Color(0xFF2E7D32)
  }) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(imageBytes, (ui.Image img) {
      completer.complete(img);
    });
    final ui.Image avatarImage = await completer.future;

    final double centerX = size / 2.0;
    final double centerY = size / 2.0;
    final Offset center = Offset(centerX, centerY);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1) 内部头像圆圈，带一个外部圆环
    final ringPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    // 外环半径 slightly smaller than half size to fit stroke
    final double radius = (size / 2.0) - 2.0;
    canvas.drawCircle(Offset(centerX, centerY), radius, ringPaint);

    // 2) 在同一画布内裁剪一个圆形区域，绘制头像
    final double innerRadius = radius - 2.0;
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.clipPath(clipPath);
    
    // Scale image to cover
    // Calculate scale to cover the circle
    final double scale = math.max(
        (size.toDouble()) / avatarImage.width,
        (size.toDouble()) / avatarImage.height
    );
    
    final double scaledWidth = avatarImage.width * scale;
    final double scaledHeight = avatarImage.height * scale;
    
    // Center crop
    final Rect src = Rect.fromLTWH(0, 0, avatarImage.width.toDouble(), avatarImage.height.toDouble());
    final Rect dst = Rect.fromLTWH(
        centerX - scaledWidth / 2, 
        centerY - scaledHeight / 2, 
        scaledWidth, 
        scaledHeight
    );
    
    canvas.drawImageRect(avatarImage, src, dst, Paint());

    final ui.Picture picture = recorder.endRecording();
    final ui.Image finalImg = await picture.toImage(size, size);
    final ByteData? byteData = await finalImg.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  /// 添加起点标记
  Future<void> _addStartMarker(LatLng position) async {
    try {
      // 创建蓝色起点标记，中间有"S"表示起点
      final bytes = await _createStartMarkerBytes('S', size: 32);
      final descriptor = BitmapDescriptor.fromBytes(bytes);
      if (mounted) {
        setState(() {
          // 移除可能已存在的起点标记（通过anchor识别）
          _markers.removeWhere(
            (marker) => marker.anchor == const Offset(0.5, 0.5),
          );
          _markers.add(
            Marker(
              position: position,
              icon: descriptor,
              anchor: const Offset(0.5, 0.5), // 中心对齐
              zIndex: Z_INDEX_START,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Create start marker failed: $e');
    }
  }

  /// 创建起点标记图标
  Future<Uint8List> _createStartMarkerBytes(
    String label, {
    int size = 32,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final double dSize = size.toDouble();

    // 背景圆 - 使用蓝色表示起点
    final Paint bgPaint = Paint()..color = const ui.Color(0xFF2196F3);
    final Offset center = Offset(dSize / 2, dSize / 2);
    canvas.drawCircle(center, dSize / 2, bgPaint);

    // 白色内圈（边框效果）
    final Paint borderPaint = Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawCircle(center, dSize * 0.44, borderPaint);

    // 文本（S）
    final ui.ParagraphStyle paragraphStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      fontWeight: ui.FontWeight.bold,
    );
    final ui.TextStyle textStyle = ui.TextStyle(
      color: ui.Color(0xFF2196F3),
      fontSize: dSize * 0.45,
    );
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(label);
    final ui.Paragraph paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: dSize));
    // 将文本绘制到中心位置
    final double textY = (dSize - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, Offset(0, textY));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size, size);
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  /// Calculate distance between two points in km
  double _calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 -
        c((p2.latitude - p1.latitude) * p) / 2 +
        c(p1.latitude * p) *
            c(p2.latitude * p) *
            (1 - c((p2.longitude - p1.longitude) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  /// _startTimer - 开始计时
  void _startTimer() {
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _currentDuration = _accumulatedDuration + now.difference(_startTime!);
          
          // Calculate calories: 5.5 * 60 * time(hours)
          // 5.5 * 60 = 330 kcal per hour
          double hours = _currentDuration.inSeconds / 3600.0;
          _calories = (330 * hours).round();
        });
      }
    });
  }

  /// _pauseTimer - 暂停计时
  void _pauseTimer() {
    _timer?.cancel();
    if (_startTime != null) {
      _accumulatedDuration += DateTime.now().difference(_startTime!);
    }
    _startTime = null;
  }

  /// _resumeTimer - 恢复计时
  void _resumeTimer() {
    _startTimer();
  }

  /// _stopTimer - 停止计时
  void _stopTimer() {
    _timer?.cancel();
    if (_startTime != null) {
      _accumulatedDuration += DateTime.now().difference(_startTime!);
    }
    _startTime = null;
    _accumulatedDuration = Duration.zero;
    _currentDuration = Duration.zero;
    _pathPoints.clear();
    // 清除起点标记
    if (mounted) {
      setState(() {
        _markers.removeWhere(
          (marker) => marker.anchor == const Offset(0.5, 0.5),
        );
        _startMarkerPosition = null;
      });
    }
  }

  /// _formatDuration - 格式化时长
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // continue to build map UI for all platforms (web/iOS/Android)

    // 显示加载界面
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF2E7D32)),
              const SizedBox(height: 16),
              const Text('正在加载...'),
            ],
          ),
        ),
      );
    }

    // 显示错误信息
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  '出错了',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isInitializing = true;
                    });
                    _initialize();
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 正常显示地图页面
    return Scaffold(
      body: Stack(
        children: [
          // 地图区域（使用高德AMap）
          Positioned.fill(
            child: _isSimulator 
                ? Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            '地图功能在模拟器中不可用',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '请使用真机测试地图相关功能',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : Builder(
              builder: (context) {
                final Set<Polyline> _polylines = <Polyline>{};
                if (_pathPoints.isNotEmpty) {
                  _polylines.add(
                    Polyline(
                      points: _pathPoints,
                      width: 3,
                      color: const Color(0xFF2E7D32),
                    ),
                  );
                }

                return AMapWidget(
                  // 合规声明（必须设置，否则部分SDK版本会白屏）
                  privacyStatement: const AMapPrivacyStatement(
                    hasContains: true,
                    hasShow: true,
                    hasAgree: true,
                  ),
                  apiKey: const AMapApiKey(
                    androidKey: '4bf8b27c0d66ef2fce72e133db777349',
                    iosKey: '173b139f4b0710330132c496bf45ece1',
                    webKey: '1f67dc45ef1c30121049a15d27edf12e',
                  ),
                  initialCameraPosition: CameraPosition(
                    target: _position ?? _defaultPosition,
                    zoom: 15,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationStyleOptions: _myLocationStyleOptions,
                  onLocationChanged: _onLocationChanged,
                  onCameraMoveEnd: _onCameraMoveEnd, // Add this
                  onMapCreated: (AMapController controller) {
                    debugPrint('AMap created');
                    setState(() {
                      _amapController = controller;
                      _isMapReady = true;
                    });
                  },
                );
              },
            ),
          ),

          // 顶部信息栏
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: SafeArea(
              child: _buildTopInfoBar(),
            ),
          ),

          // 右侧工具栏
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: _buildRightToolbar(),
          ),

          // 底部操作栏
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomActionBar(),
          ),

          // SOS遮罩层
          if (_isSOSActive) _buildSOSOverlay(),
        ],
      ),
    );
  }

  /// _buildTopInfoBar - 构建顶部信息栏
  Widget _buildTopInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：GPS状态和徒步时长
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _position != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: _position != null
                        ? const Color(0xFF2E7D32)
                        : Colors.grey,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _position != null ? 'GPS 良好' : '搜索GPS...',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (_hikingState != 'IDLE')
                Text(
                  _formatDuration(_currentDuration),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  '准备出发',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          
          // 右侧：实时数据（公里数、热量、爬升）
          if (_hikingState != 'IDLE')
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildStatItem(Icons.directions_walk, '${_totalDistance.toStringAsFixed(1)}km', Colors.green),
                  const SizedBox(width: 8),
                  _buildStatItem(Icons.local_fire_department, '$_calories kcal', Colors.orange),
                  const SizedBox(width: 8),
                  _buildStatItem(Icons.terrain, '$_elevationGain m', Colors.brown),
                ],
              ),
            ),

          // SOS状态指示
          if (_isSOSActive)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 添加图层配置对话框
  void _showLayerConfig() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('图层显示', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 路况开关
                      SwitchListTile(
                        title: const Text('路况信息'),
                        secondary: const Icon(Icons.comment, color: Colors.blue),
                        value: _showFeedbacks,
                        onChanged: (val) {
                          // Update local state (modal)
                          setModalState(() => _showFeedbacks = val);
                          // Update parent state (map page)
                          this.setState(() {
                            _showFeedbacks = val;
                            _refreshMapMarkers();
                          });
                        },
                      ),
                      
                      // 路况筛选（仅当路况开启时显示）
                      if (_showFeedbacks) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 8),
                          child: Text('路况筛选', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Text('时间范围: '),
                              DropdownButton<int>(
                                value: _feedbackDays,
                                items: const [
                                  DropdownMenuItem(value: 3, child: Text('最近3天')),
                                  DropdownMenuItem(value: 7, child: Text('最近7天')),
                                  DropdownMenuItem(value: 30, child: Text('最近30天')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => _feedbackDays = val);
                                    this.setState(() {
                                      _feedbackDays = val;
                                      _refreshMapMarkers();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Text('最少确认: '),
                              DropdownButton<int>(
                                value: _minConfirms,
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('不限')),
                                  DropdownMenuItem(value: 5, child: Text('5+')),
                                  DropdownMenuItem(value: 10, child: Text('10+')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => _minConfirms = val);
                                    this.setState(() {
                                      _minConfirms = val;
                                      _refreshMapMarkers();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                          child: Text('路况类型:', style: TextStyle(fontSize: 14)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _feedbackTypeOptions.map((type) {
                              final id = type['id'] as String;
                              final label = type['label'] as String;
                              final icon = type['icon'] as IconData;
                              final color = type['color'] as Color;
                              final isSelected = _selectedFeedbackTypes.contains(id);

                              return FilterChip(
                                label: Text(label),
                                avatar: Icon(
                                  icon,
                                  size: 18,
                                  color: isSelected ? Colors.white : color,
                                ),
                                selected: isSelected,
                                onSelected: (bool selected) {
                                  setModalState(() {
                                    if (selected) {
                                      _selectedFeedbackTypes.add(id);
                                    } else {
                                      _selectedFeedbackTypes.remove(id);
                                    }
                                  });
                                  this.setState(() {
                                    // Sync state and refresh
                                    if (selected) {
                                       _selectedFeedbackTypes.add(id);
                                    } else {
                                       _selectedFeedbackTypes.remove(id);
                                    }
                                    _refreshMapMarkers();
                                  });
                                },
                                selectedColor: color,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                                backgroundColor: Colors.white,
                                side: BorderSide(color: color),
                                checkmarkColor: Colors.white,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      
                      const Divider(),
                      
                      // 求助开关
                      SwitchListTile(
                        title: const Text('求助信号'),
                        secondary: const Icon(Icons.warning, color: Colors.red),
                        value: _showSOS,
                        onChanged: (val) {
                          setModalState(() => _showSOS = val);
                          this.setState(() {
                            _showSOS = val;
                            _refreshMapMarkers();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 刷新地图上的所有标记（路况、求助、周围用户等）
  void _refreshMapMarkers() {
    if (_position == null) return;
    
    // 重新加载路况和求助数据
    _loadFeedbacksAndSOS();
    
    // 触发UI更新（_updateMapMarkers 会合并所有缓存的标记）
    _updateMapMarkers();
  }

  // 加载路况和求助数据
  Future<void> _loadFeedbacksAndSOS({LatLng? center}) async {
    final targetPos = center ?? _position;
    if (targetPos == null) return;
    
    // 计算当前可见范围（这里简单模拟，实际可以使用地图的bounds）
    // 扩大搜索范围，确保能看到演示数据 (北京到周边)
    final double range = 2.0; // ~200km
    final minLat = targetPos.latitude - range;
    final maxLat = targetPos.latitude + range;
    final minLng = targetPos.longitude - range;
    final maxLng = targetPos.longitude + range;

    // 1. 加载路况
    if (_showFeedbacks) {
      try {
        final response = await ApiService().get('/messages/feedbacks', queryParameters: {
          'min_lat': minLat,
          'max_lat': maxLat,
          'min_lng': minLng,
          'max_lng': maxLng,
          'days': _feedbackDays,
          'min_confirms': _minConfirms,
          // Note: Backend filtering for types is not implemented yet, so we filter locally in _updateFeedbackMarkers
        });
        
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data;
          _updateFeedbackMarkers(data);
        }
      } catch (e) {
        debugPrint('Load feedbacks failed: $e');
      }
    } else {
      _feedbackMarkersCache.clear();
    }

    // 2. 加载求助
    if (_showSOS) {
      try {
        final response = await ApiService().get('/messages/sos', queryParameters: {
          'min_lat': minLat,
          'max_lat': maxLat,
          'min_lng': minLng,
          'max_lng': maxLng,
        });
        
        if (response.statusCode == 200) {
          final List<dynamic> data = response.data;
          _updateSOSMarkers(data);
        }
      } catch (e) {
        debugPrint('Load SOS failed: $e');
      }
    } else {
      _sosMarkersCache.clear();
    }
    
    _updateMapMarkers();
  }

  // 更新路况标记缓存
  Future<void> _updateFeedbackMarkers(List<dynamic> feedbacks) async {
    _feedbackMarkersCache.clear();
    for (var item in feedbacks) {
      try {
        final id = item['id'];
        final lat = item['latitude'];
        final lng = item['longitude'];
        final type = item['type'];
        
        // Filter by selected types
        if (!_selectedFeedbackTypes.contains(type)) {
          continue;
        }
        
        // 根据类型选择图标颜色
        Color color = Colors.grey;
        IconData iconData = Icons.info;
        
        // 从配置中查找对应的图标和颜色
        final typeOption = _feedbackTypeOptions.firstWhere(
          (element) => element['id'] == type,
          orElse: () => {'color': Colors.grey, 'icon': Icons.info},
        );
        
        color = typeOption['color'] as Color;
        iconData = typeOption['icon'] as IconData;
        
        final iconBytes = await _createIconMarkerBytes(iconData, color);
        
        _feedbackMarkersCache[id] = Marker(
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.fromBytes(iconBytes),
          onTap: (markerId) => _showMarkerInfoCard(item, isSOS: false),
          zIndex: Z_INDEX_FEEDBACK,
        );
      } catch (e) {
        debugPrint('Error creating feedback marker: $e');
      }
    }
  }

  // 更新求助标记缓存
  Future<void> _updateSOSMarkers(List<dynamic> alerts) async {
    _sosMarkersCache.clear();
    for (var item in alerts) {
      try {
        final id = item['id'];
        final lat = item['latitude'];
        final lng = item['longitude'];
        
        final iconBytes = await _createIconMarkerBytes(Icons.sos, Colors.red, isPulse: true);
        
        _sosMarkersCache[id] = Marker(
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.fromBytes(iconBytes),
          onTap: (markerId) => _showMarkerInfoCard(item, isSOS: true),
          zIndex: Z_INDEX_SOS, // SOS 最顶层
        );
      } catch (e) {
        debugPrint('Error creating SOS marker: $e');
      }
    }
  }

  // 生成图标标记
  Future<Uint8List> _createIconMarkerBytes(IconData icon, Color color, {bool isPulse = false}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 80;
    final double dSize = size.toDouble();
    final center = Offset(dSize / 2, dSize / 2);

    // 绘制背景
    if (isPulse) {
       final pulsePaint = Paint()..color = color.withOpacity(0.3);
       canvas.drawCircle(center, dSize / 2 + 8, pulsePaint);
    }
    final bgPaint = Paint()..color = color;
    canvas.drawCircle(center, dSize / 2, bgPaint);
    
    // 绘制边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, dSize / 2 - 2, borderPaint);

    // 绘制图标
    try {
      final textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 40,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage, 
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((dSize - textPainter.width) / 2, (dSize - textPainter.height) / 2));
    } catch (e) {
      debugPrint('Error painting icon: $e');
      // Fallback: 绘制一个简单的白色圆点
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(center, 6, dotPaint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // 显示标记信息卡片
  void _showMarkerInfoCard(Map<String, dynamic> data, {required bool isSOS}) {
    // 定义类型映射，用于显示中文标签和颜色
    final typeMap = {
      'blocked': {'label': '道路阻断', 'color': Colors.red, 'icon': Icons.block},
      'detour': {'label': '建议绕行', 'color': Colors.orange, 'icon': Icons.alt_route},
      'weather': {'label': '天气变化', 'color': Colors.blue, 'icon': Icons.cloud},
      'water': {'label': '水源位置', 'color': Colors.cyan, 'icon': Icons.water_drop},
      'campsite': {'label': '推荐营地', 'color': Colors.green, 'icon': Icons.nights_stay},
      'danger': {'label': '危险区域', 'color': Colors.deepOrange, 'icon': Icons.warning},
      'supply': {'label': '有补给点', 'color': Colors.purple, 'icon': Icons.store},
      'sos': {'label': '紧急求助', 'color': Colors.red, 'icon': Icons.warning},
      'other': {'label': '其他信息', 'color': Colors.grey, 'icon': Icons.more_horiz},
    };

    String typeStr = data['type'] as String? ?? 'other';
    if (isSOS) {
       typeStr = 'sos';
    }
    
    final typeInfo = typeMap[typeStr] ?? typeMap['other']!;
    final color = typeInfo['color'] as Color;
    final label = typeInfo['label'] as String;
    final icon = typeInfo['icon'] as IconData;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  data['content'] ?? data['message'] ?? '无内容',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSOS ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close card
                    // Both SOS and Feedback use the same detail page for now
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => RouteFeedbackDetailPage(feedback: data))
                    );
                  },
                  child: const Text('查看详情'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// _buildRightToolbar - 构建右侧工具栏
  Widget _buildRightToolbar() {
    return Column(
      children: [
        _buildToolButton(Icons.layers, '图层', () => _showLayerConfig()),
        const SizedBox(height: 12),
        _buildToolButton(Icons.my_location, '定位', () {
          _locateToCurrentPosition();
        }),
        const SizedBox(height: 12),
        _buildToolButton(Icons.group, '队友', () {}, badgeCount: 3),
        const SizedBox(height: 12),
        _buildToolButton(Icons.add_comment, '路况', () {
          if (_hikingState != 'RUNNING') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先开始徒步才能发布路况')),
            );
            return;
          }
          if (_position != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RouteFeedbackPage(
                latitude: _position!.latitude,
                longitude: _position!.longitude,
              )),
            );
          } else {
             // If no location yet, maybe prompt or still push (page handles fallback)
             Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const RouteFeedbackPage()),
             );
          }
        }),
        const SizedBox(height: 12),
        _buildToolButton(Icons.help_outline, '求助', () {
          if (_hikingState != 'RUNNING') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先开始徒步才能发送求助')),
            );
            return;
          }
          if (_position != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AskQuestionPage(
                latitude: _position!.latitude,
                longitude: _position!.longitude,
              )),
            );
          } else {
             Navigator.push(
               context,
               MaterialPageRoute(builder: (context) => const AskQuestionPage()),
             );
          }
        }),
      ],
    );
  }

  /// _buildToolButton - 构建工具栏按钮
  Widget _buildToolButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: Colors.grey[700]),
                if (badgeCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  /// _buildBottomActionBar - 构建底部操作栏
  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: _hikingState != 'IDLE'
          ? _buildActiveActions()
          : _buildStartAction(),
    );
  }

  /// _buildStartAction - 构建开始徒步按钮
  Widget _buildStartAction() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          debugPrint('Start hiking button pressed');
          setState(() {
            _hikingState = 'RUNNING';
            _startTimer();
            _pathPoints.clear();
            _isTrackingLocation = true;
            if (_position != null) {
              _pathPoints.add(_position!);
            }
          });
          // 添加起点标记
          if (_position != null) {
            _addStartMarker(_position!);
            _addAvatarMarker(_position!);
          }
          
          LocationManager().startHiking(); // Notify backend hiking started
          
          // Initial location update to set is_hiking=true on backend immediately
          if (_position != null) {
             ApiService().post('/hiking/start', data: {
                'lat': _position!.latitude,
                'lng': _position!.longitude,
             });
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_walk),
            SizedBox(width: 8),
            Text(
              '开始徒步',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// _buildActiveActions - 构建徒步中的操作按钮
  Widget _buildActiveActions() {
    final isRunning = _hikingState == 'RUNNING';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircleAction(
          icon: isRunning ? Icons.pause : Icons.play_arrow,
          label: isRunning ? '休息' : '继续',
          color: isRunning ? Colors.orange : Colors.green,
          onTap: () {
            setState(() {
              if (isRunning) {
                _hikingState = 'PAUSED';
                _pauseTimer();
                _isTrackingLocation = false;
              } else {
                _hikingState = 'RUNNING';
                _resumeTimer();
                _isTrackingLocation = true;
              }
            });
          },
        ),
        const SOSButton(),
        _buildCircleAction(
          icon: Icons.stop,
          label: '结束',
          color: Colors.grey,
          onTap: () => _showEndHikingDialog(),
        ),
      ],
    );
  }

  /// _buildCircleAction - 构建圆形操作按钮
  Widget _buildCircleAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// _endHiking - 结束徒步并保存数据
  Future<void> _endHiking() async {
    // 1. 记录结束时间并获取开始时间（在停止计时器前）
    final DateTime now = DateTime.now();
    final DateTime start = _startTime ?? now;
    final int duration = _currentDuration.inSeconds;
    
    // 2. 停止计时和定位
    _stopTimer();
    LocationManager().stopHiking(); // Notify backend hiking stopped
    final LatLng endPos = (_pathPoints.isNotEmpty)
        ? _pathPoints.last
        : (_position ?? _defaultPosition);
    _addEndMarker(endPos);
    
    // 3. 截图
    Uint8List? snapshotBytes;
    if (_amapController != null) {
      try {
        snapshotBytes = await _amapController!.takeSnapshot();
      } catch (e) {
        debugPrint('Take snapshot failed: $e');
      }
    }
    
    // 4. 上传截图
    String? snapshotUrl;
    if (snapshotBytes != null) {
      try {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            snapshotBytes,
            filename: 'snapshot_${DateTime.now().millisecondsSinceEpoch}.png',
          ),
        });
        
        final response = await ApiService().post('/upload/snapshot', data: formData);
        if (response.statusCode == 200 && response.data != null) {
          snapshotUrl = response.data['url'];
        }
      } catch (e) {
        debugPrint('Upload snapshot failed: $e');
      }
    }
    
    // 5. 准备关联消息
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? 0;
    final startTs = (start.millisecondsSinceEpoch / 1000).round();
    final endTs = (now.millisecondsSinceEpoch / 1000).round();
    
    // 6. 保存记录
    int? localRecordId;
    int associatedCount = 0;
    
    try {
      // 6.1 先计算并关联本地消息，获取数量
      // 注意：这里先关联到一个临时ID或者在保存记录后再关联
      // 我们先保存记录以获取 localRecordId
      
      final record = HikingRecord(
        id: '', // Backend will generate ID
        userId: userId,
        startTime: start,
        endTime: now,
        duration: duration,
        distance: _totalDistance,
        calories: _calories,
        elevationGain: _elevationGain,
        startLocation: 'Unknown', 
        endLocation: 'Unknown',
        mapSnapshotUrl: snapshotUrl,
        messageCount: 0, // 初始为0
        coordinatesJson: jsonEncode(_pathPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()),
      );
      
      final localRecordMap = record.toJson();
      localRecordMap.remove('id'); 
      localRecordMap['sync_status'] = 1; 
      localRecordId = await DatabaseHelper().saveHikingRecord(localRecordMap);
      
      // 6.2 关联本地消息并更新数量
      associatedCount = await DatabaseHelper().associateMessagesWithHike(localRecordId, userId, startTs, endTs);
      debugPrint('Associated $associatedCount messages with hike $localRecordId');
      
      // 更新本地记录的消息数
      localRecordMap['local_id'] = localRecordId;
      localRecordMap['message_count'] = associatedCount;
      await DatabaseHelper().saveHikingRecord(localRecordMap);
      
      // 6.3 上传到服务器
      final syncRecord = record.copyWith(messageCount: associatedCount);
      final response = await ApiService().post('/hiking-records', data: syncRecord.toJson());
      
      if (response.statusCode == 200) {
         final remoteRecord = HikingRecord.fromJson(response.data);
         final remoteId = int.tryParse(remoteRecord.id);
         
         // 6.4 同步消息关联到服务器
         if (remoteId != null && associatedCount > 0) {
            try {
              await ApiService().post('/messages/associate', data: {
                'hike_id': remoteId,
                'start_time': start.millisecondsSinceEpoch,
                'end_time': now.millisecondsSinceEpoch,
              });
              debugPrint('Synced message association to server for hike $remoteId');
            } catch (e) {
              debugPrint('Sync message association failed: $e');
            }
         }
         
         // 6.5 更新本地记录状态为已同步
         localRecordMap['remote_id'] = remoteId;
         localRecordMap['sync_status'] = 0; 
         localRecordMap['local_id'] = localRecordId; 
         
         await DatabaseHelper().saveHikingRecord(localRecordMap);
      }
    } catch (e) {
      debugPrint('Save hiking record failed: $e');
      if (mounted) {
        if (localRecordId == null) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存记录失败: $e')));
        }
      }
    }

    if (mounted) {
      setState(() {
        _hikingState = 'IDLE';
        _isTrackingLocation = false;
        _totalDistance = 0.0;
        _calories = 0;
        _elevationGain = 0;
        _startAltitude = null;
        _currentAltitude = null;
      });
      
      // 6. 跳转到历史页面
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HikingHistoryPage()),
      );
    }
  }

  /// _showEndHikingDialog - 显示结束徒步对话框
  void _showEndHikingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束徒步'),
        content: const Text('确定要结束本次徒步吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endHiking();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// _buildSOSOverlay - 构建SOS遮罩层
  Widget _buildSOSOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 80),
            const SizedBox(height: 24),
            const Text(
              'SOS 已激活',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () => setState(() => _isSOSActive = false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              child: const Text('解除SOS'),
            ),
          ],
        ),
      ),
    );
  }
}
