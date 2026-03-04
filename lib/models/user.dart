/// User - 用户数据模型类
/// 用于存储用户的基本信息
class User {
  // 用户ID
  final int id;
  // 用户名（必填）
  final String username;
  // 邮箱（可选）
  final String? email;
  // 昵称（可选）
  final String? nickname;
  // 头像URL（可选）
  final String? avatar;
  // 是否激活状态
  final bool isActive;

  /// User构造函数
  /// 参数：id 用户ID, username 用户名, email 邮箱(可选), nickname 昵称(可选), avatar 头像(可选), isActive 是否激活
  User({
    required this.id,
    required this.username,
    this.email,
    this.nickname,
    this.avatar,
    this.isActive = true,
  });

  /// fromJson - 从JSON数据创建User实例
  /// 将服务器返回的JSON数据转换为User对象
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      isActive: json['is_active'] ?? true,
    );
  }

  /// copyWith - 创建User的副本并更新指定字段
  /// 用于更新用户信息时创建新的User实例
  User copyWith({
    int? id,
    String? username,
    String? email,
    String? nickname,
    String? avatar,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      isActive: isActive ?? this.isActive,
    );
  }

  /// toJson - 将User实例转换为JSON数据
  /// 用于发送用户信息到服务器
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'nickname': nickname,
      'avatar': avatar,
      'is_active': isActive,
    };
  }
}
