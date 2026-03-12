import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:solitary/services/api_service.dart';
import 'package:solitary/services/database_helper.dart';

import 'chat_page.dart';

class SOSEventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const SOSEventDetailPage({super.key, required this.event});

  @override
  State<SOSEventDetailPage> createState() => _SOSEventDetailPageState();
}

class _SOSEventDetailPageState extends State<SOSEventDetailPage> {
  late final Map<String, dynamic> _messageData;
  late final List<dynamic> _recipients;
  late final List<String> _photoBase64List;
  List<Map<String, dynamic>> _recipientCards = [];

  @override
  void initState() {
    super.initState();
    _messageData = _safeJson(widget.event['message_json']) ?? {};
    _recipients = _safeJson(widget.event['recipients_json']) ?? [];
    final photosJson = _safeJson(widget.event['photos_json']);
    _photoBase64List = (photosJson is List)
        ? photosJson.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    _loadRecipients();
  }

  dynamic _safeJson(dynamic value) {
    try {
      if (value == null) return null;
      if (value is String) return jsonDecode(value);
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRecipients() async {
    final List<Map<String, dynamic>> loaded = [];
    final int meId = int.tryParse('${widget.event['user_id'] ?? 0}') ?? 0;
    final int eventTs = int.tryParse('${widget.event['created_at'] ?? 0}') ?? 0;
    final db = await DatabaseHelper().database;

    for (final r in _recipients) {
      final id = (r is Map && r['id'] != null) ? int.tryParse('${r['id']}') : null;
      if (id == null) continue;

      var contact = await DatabaseHelper().getContact(id);
      String name = contact?['nickname'] ?? (r is Map ? (r['nickname'] ?? '') : '') ?? '';
      String avatar = contact?['avatar'] ?? '';
      if (name.toString().trim().isEmpty) name = '用户 $id';

      if (contact == null) {
        try {
          final resp = await ApiService().get('/users/$id');
          if (resp.statusCode == 200 && resp.data != null) {
            name = resp.data['nickname'] ?? name;
            avatar = resp.data['avatar'] ?? avatar;
          }
        } catch (_) {}
      }

      loaded.add({
        'id': id,
        'name': name,
        'avatar': avatar,
        'hasReply': false,
        'lastMsg': '',
        'lastTs': 0,
      });

      // 查询该收件人与我之间，在本次 SOS 之后的最近一条消息，用来判断“是否回复”
      if (meId != 0 && eventTs != 0) {
        try {
          final rows = await db.query(
            'messages',
            where:
                '((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)) AND timestamp >= ?',
            whereArgs: [meId, id, id, meId, eventTs],
            orderBy: 'timestamp DESC',
            limit: 1,
          );
          if (rows.isNotEmpty) {
            final m = rows.first;
            final senderId = m['sender_id'] as int;
            final content = (m['content'] as String?) ?? '';
            final ts = (m['timestamp'] as int?) ?? 0;
            final bool replied = senderId == id;
            loaded[loaded.length - 1]['hasReply'] = replied;
            loaded[loaded.length - 1]['lastMsg'] = content;
            loaded[loaded.length - 1]['lastTs'] = ts;
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;
    setState(() {
      _recipientCards = loaded;
    });
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dangerLabel = _messageData['danger_label']?.toString() ?? '未知危险';
    final safetyStatus = int.tryParse('${_messageData['safety_status'] ?? 0}') ?? 0;
    final urgentLabels = (_messageData['urgent_labels'] is List)
        ? (_messageData['urgent_labels'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final statusText = safetyStatus == 2 ? '已脱险' : (safetyStatus == 1 ? '暂时安全' : '仍危险');
    final statusColor = safetyStatus == 2 ? Colors.green : (safetyStatus == 1 ? Colors.orange : Colors.red);

    return Scaffold(
      appBar: AppBar(
        title: const Text('求救详情'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Text('SOS 求救', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(Icons.report, dangerLabel, Colors.red.shade700),
                    _chip(Icons.shield, statusText, statusColor),
                    if (urgentLabels.isNotEmpty)
                      _chip(Icons.inventory_2, urgentLabels.join('、'), Colors.deepOrange),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_photoBase64List.isNotEmpty) ...[
            const Text('现场照片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photoBase64List.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final b64 = _photoBase64List[index];
                  Uint8List? bytes;
                  try {
                    bytes = base64Decode(b64);
                  } catch (_) {}
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: bytes == null
                        ? Container(width: 96, height: 96, color: Colors.grey.shade200)
                        : Image.memory(bytes, width: 96, height: 96, fit: BoxFit.cover),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text('已发送给以下用户', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_recipientCards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('暂无接收用户')),
            )
          else
            ..._recipientCards.map((u) {
              final avatar = u['avatar'] as String? ?? '';
              final name = u['name'] as String? ?? '';
              final id = u['id'] as int;
              final hasReply = u['hasReply'] == true;
              final lastMsg = u['lastMsg'] as String? ?? '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: (avatar.isNotEmpty)
                    ? CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          avatar.startsWith('http') ? avatar : 'http://8.136.205.255:8000$avatar',
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.red.shade50,
                        child: Text(name.isNotEmpty ? name.substring(0, 1) : 'U'),
                      ),
                title: Text(name),
                subtitle: Text(
                  hasReply
                      ? (lastMsg.isNotEmpty ? lastMsg : '已回复')
                      : '等待回复...',
                  style: TextStyle(
                    color: hasReply ? Colors.black87 : Colors.grey,
                    fontStyle: hasReply ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                trailing: const Icon(Icons.chat),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        title: name,
                        avatar: avatar,
                        partnerId: id,
                      ),
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }
}

