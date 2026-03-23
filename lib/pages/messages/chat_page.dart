import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import 'dart:convert';
import 'sos_event_detail_page.dart';

class ChatPage extends StatefulWidget {
  final String title;
  final String? avatar;
  final int partnerId;
  final int? hikeId; // Keep for compatibility
  final DateTime? startTime;
  final DateTime? endTime;
  /// 是否为好友会话：true 时读写 friend_messages 与 /friend-messages；false 为临时会话（messages）。
  final bool isFriendConversation;

  const ChatPage({
    super.key,
    required this.title,
    this.avatar,
    required this.partnerId,
    this.hikeId,
    this.startTime,
    this.endTime,
    this.isFriendConversation = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  // 只有当用户仍在接近底部时，才自动滚动到底部；否则用户向上浏览历史消息会被打断
  bool _shouldAutoScrollToBottom = true;
  // 用户正在拖动列表时，禁止自动回到底部
  bool _isUserInteracting = false;

  late MessageProvider _msgProvider;

  @override
  void initState() {
    super.initState();
    _loadMessages(autoScrollToBottom: true);
    _scrollController.addListener(_handleScroll);
    
    // Listen for updates from MessageProvider (which polls server)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _msgProvider = Provider.of<MessageProvider>(context, listen: false);
        _msgProvider.addListener(_onMessageUpdate);
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (_isUserInteracting) {
      _shouldAutoScrollToBottom = false;
      return;
    }
    final atBottom = (max - current) <= 20; // 更严格阈值：接近底部才自动滚动
    _shouldAutoScrollToBottom = atBottom;
  }

  @override
  void dispose() {
    // Remove listener
    _msgProvider.removeListener(_onMessageUpdate);
    _messageController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessageUpdate() {
    if (mounted) {
      // 轮询更新时：只有用户仍接近底部才自动滚动到底部，避免“无法向上滑动/被强制回到底部”
      _loadMessages(
        autoScrollToBottom: _shouldAutoScrollToBottom && !_isUserInteracting,
      );
    }
  }

  Future<void> _loadMessages({required bool autoScrollToBottom}) async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    
    if (authProvider.user == null) return;

    final int prevLen = _messages.length;
    final msgs = await msgProvider.getMessagesForContact(
      authProvider.user!.id,
      widget.partnerId,
      hikeId: widget.hikeId,
      startTime: widget.startTime,
      endTime: widget.endTime,
      isFriendConversation: widget.isFriendConversation,
    );

    if (mounted) {
      // 若远端拉下来的消息“看起来没变”，就跳过 setState，避免打断滚动手势
      final bool looksSameAsBefore = prevLen == msgs.length &&
          prevLen > 0 &&
          _messages.isNotEmpty &&
          msgs.first.id == _messages.first.id &&
          msgs.last.id == _messages.last.id;
      if (looksSameAsBefore) return;

      final bool isAppending = prevLen > 0 && msgs.length > prevLen;
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      
      // Scroll to bottom after loading
      // 只有在“新增消息追加”时才允许自动回到底部
      if (autoScrollToBottom && _messages.isNotEmpty && (isAppending || prevLen == 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    final content = _messageController.text;
    _messageController.clear();
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      await msgProvider.sendMessage(
        authProvider.user!.id,
        widget.partnerId,
        content,
        isFriendConversation: widget.isFriendConversation,
      );
      if (mounted) {
        await _loadMessages(autoScrollToBottom: true);
      }
    }
  }

  Widget _buildMessageContent(Message msg, bool isMe) {
    if (msg.type == 'sos') {
      try {
        final data = jsonDecode(msg.content);
        return GestureDetector(
          onTap: () {
            final fakeEvent = {
              'message_json': msg.content,
              'user_id': msg.senderId,
              'created_at': msg.timestamp,
              'photos_json': data['photos'] != null ? jsonEncode(data['photos']) : null,
            };
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SOSEventDetailPage(event: fakeEvent),
              ),
            );
          },
          child: _buildSOSCard(data),
        );
      } catch (e) {
        return Text(
          msg.content,
          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
        );
      }
    }
    
    return Text(
      msg.content,
      style: TextStyle(color: isMe ? Colors.white : Colors.black87),
    );
  }

  Widget _buildSOSCard(Map<String, dynamic> data) {
    final dangerType = data['danger_label'] ?? '未知危险';
    final safetyStatus = data['safety_status'] ?? 0;
    final urgentLabels = (data['urgent_labels'] as List?)?.join('、') ?? '无';
    final description = data['description'] ?? '';
    final address = data['address'] ?? '';
    final time = data['time'] ?? '';
    final lat = data['latitude'];
    final lng = data['longitude'];

    Color statusColor;
    String statusText;
    if (safetyStatus == 2) {
      statusColor = Colors.green;
      statusText = '已脱险';
    } else if (safetyStatus == 1) {
      statusColor = Colors.orange;
      statusText = '暂时安全';
    } else {
      statusColor = Colors.red;
      statusText = '仍危险';
    }

    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'SOS 求救信号',
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          
          // Info Rows
          _buildInfoRow('危险类型', dangerType, isBold: true),
          const SizedBox(height: 4),
          _buildInfoRow('安全状态', statusText, color: statusColor, isBold: true),
          const SizedBox(height: 4),
          _buildInfoRow('急需物品', urgentLabels),
          
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('具体描述:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(description, style: const TextStyle(fontSize: 14)),
          ],
          
          const Divider(height: 16),
          
          // Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(address, style: const TextStyle(fontSize: 12)),
                    if (lat != null && lng != null)
                      Text(
                        '【GCJ02】${lat.toStringAsFixed(6)}°N, ${lng.toStringAsFixed(6)}°E',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    if (time.isNotEmpty)
                      Text(
                        '更新时间: $time',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color ?? Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id ?? 0;
    final currentUserAvatar = authProvider.user?.avatar ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.avatar != null && widget.avatar!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: CachedNetworkImageProvider(
                    widget.avatar!.startsWith('http') 
                      ? widget.avatar! 
                      : 'http://8.136.205.255:8000${widget.avatar!}'
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    widget.title.isNotEmpty ? widget.title.substring(0, 1) : 'U',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ),
            Text(widget.title),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      // 用户开始手势滚动时，禁止自动回到底部
                      if (notification is ScrollStartNotification) {
                        _isUserInteracting = true;
                      } else if (notification is ScrollEndNotification) {
                        _isUserInteracting = false;
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.senderId == currentUserId;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe) ...[
                                if (widget.avatar != null && widget.avatar!.isNotEmpty)
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: CachedNetworkImageProvider(
                                      widget.avatar!.startsWith('http') 
                                        ? widget.avatar! 
                                        : 'http://8.136.205.255:8000${widget.avatar!}'
                                    ),
                                  )
                                else
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.orange.shade100,
                                    child: Text(
                                      widget.title.isNotEmpty ? widget.title.substring(0, 1) : 'U',
                                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                              ],
                              
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                  decoration: BoxDecoration(
                                    color: isMe ? const Color(0xFF2E7D32) : Colors.grey.shade200,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                                      bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildMessageContent(msg, isMe),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(msg.timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
      
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                if (currentUserAvatar.isNotEmpty)
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: CachedNetworkImageProvider(
                                      currentUserAvatar.startsWith('http') 
                                        ? currentUserAvatar 
                                        : 'http://8.136.205.255:8000$currentUserAvatar'
                                    ),
                                  )
                                else
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.blue.shade100,
                                    child: const Icon(Icons.person, size: 20, color: Colors.blue),
                                  ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (widget.hikeId == null) // Only show input if not in history mode
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '发送消息...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2E7D32)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(date.year, date.month, date.day);
    
    final diff = today.difference(thatDay).inDays;
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    if (diff == 0) {
      return '今天 $timeStr';
    } else if (diff == 1) {
      return '昨天 $timeStr';
    } else if (diff == 2) {
      return '前天 $timeStr';
    } else {
      return '${date.month}月${date.day}日 $timeStr';
    }
  }
}
