import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../utils/device_utils.dart';
import '../../services/api_service.dart';
import '../../services/database_helper.dart';
import '../../models/message.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';

class RouteFeedbackDetailPage extends StatefulWidget {
  final Map<String, dynamic> feedback;

  const RouteFeedbackDetailPage({super.key, required this.feedback});

  @override
  State<RouteFeedbackDetailPage> createState() => _RouteFeedbackDetailPageState();
}

class _RouteFeedbackDetailPageState extends State<RouteFeedbackDetailPage> {
  bool _isSimulator = false;
  int _currentPhotoIndex = 0;
  int _viewCount = 0;
  int _confirmCount = 0;
  int _forwardCount = 0;
  bool _isConfirmed = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;
  List<Map<String, dynamic>> _comments = [];
  late Map<String, dynamic> _currentFeedback;
  bool _isLoadingLatest = true;

  @override
  void initState() {
    super.initState();
    _currentFeedback = Map<String, dynamic>.from(widget.feedback);
    _checkDevice();
    _initStatsAndComments();
    _fetchLatestFeedback();
  }

  Future<void> _fetchLatestFeedback() async {
    // 优先使用 remote_id，如果没有则尝试 id
    final id = _currentFeedback['remote_id'] ?? _currentFeedback['id'];
    if (id == null) {
      setState(() => _isLoadingLatest = false);
      return;
    }

    try {
      final resp = await ApiService().get('/messages/feedbacks/$id');
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data;
        setState(() {
          _currentFeedback['view_count'] = data['view_count'];
          _currentFeedback['confirm_count'] = data['confirm_count'];
          _currentFeedback['forward_count'] = data['forward_count'] ?? (_currentFeedback['forward_count'] ?? 0);
          _currentFeedback['content'] = data['content'];
          _currentFeedback['photos'] = data['photos'] is List ? jsonEncode(data['photos']) : data['photos'];
          _currentFeedback['user_name'] = data['user_name'];
          _currentFeedback['user_avatar'] = data['user_avatar'];
          
          _viewCount = data['view_count'] ?? 0;
          _confirmCount = data['confirm_count'] ?? 0;
          _forwardCount = data['forward_count'] ?? _forwardCount;
          _isLoadingLatest = false;
        });

        // Sync back to local DB
        try {
          final localId = _currentFeedback['local_id'];
          final updateData = Map<String, dynamic>.from(_currentFeedback);
          if (localId != null) {
            updateData['local_id'] = localId; // Ensure local_id is preserved for update
          }
          await DatabaseHelper().saveFeedback(updateData);
        } catch (e) {
          debugPrint('Failed to sync latest feedback to local DB: $e');
        }
      } else {
        setState(() => _isLoadingLatest = false);
      }
    } catch (e) {
      debugPrint('Failed to fetch latest feedback: $e');
      setState(() => _isLoadingLatest = false);
    }
  }

  Future<void> _checkDevice() async {
    final isSim = await DeviceUtils.isSimulator();
    if (mounted) {
      setState(() {
        _isSimulator = isSim;
      });
    }
  }

  Future<void> _initStatsAndComments() async {
    // 优先使用 remote_id，如果没有则尝试 id
    final id = _currentFeedback['remote_id'] ?? _currentFeedback['id'];
    if (id == null) return;

    _viewCount = _currentFeedback['view_count'] as int? ?? 0;
    _confirmCount = _currentFeedback['confirm_count'] as int? ?? 0;
    _forwardCount = _currentFeedback['forward_count'] as int? ?? 0;

    // 浏览+1（远端）
    try {
      final resp =
          await ApiService().post('/messages/feedback/$id/view', data: {});
      if (resp.statusCode == 200 && resp.data != null) {
        final v = resp.data['view_count'] as int?;
        if (v != null) {
          setState(() {
            _viewCount = v;
          });
        }
      }
    } catch (e) {
      debugPrint('mark view failed: $e');
    }

    // 确认状态
    try {
      final resp = await ApiService()
          .get('/messages/feedback/$id/confirm-status');
      if (resp.statusCode == 200 && resp.data != null) {
        setState(() {
          _isConfirmed = resp.data['confirmed'] == true;
          _confirmCount = resp.data['confirm_count'] as int? ?? _confirmCount;
        });
      }
    } catch (e) {
      debugPrint('load confirm status failed: $e');
    }

    // 评论列表
    try {
      final resp = await ApiService()
          .get('/messages/feedback/$id/comments');
      if (resp.statusCode == 200 && resp.data is List) {
        final List<Map<String, dynamic>> serverComments = 
            (resp.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
            
        setState(() {
          _comments = serverComments;
        });

        // Sync comments to local db
        for (var c in serverComments) {
          c['feedback_id'] = id;
          c['remote_id'] = c['id'];
          c.remove('id');
          await DatabaseHelper().saveFeedbackComment(c);
        }
      } else {
        // Fallback to local db if offline or server error
        final localComments = await DatabaseHelper().getFeedbackComments(id);
        setState(() {
          _comments = localComments;
        });
      }
    } catch (e) {
      debugPrint('load comments failed: $e');
      // Fallback to local db
      final localComments = await DatabaseHelper().getFeedbackComments(id);
      setState(() {
        _comments = localComments;
      });
    }

    // 将最新的浏览/确认计数回写本地，方便“我的路况”列表展示最新数据
    try {
      final map = Map<String, dynamic>.from(_currentFeedback)
        ..['view_count'] = _viewCount
        ..['confirm_count'] = _confirmCount
        ..['forward_count'] = _forwardCount;
      await DatabaseHelper().saveFeedback(map);
    } catch (e) {
      debugPrint('sync feedback stats to local failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = _currentFeedback;
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
    
    // Handle different field names for SOS vs Feedback
    String typeStr = feedback['type'] as String? ?? 'other';
    // If it's an SOS alert (might not have type field or type is different)
    if (feedback.containsKey('status') && feedback.containsKey('message')) {
       typeStr = 'sos';
    }

    final typeKey = typeStr;
    final typeInfo = typeMap[typeKey] ?? typeMap['other']!;
    final color = typeInfo['color'] as Color;
    
    // Parse time
    final createdTime = DateTime.fromMillisecondsSinceEpoch(feedback['created_at']);
    final dateStr = '${createdTime.year}-${createdTime.month}-${createdTime.day} ${createdTime.hour}:${createdTime.minute}';

    // Parse photos
    List<String> photos = [];
    final rawPhotos = feedback['photos'];
    if (rawPhotos != null) {
      try {
        if (rawPhotos is String && rawPhotos.isNotEmpty) {
           photos = List<String>.from(jsonDecode(rawPhotos));
        } else if (rawPhotos is List) {
           photos = List<String>.from(rawPhotos);
        }
      } catch (e) {
        // ignore error
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('路况详情'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Placeholder or Photos
            if (photos.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPhotoIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        String url = photos[index];
                        if (!url.startsWith('http')) {
                          url = 'http://8.136.205.255:8000$url';
                        }
                        return GestureDetector(
                          onTap: () {
                            // Prepare full URLs for viewer
                            final fullUrls = photos.map((p) {
                              if (!p.startsWith('http')) {
                                return 'http://8.136.205.255:8000$p';
                              }
                              return p;
                            }).toList();
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageViewerPage(
                                  imageUrls: fullUrls,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentPhotoIndex + 1}/${photos.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 200,
                color: Colors.grey[200],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 48, color: color),
                      const SizedBox(height: 8),
                      Text(
                        _isSimulator ? '模拟器不支持地图显示' : '暂无照片/地图数据',
                         style: TextStyle(color: color)
                      ),
                    ],
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(typeInfo['icon'] as IconData, size: 16, color: color),
                            const SizedBox(width: 4),
                            Text(
                              typeInfo['label'] as String,
                              style: TextStyle(color: color, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // User Info
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final avatar = feedback['avatar'] ??
                              feedback['user_avatar'] ??
                              feedback['user_avatar'] ??
                              '';
                          if (avatar is String && avatar.isNotEmpty) {
                            String url = avatar;
                            if (!url.startsWith('http')) {
                              url = 'http://8.136.205.255:8000$url';
                            }
                            return CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  CachedNetworkImageProvider(url),
                              backgroundColor: Colors.grey[200],
                            );
                          }
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[200],
                            child: Icon(Icons.person,
                                size: 18, color: Colors.grey[400]),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        feedback['user_name'] ?? '匿名用户',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Content
                  Text(
                    feedback['content'] ?? feedback['message'] ?? '无内容',
                    style: const TextStyle(fontSize: 18, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  
                  // Address
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          feedback['address'] ?? '未知位置',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Stats（浏览 / 确认 / 评论），确认通过点击拇指图标触发
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(
                        Icons.remove_red_eye,
                        '$_viewCount',
                        '浏览',
                      ),
                      _buildStat(
                        Icons.thumb_up,
                        '$_confirmCount',
                        '确认',
                        color: _isConfirmed ? Colors.green : Colors.grey,
                        onTap: () async {
                          if (_isConfirmed) return;
                          final id = feedback['id'] as int?;
                          if (id == null) return;
                          try {
                            final resp = await ApiService().post(
                                '/messages/feedback/$id/confirm',
                                data: {});
                            if (resp.statusCode == 200 &&
                                resp.data != null) {
                              setState(() {
                                _isConfirmed = true;
                                _confirmCount = resp
                                        .data['confirm_count']
                                    as int? ??
                                    _confirmCount + 1;
                              });
                            }
                          } catch (e) {
                            debugPrint('confirm feedback failed: $e');
                          }
                        },
                      ),
                      _buildStat(
                        Icons.comment,
                        '${_comments.length}',
                        '评论',
                      ),
                      _buildStat(
                        Icons.share,
                        '$_forwardCount',
                        '转发',
                        onTap: _openForwardSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Comments Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '评论 (${_comments.length})',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('暂无评论',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    Column(
                      children: _comments.map((c) {
                        final name = c['user_name'] ?? '匿名用户';
                        final avatar = c['user_avatar'] as String?;
                        final content = c['content'] ?? '';
                        final ts = c['created_at'] as int? ?? 0;
                        final dt =
                            DateTime.fromMillisecondsSinceEpoch(ts);
                        final timeStr =
                            '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: avatar != null && avatar.isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? Icon(Icons.person, size: 18, color: Colors.grey[400])
                                : null,
                          ),
                          title: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(content),
                          trailing: Text(
                            timeStr,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),

                  // Comment input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: '说点什么...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _isPostingComment
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        onPressed: _isPostingComment
                            ? null
                            : () async {
                                final text =
                                    _commentController.text.trim();
                                if (text.isEmpty) return;
                                
                                // ID 取值逻辑：优先取 remote_id，如果没有则尝试 id
                                final id = _currentFeedback['remote_id'] ?? _currentFeedback['id'];
                                if (id == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('错误：无法获取路况ID，无法评论')),
                                  );
                                  return;
                                }
                                
                                setState(() => _isPostingComment = true);
                                try {
                                  final resp = await ApiService().post(
                                    '/messages/feedback/$id/comments',
                                    data: {'content': text},
                                  );
                                  if (resp.statusCode == 200 &&
                                      resp.data != null) {
                                    final newComment = Map<String, dynamic>.from(resp.data);
                                    setState(() {
                                      _comments.insert(0, newComment);
                                      _commentController.clear();
                                    });
                                    
                                    // Save to local db
                                    newComment['feedback_id'] = id;
                                    newComment['remote_id'] = newComment['id'];
                                    newComment.remove('id');
                                    await DatabaseHelper().saveFeedbackComment(newComment);
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('评论失败: ${resp.statusMessage}')),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('post comment failed: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('发送失败: $e')),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() =>
                                        _isPostingComment = false);
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    IconData icon,
    String value,
    String label, {
    Color? color,
    VoidCallback? onTap,
  }) {
    final iconColor = color ?? Colors.grey;
    final content = Column(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style:
                const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: content,
      ),
    );
  }

  Future<void> _openForwardSheet() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    final userId = auth.user?.id;
    if (userId == null) return;

    await msgProvider.fetchContacts(userId);
    await msgProvider.syncTempFriendships(userId);
    final friendContacts = msgProvider.contacts;
    final temps = await DatabaseHelper().getTempFriendships(userId);

    if (!mounted) return;
    int tab = 0; // 0 好友，1 临时会话
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('转发给', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('好友'),
                    selected: tab == 0,
                    onSelected: (_) => setModalState(() => tab = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('临时会话'),
                    selected: tab == 1,
                    onSelected: (_) => setModalState(() => tab = 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: tab == 0 ? friendContacts.length : temps.length,
                  itemBuilder: (_, i) {
                    final partnerId = tab == 0
                        ? friendContacts[i].id
                        : (temps[i]['partner_id'] as int? ?? 0);
                    final name = tab == 0
                        ? friendContacts[i].nickname
                        : (temps[i]['partner_name']?.toString() ?? '用户$partnerId');
                    final avatar = tab == 0
                        ? (friendContacts[i].avatar ?? '')
                        : (temps[i]['partner_avatar']?.toString() ?? '');
                    final preview = tab == 0
                        ? (friendContacts[i].lastMessage ?? '暂无消息')
                        : ((temps[i]['last_message']?.toString().isNotEmpty ?? false)
                            ? temps[i]['last_message'].toString()
                            : '暂无消息');
                    final ts = tab == 0
                        ? (friendContacts[i].lastMessageTime ?? 0)
                        : (temps[i]['last_timestamp'] as int? ?? 0);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: avatar.isNotEmpty
                            ? CachedNetworkImageProvider(
                                avatar.startsWith('http') ? avatar : 'http://8.136.205.255:8000$avatar',
                              )
                            : null,
                        child: avatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
                      ),
                      title: Text(name),
                      subtitle: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        _formatForwardItemTime(ts),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _forwardToUser(
                          receiverId: partnerId,
                          isFriendConversation: tab == 0,
                          receiverName: name,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatForwardItemTime(int ts) {
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(thatDay).inDays;
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return hm;
    if (diff == 1) return '昨天';
    return '${dt.month}/${dt.day}';
  }

  Future<void> _forwardToUser({
    required int receiverId,
    required bool isFriendConversation,
    required String receiverName,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    final userId = auth.user?.id;
    if (userId == null) return;

    final feedbackId = _currentFeedback['remote_id'] ?? _currentFeedback['id'];
    final payload = {
      'type': 'feedback_card',
      'feedback_id': feedbackId,
      'feedback_type': _currentFeedback['type'],
      'title': '路况转发',
      'content': _currentFeedback['content'] ?? '',
      'address': _currentFeedback['address'] ?? '未知位置',
      'user_name': _currentFeedback['user_name'] ?? '匿名用户',
      'user_avatar': _currentFeedback['user_avatar'],
      'view_count': _viewCount,
      'confirm_count': _confirmCount,
      'forward_count': _forwardCount,
      'created_at': _currentFeedback['created_at'],
      'photos': _currentFeedback['photos'],
    };

    try {
      await msgProvider.sendMessage(
        userId,
        receiverId,
        jsonEncode(payload),
        type: 'feedback_card',
        isFriendConversation: isFriendConversation,
      );

      if (feedbackId != null) {
        final resp = await ApiService().post('/messages/feedback/$feedbackId/forward', data: {});
        if (resp.statusCode == 200 && resp.data != null) {
          setState(() {
            _forwardCount = resp.data['forward_count'] as int? ?? (_forwardCount + 1);
            _currentFeedback['forward_count'] = _forwardCount;
          });
          final map = Map<String, dynamic>.from(_currentFeedback)..['forward_count'] = _forwardCount;
          await DatabaseHelper().saveFeedback(map);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已转发给 $receiverName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转发失败: $e')),
        );
      }
    }
  }
}

class ImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white, size: 50),
                  ),
                ),
              );
            },
          ),
          
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
          
          // Counter
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_currentIndex + 1} / ${widget.imageUrls.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
