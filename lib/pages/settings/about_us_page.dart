import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于我们')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terrain, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Solitary', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('v1.0.1', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            const Text('让每一次独行都有陪伴'),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('用户协议')),
            TextButton(onPressed: () {}, child: const Text('隐私政策')),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
