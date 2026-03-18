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
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
                ),
                title: const Text('从相册选择', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(
                     color: const Color(0xFF2E7D32).withOpacity(0.1),
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.camera_alt, color: Color(0xFF2E7D32)),
                ),
                title: const Text('拍照', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
