import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';

class ChatPage extends StatefulWidget {
  final String title;
  final String? avatar;
  final int partnerId;
  final int? hikeId; // Add hikeId for history mode

  const ChatPage({
    super.key, 
    required this.title, 
    this.avatar,
    required this.partnerId,
    this.hikeId,
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
      hikeId: widget.hikeId, // Pass hikeId if present
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
                      : 'http://114.55.148.245:8000${widget.avatar!}'
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
                              Text(
                                msg.content,
                                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                              ),
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
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
