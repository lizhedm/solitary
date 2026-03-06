import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'sos_button.dart';
import 'route_feedback_page.dart';
import 'ask_question_page.dart';
import 'hiking_history_page.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _locationSubscription?.cancel();
    _amapController?.disponse();
    super.dispose();
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
      final status = await Permission.location.request();
      debugPrint('Location permission: $status');

      if (status.isGranted && mounted) {
        _initLocation();
      } else if (status.isDenied) {
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

  /// 高德地图定位回调
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
        _pathPoints.add(location.latLng);
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
  }

  /// _locateToCurrentPosition - 定位到当前位置
  Future<void> _locateToCurrentPosition() async {
    debugPrint('Location button pressed');

    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('需要位置权限才能定位')));
        }
        return;
      }
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请开启设备定位服务')));
      }
      return;
    }

    // 检查当前是否有有效位置
    bool hasValidPosition = _position != null && _isValidCoordinate(_position!);

    if (hasValidPosition) {
      // 已经有有效位置，直接移动地图并添加头像标记
      _amapController?.moveCamera(CameraUpdate.newLatLngZoom(_position!, 17));
      _addAvatarMarker(_position!);
      return;
    }

    // 没有有效位置，设置标志等待高德定位回调
    _centerOnNextLocation = true;

    // 同时使用geolocator作为后备方案获取一次位置
    _getLocationWithGeolocator();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在定位...'),
          duration: Duration(seconds: 3),
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
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final double dSize = size.toDouble();

    // 背景圆
    final Paint bgPaint = Paint()..color = const ui.Color(0xFF2E7D32);
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
      color: ui.Color(0xFF2E7D32),
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
          // 移除现有的头像标记（通过anchor识别）
          _markers.removeWhere(
            (marker) => marker.anchor == const Offset(0.5, 0.5),
          );
          // 添加新的头像标记
          _markers.add(
            Marker(
              position: position,
              icon: descriptor!,
              anchor: const Offset(0.5, 0.5),
              zIndex: 100,
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
              zIndex: 60,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Create end marker failed: $e');
    }
  }

  /// 将图片字节转换为圆形标记图标的字节流（64x64）
  Future<Uint8List> _avatarCircleBytesFromBytes(Uint8List imageBytes) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(imageBytes, (ui.Image img) {
      completer.complete(img);
    });
    final ui.Image avatarImage = await completer.future;

    final int size = 64;
    final double centerX = size / 2.0;
    final double centerY = size / 2.0;
    final Offset center = Offset(centerX, centerY);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1) 内部头像圆圈，带一个外部绿色圆环（环宽 4px，内半径 28，外半径 30）
    final ringPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    // 外环半径 30
    canvas.drawCircle(Offset(centerX, centerY), 30.0, ringPaint);

    // 2) 在同一画布内裁剪一个圆形区域，绘制头像
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: 28.0));
    canvas.clipPath(clipPath);
    final Rect src = Rect.fromLTWH(
      0,
      0,
      avatarImage.width.toDouble(),
      avatarImage.height.toDouble(),
    );
    final Rect dst = Rect.fromCircle(center: center, radius: 28.0);
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
              zIndex: 50,
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

  /// _startTimer - 开始计时
  void _startTimer() {
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _currentDuration = _accumulatedDuration + now.difference(_startTime!);
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
            child: Builder(
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
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _buildTopInfoBar(),
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
          // GPS状态指示
          Row(
            children: [
              Icon(
                _position != null ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: _position != null
                    ? const Color(0xFF2E7D32)
                    : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _position != null ? 'GPS 良好' : '搜索GPS...',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // 徒步时长或状态提示
          if (_hikingState != 'IDLE')
            Column(
              children: [
                Text(
                  _formatDuration(_currentDuration),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  '徒步时长',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            )
          else
            const Text(
              '准备出发',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          // SOS状态指示
          if (_isSOSActive)
            Container(
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
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  /// _buildRightToolbar - 构建右侧工具栏
  Widget _buildRightToolbar() {
    return Column(
      children: [
        _buildToolButton(Icons.layers, () {}),
        const SizedBox(height: 12),
        _buildToolButton(Icons.my_location, () {
          _locateToCurrentPosition();
        }),
        const SizedBox(height: 12),
        _buildToolButton(Icons.group, () {}, badgeCount: 3),
        const SizedBox(height: 12),
        _buildToolButton(Icons.add_comment, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RouteFeedbackPage()),
          );
        }),
        const SizedBox(height: 12),
        _buildToolButton(Icons.help_outline, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AskQuestionPage()),
          );
        }),
      ],
    );
  }

  /// _buildToolButton - 构建工具栏按钮
  Widget _buildToolButton(
    IconData icon,
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return GestureDetector(
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
              _stopTimer();
              // 结束点标记：在当前线段末端添加 End 圆圈标记
              final LatLng endPos = (_pathPoints.isNotEmpty)
                  ? _pathPoints.last
                  : (_position ?? _defaultPosition);
              _addEndMarker(endPos);
              setState(() {
                _hikingState = 'IDLE';
                _isTrackingLocation = false;
              });
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
