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
}
