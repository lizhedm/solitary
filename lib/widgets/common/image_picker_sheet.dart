import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerSheet {
  static Future<XFile?> show(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    
    return showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
                title: const Text('从相册选择'),
                onTap: () async {
                  Navigator.pop(context); // Close bottom sheet first
                  final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
                  // We can't return from showModalBottomSheet here because we already popped
                  // So we rely on the caller to handle the result, but wait...
                  // The standard pattern is to return the value from pop.
                  // But here the async gap makes it tricky.
                  // Let's change the strategy: return the Source, then pick outside.
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF2E7D32)),
                title: const Text('拍照'),
                onTap: () async {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Better approach: Return the source
  static Future<ImageSource?> showSourcePicker(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        // 这里的 BottomSheet UI 需要与 `求救详情` 中选择照片来源保持一致
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }
}
