class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final String type;
  final int timestamp;
  final bool isRead;
  final int? hikeId;
  final int? senderHikeId;
  final int? receiverHikeId;
  
  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.isRead,
    this.hikeId,
    this.senderHikeId,
    this.receiverHikeId,
  });
  
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? json['remote_id'] ?? json['local_id'] ?? 0,
      senderId: json['sender_id'],
      receiverId: json['receiver_id'] ?? 0, // handle optional
      content: json['content'],
      type: json['type'],
      timestamp: json['timestamp'],
      isRead: (json['is_read'] is int) ? (json['is_read'] == 1) : (json['is_read'] ?? false),
      hikeId: json['hike_id'],
      senderHikeId: json['sender_hike_id'],
      receiverHikeId: json['receiver_hike_id'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'type': type,
      'timestamp': timestamp,
      'is_read': isRead ? 1 : 0,
      'hike_id': hikeId,
      'sender_hike_id': senderHikeId,
      'receiver_hike_id': receiverHikeId,
    };
  }
}