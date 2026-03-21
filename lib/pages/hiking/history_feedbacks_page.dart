import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_helper.dart';
import 'feedback_list_widget.dart';

class HistoryFeedbacksPage extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;

  const HistoryFeedbacksPage({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  @override
  State<HistoryFeedbacksPage> createState() => _HistoryFeedbacksPageState();
}

class _HistoryFeedbacksPageState extends State<HistoryFeedbacksPage> {
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final startTs = widget.startTime.millisecondsSinceEpoch;
      final endTs = widget.endTime.millisecondsSinceEpoch;

      final allFeedbacks = await DatabaseHelper().getFeedbacks(userId);
      final filtered = allFeedbacks.where((f) {
        final createdAt = f['created_at'] as int? ?? 0;
        return createdAt >= startTs && createdAt <= endTs;
      }).toList();

      setState(() {
        _feedbacks = filtered;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load history feedbacks: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布的路况'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FeedbackListWidget(
              feedbacks: _feedbacks,
            ),
    );
  }
}
