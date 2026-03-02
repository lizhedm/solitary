import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:web/web.dart' as web;

class WebAMapWidget extends StatefulWidget {
  final AMapApiKey apiKey;
  final LatLng center;

  const WebAMapWidget({super.key, required this.apiKey, required this.center});

  @override
  State<WebAMapWidget> createState() => _WebAMapWidgetState();
}

class _WebAMapWidgetState extends State<WebAMapWidget> {
  // Use a unique ID for each map instance to avoid conflicts
  late final String _divId;
  late final String _viewType;
  
  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _divId = 'amap_container_$timestamp';
    _viewType = 'amap_web_view_$timestamp';
    
    // Register the view factory
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      div.id = _divId;
      div.style.width = '100%';
      div.style.height = '100%';
      return div;
    });
    
    // Initialize map after the view is attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMap();
    });
  }

  void _initMap() {
    // Wait for the div to be in the DOM
    Future.delayed(const Duration(milliseconds: 500), () {
        // Cast globalContext to JSObject to use unsafe methods
        final global = globalContext as JSObject;
        
        // Check if AMap exists
        if (global.hasProperty('AMap'.toJS).toDart) {
           final aMap = global.getProperty('AMap'.toJS) as JSObject;
           
           final options = JSObject();
           options.setProperty('zoom'.toJS, 15.0.toJS);
           
           // Create center array
           final centerArr = [widget.center.longitude, widget.center.latitude].toJS;
           options.setProperty('center'.toJS, centerArr);

           // Access the constructor: AMap['Map']
           final mapConstructor = aMap.getProperty('Map'.toJS) as JSObject;
           mapConstructor.callAsConstructor(_divId.toJS, options);
        } else {
          debugPrint('AMap JS API not loaded. Make sure the script is included in index.html');
        }
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
