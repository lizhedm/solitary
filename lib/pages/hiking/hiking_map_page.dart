import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'dart:typed_data';
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
  // 徒步状态：IDLE（空闲）、RUNNING（进行中）、PAUSED（暂停）
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

      // 启动位置更新流
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen(
            (Position position) {
              debugPrint(
                'Location: ${position.latitude}, ${position.longitude}',
              );
              _updateLocation(position);
            },
            onError: (error) {
              debugPrint('Location stream error: $error');
            },
          );

      // 获取上次已知位置
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        _updateLocation(position);
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  /// _updateLocation - 更新位置
  void _updateLocation(Position newPos) {
    if (!mounted) return;

    final newLatLng = LatLng(newPos.latitude, newPos.longitude);

    setState(() {
      _position = newLatLng;
      if (_hikingState == 'RUNNING') {
        _pathPoints.add(newLatLng);
      }
    });

    // 徒步模式下移动相机跟随位置
    if (_hikingState == 'RUNNING' && _position != null) {
      _amapController?.moveCamera(CameraUpdate.newLatLngZoom(_position!, 17));
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

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在定位...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      debugPrint('Position: ${position.latitude}, ${position.longitude}');

      final currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _position = currentLatLng;
        _isTrackingLocation = true;
      });

      // 移动地图到当前位置
      _amapController?.moveCamera(CameraUpdate.newLatLngZoom(currentLatLng, 17));

      // 生成头像标记并添加到地图上（使用首字母占位）
      try {
        const String initial = 'U';
        final bytes = await _createAvatarMarkerBytes(initial, size: 128);
        final descriptor = await BitmapDescriptor.fromBytes(bytes);
        if (mounted) {
          setState(() {
            _markers = <Marker>{
              Marker(position: currentLatLng, icon: descriptor, anchor: const Offset(0.5, 1.0)),
            };
          });
        }
      } catch (e) {
        debugPrint('Create avatar marker failed: $e');
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('定位成功'),
            content: Text(
              '当前位置: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('定位失败: $e')));
      }
    }
  }

  /// 生成头像 Marker 的 PNG bytes（圆形带文字首字母）
  Future<Uint8List> _createAvatarMarkerBytes(String label, {int size = 128}) async {
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
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(paragraphStyle)..pushStyle(textStyle)..addText(label);
    final ui.Paragraph paragraph = pb.build()..layout(ui.ParagraphConstraints(width: dSize));
    // 将文本绘制到中心位置
    final double textY = (dSize - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, Offset(0, textY));

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(size, size);
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
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
            child: Builder(builder: (context) {
              final Set<Polyline> _polylines = <Polyline>{};
              if (_pathPoints.isNotEmpty) {
                _polylines.add(Polyline(points: _pathPoints, width: 6, color: const Color(0xFF2E7D32)));
              }

              return AMapWidget(
                // 合规声明（必须设置，否则部分SDK版本会白屏）
                privacyStatement: const AMapPrivacyStatement(hasContains: true, hasShow: true, hasAgree: true),
                apiKey: const AMapApiKey(
                  androidKey: '4bf8b27c0d66ef2fce72e133db777349',
                  iosKey: '173b139f4b0710330132c496bf45ece1',
                  webKey: '1f67dc45ef1c30121049a15d27edf12e',
                ),
                initialCameraPosition: CameraPosition(target: _position ?? _defaultPosition, zoom: 15),
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (AMapController controller) {
                  debugPrint('AMap created');
                  setState(() {
                    _amapController = controller;
                    _isMapReady = true;
                  });
                },
              );
            }),
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
          label: isRunning ? '暂停' : '继续',
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
