import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import 'dart:convert';

class ChatPage extends StatefulWidget {
  final String title;
  final String? avatar;
  final int partnerId;
  final int? hikeId; // Keep for compatibility
  final DateTime? startTime;
  final DateTime? endTime;

  const ChatPage({
    super.key, 
    required this.title, 
    this.avatar,
    required this.partnerId,
    this.hikeId,
    this.startTime,
    this.endTime,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    
    // Listen for updates from MessageProvider (which polls server)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MessageProvider>(context, listen: false);
      provider.addListener(_onMessageUpdate);
    });
  }

  @override
  void dispose() {
    // Remove listener
    final provider = Provider.of<MessageProvider>(context, listen: false);
    provider.removeListener(_onMessageUpdate);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMessageUpdate() {
    if (mounted) {
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    
    if (authProvider.user == null) return;

    final msgs = await msgProvider.getMessagesForContact(
      authProvider.user!.id, 
      widget.partnerId,
      hikeId: widget.hikeId,
      startTime: widget.startTime,
      endTime: widget.endTime,
    );

    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      
      // Scroll to bottom after loading
      if (_messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
        content
      );
      // Provider will notify listeners, which calls _onMessageUpdate -> _loadMessages
      // But we can also manually refresh to be instant
      _loadMessages();
    }
  }

  Widget _buildMessageContent(Message msg, bool isMe) {
    if (msg.type == 'sos') {
      try {
        final data = jsonDecode(msg.content);
        return _buildSOSCard(data);
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.avatar != null)
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
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == currentUserId;
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
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
                      );
                    },
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
