import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:amap_flutter/amap_flutter.dart' as amap;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sos_button.dart';
import 'route_feedback_page.dart';
import 'ask_question_page.dart';
import 'hiking_history_page.dart';

/// HikingMapPage - 徒步地图页面
/// 应用的核心页面，显示高德地图，支持实时定位、徒步轨迹记录等功能
class HikingMapPage extends StatefulWidget {
  const HikingMapPage({super.key});

  @override
  State<HikingMapPage> createState() => _HikingMapPageState();
}

class _HikingMapPageState extends State<HikingMapPage> {
  // 地图控制器，用于控制地图移动、添加标记等操作
  amap.AMapController? _mapController;
  // 地图是否准备就绪
  bool _isMapReady = false;
  // 是否正在初始化（显示加载界面）
  bool _isInitializing = true;
  // 错误信息（初始化失败时显示）
  String? _errorMessage;

  // 当前用户位置
  amap.Position? _position;
  // 徒步状态：IDLE（空闲）、RUNNING（进行中）、PAUSED（暂停）
  String _hikingState = 'IDLE';
  // 是否激活SOS模式
  bool _isSOSActive = false;

  // 计时器相关变量
  Timer? _timer; // 定时器，用于更新徒步时长
  DateTime? _startTime; // 徒步开始时间
  Duration _accumulatedDuration = Duration.zero; // 累计时间（暂停时保存）
  Duration _currentDuration = Duration.zero; // 当前显示的时间

  // 轨迹相关变量
  final List<amap.Position> _pathPoints = []; // 徒步路径点列表
  amap.Marker? _positionMarker; // 当前位置标记
  final List<amap.Marker> _routeMarkers = []; // 路径标记列表
  final List<amap.Marker> _markers = []; // 所有标记列表
  bool _isTrackingLocation = false; // 是否正在追踪位置

  // 位置更新流订阅
  StreamSubscription<Position>? _locationSubscription;

  /// initState - 组件初始化
  /// 延迟初始化，避免在widget未完全构建时崩溃
  @override
  void initState() {
    super.initState();
    // 延迟执行初始化，确保在组件构建完成后调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  /// _initialize - 初始化方法
  /// 1. 初始化高德地图 2. 请求定位权限 3. 初始化定位服务
  Future<void> _initialize() async {
    try {
      // 初始化高德地图，配置API密钥
      await amap.AMapFlutter.init(
        apiKey: amap.ApiKey(
          androidKey: '4bf8b27c0d66ef2fce72e133db777349',
          iosKey: '173b139f4b0710330132c496bf45ece1',
          webKey: '1f67dc45ef1c30121049a15d27edf12e',
        ),
        agreePrivacy: true, // 同意隐私协议
      );
      debugPrint('AMap initialized successfully');
    } catch (e) {
      debugPrint('AMap init error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '地图初始化失败: $e';
          _isInitializing = false;
        });
      }
      return;
    }

    if (!mounted) return;

    try {
      // 请求位置权限
      final status = await Permission.location.request();
      if (status.isGranted && mounted) {
        _initLocation(); // 初始化定位服务
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
  /// 启动位置监听，获取实时位置更新
  void _initLocation() async {
    if (!mounted) return;
    try {
      // 启动位置更新流，持续监听位置变化
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, // 高精度定位
              distanceFilter: 5, // 移动5米以上才更新
            ),
          ).listen(
            (Position position) {
              debugPrint(
                'Location stream update: ${position.latitude}, ${position.longitude}',
              );
              _updateLocation(
                amap.Position(
                  latitude: position.latitude,
                  longitude: position.longitude,
                ),
              );
            },
            onError: (error) {
              debugPrint('Location stream error: $error');
            },
          );

      // 获取上次已知位置（缓存）
      final position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        debugPrint(
          'Initial position from cache: ${position.latitude}, ${position.longitude}',
        );
        _updateLocation(
          amap.Position(
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  /// _updateLocation - 更新位置
  /// 参数：newPos 新的位置坐标
  /// 更新当前位置，并在徒步模式下添加到路径点
  void _updateLocation(amap.Position newPos) {
    setState(() {
      _position = newPos;
      // 徒步模式下添加路径点
      if (_hikingState == 'RUNNING') {
        _pathPoints.add(newPos);
      }
    });

    // 徒步模式下移动相机跟随位置
    if (_hikingState == 'RUNNING' &&
        _position != null &&
        _mapController != null) {
      _mapController?.moveCamera(
        amap.CameraPosition(position: _position!, zoom: 17),
      );
    }
  }

  /// _locateToCurrentPosition - 定位到当前位置
  /// 点击定位按钮时调用，获取当前位置并移动地图到该位置
  Future<void> _locateToCurrentPosition() async {
    debugPrint('Location button pressed, starting location...');

    // 检查地图控制器是否可用
    if (_mapController == null) {
      debugPrint('Map controller is null, cannot locate');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('地图未就绪')));
      }
      return;
    }

    // 检查位置权限
    var status = await Permission.location.status;
    debugPrint('Location permission status: $status');
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        debugPrint('Location permission denied');
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('需要位置权限才能定位')));
        }
        return;
      }
    }

    // 检查定位服务是否开启
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('Location service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请开启设备定位服务')));
      }
      return;
    }

    // 显示定位中提示
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在定位...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      // 使用Geolocator获取当前位置
      Position? position;
      try {
        // 尝试获取实时位置
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).timeout(const Duration(seconds: 10));
        debugPrint(
          'Got fresh position: ${position.latitude}, ${position.longitude}',
        );
      } catch (e) {
        debugPrint('getCurrentPosition error: $e, trying last known position');
        // 获取失败时尝试获取缓存位置
        position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          debugPrint(
            'Got last known position: ${position.latitude}, ${position.longitude}',
          );
        }
      }

      // 如果无法获取任何位置
      if (position == null) {
        debugPrint('Failed to get any position');
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('无法获取位置，请检查GPS设置')));
        }
        return;
      }

      // 创建AMap位置对象
      final currentPosition = amap.Position(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      debugPrint(
        'Position obtained: ${currentPosition.latitude}, ${currentPosition.longitude}',
      );

      // 更新状态
      setState(() {
        _position = currentPosition;
        _isTrackingLocation = true;

        // 清除旧标记，添加新的当前位置标记
        _markers.clear();
        final marker = amap.Marker(
          id: 'current_location',
          position: currentPosition,
        );
        _markers.add(marker);
        _positionMarker = marker;
      });

      debugPrint('State updated, moving camera...');

      // 移动地图到当前位置
      _mapController?.moveCamera(
        amap.CameraPosition(position: currentPosition, zoom: 17),
      );
      debugPrint('Camera moved to position');

      // 添加标记到地图
      final marker = amap.Marker(
        id: 'current_location',
        position: currentPosition,
      );
      _mapController?.addMarker(marker);
      debugPrint('Marker added to map');

      // 显示定位成功对话框
      debugPrint('Location successful, showing result');
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('定位成功'),
            content: Text(
              '当前位置: ${currentPosition.latitude.toStringAsFixed(4)}, ${currentPosition.longitude.toStringAsFixed(4)}',
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
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('定位失败: $e')));
      }
    }
  }

  /// dispose - 组件销毁
  /// 清理计时器和位置订阅
  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// _startTimer - 开始计时
  /// 启动定时器更新徒步时长显示
  void _startTimer() {
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        final now = DateTime.now();
        _currentDuration = _accumulatedDuration + now.difference(_startTime!);
      });
    });
  }

  /// _pauseTimer - 暂停计时
  /// 暂停徒步计时，保存当前累计时间
  void _pauseTimer() {
    _timer?.cancel();
    if (_startTime != null) {
      _accumulatedDuration += DateTime.now().difference(_startTime!);
    }
    _startTime = null;
  }

  /// _resumeTimer - 恢复计时
  /// 继续徒步计时
  void _resumeTimer() {
    _startTimer();
  }

  /// _stopTimer - 停止计时
  /// 结束徒步，重置所有计时数据
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
  /// 将Duration转换为 HH:MM:SS 格式字符串
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // Web端显示提示信息（amap_flutter在Web端有兼容性问题）
    if (kIsWeb) {
      return Scaffold(
        body: Stack(
          children: [
            Container(
              color: Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      '地图功能在Web端暂不可用',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请使用Android或iOS App',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
            // 顶部信息栏
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: _buildTopInfoBar(),
            ),
            // 底部操作栏
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomActionBar(),
            ),
          ],
        ),
      );
    }

    // 显示加载界面
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF2E7D32)),
              SizedBox(height: 16),
              Text('正在加载地图...'),
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
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  '出错了',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isInitializing = true;
                    });
                    _initialize();
                  },
                  child: Text('重试'),
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
          // 地图区域
          Positioned.fill(
            child: Container(
              color: Colors.grey[200],
              child: SafeArea(
                bottom: false,
                child: amap.AMapFlutter(
                  // 设置地图类型为标准地图
                  mapType: amap.MapType.standard,
                  // 初始相机位置（北京）
                  initCameraPosition: amap.CameraPosition(
                    position: amap.Position(
                      latitude: 39.9042,
                      longitude: 116.4074,
                    ),
                    zoom: 15,
                  ),
                  // 地图创建完成回调
                  onMapCreated: (controller) {
                    debugPrint(
                      'AMap: onMapCreated, mapId: ${controller.mapId}',
                    );
                    _mapController = controller;
                    if (mounted) {
                      setState(() {
                        _isMapReady = true;
                      });
                    }
                  },
                  // 地图完全加载回调
                  onMapCompleted: () {
                    debugPrint(
                      'AMap: onMapCompleted - Map loaded successfully',
                    );
                    if (_position != null) {
                      _mapController?.moveCamera(
                        amap.CameraPosition(position: _position!, zoom: 17),
                      );
                    }
                  },
                ),
              ),
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
  /// 显示GPS状态、徒步时长或准备出发提示
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
                    fontFeatures: [FontFeature.tabularFigures()],
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
  /// 包含图层、定位、群组、反馈、帮助等按钮
  Widget _buildRightToolbar() {
    return Column(
      children: [
        // 图层按钮
        _buildToolButton(Icons.layers, () {}),
        const SizedBox(height: 12),
        // 定位按钮
        _buildToolButton(Icons.my_location, () {
          _locateToCurrentPosition();
        }),
        const SizedBox(height: 12),
        // 群组按钮（带徽章）
        _buildToolButton(Icons.group, () {}, badgeCount: 3),
        const SizedBox(height: 12),
        // 路线反馈按钮
        _buildToolButton(Icons.add_comment, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RouteFeedbackPage()),
          );
        }),
        const SizedBox(height: 12),
        // 帮助按钮
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
  /// icon: 图标, onTap: 点击回调, badgeCount: 徽章数量
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
            // 显示徽章
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
  /// 根据徒步状态显示开始/暂停/继续/结束按钮
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
            _routeMarkers.clear();
            _isTrackingLocation = true;
            if (_position != null) {
              _pathPoints.add(_position!);
              // 添加起点标记
              final marker = amap.Marker(
                id: 'route_start',
                position: _position!,
              );
              _routeMarkers.add(marker);
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
  /// 显示暂停/继续和结束按钮
  Widget _buildActiveActions() {
    final isRunning = _hikingState == 'RUNNING';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 暂停/继续按钮
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
        const SOSButton(), // SOS按钮
        // 结束按钮
        _buildCircleAction(
          icon: Icons.stop,
          label: '结束',
          color: Colors.grey,
          onTap: () {
            _showEndHikingDialog();
          },
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
              onPressed: () {
                setState(() {
                  _isSOSActive = false;
                });
              },
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
