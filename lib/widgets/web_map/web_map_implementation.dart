import 'package:flutter/material.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

class WebAMapWidget extends StatelessWidget {
  final AMapApiKey apiKey;
  final LatLng center;

  const WebAMapWidget({super.key, required this.apiKey, required this.center});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Web Map placeholder - map functionality not available in web version',
      ),
    );
  }
}
