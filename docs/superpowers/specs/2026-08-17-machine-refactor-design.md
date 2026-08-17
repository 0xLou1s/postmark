# Refactor: tách trách nhiệm trong feature `machine`

Ngày: 2026-08-17

## Mục tiêu

Dọn dẹp cấu trúc code để dễ mở rộng và bảo trì. Giữ nguyên toàn bộ hành vi hiện
tại — không sửa logic camera, thứ tự animation, phép tính crop, hay cách xử lý
zoom.

## Vấn đề hiện tại

1. `lib/features/machine/machine_screen.dart` dài 539 dòng, gánh 4 trách nhiệm:
   điều phối chuỗi chụp, view camera trực tiếp, view fallback desktop, overlay
   eject — cộng widget private `_CameraControl` và 5 hằng số ở file scope.
2. Màu hardcode lặp lại: `Color(0xFF1C1C1C)` (machine_screen.dart:393) trùng
   `PostmarkColors.slot`; `Colors.white38`, `Colors.white24`,
   `Colors.black.withValues(alpha: 0.4)` rải rác nhiều file.
3. Magic number không có chỗ ở: `_kControlSize`, `_kRowPadX`, `_kMachineInsets`,
   các duration animation đều private trong file screen.
4. `_usePicker` — mối quan tâm về platform — là getter nằm trong file UI.
5. `ImagePicker` được gọi trực tiếp trong widget thay vì ở tầng dưới.

## Cấu trúc đích

```
lib/
├── app/                          (giữ nguyên: app, router, shell)
├── core/
│   ├── constants/
│   │   └── app_durations.dart
│   ├── platform/
│   │   └── camera_capability.dart
│   ├── theme/
│   │   ├── app_theme.dart        ← chuyển từ app/theme.dart
│   │   └── app_colors.dart
│   └── widgets/                  (giữ nguyên)
├── data/                         (giữ nguyên)
├── domain/                       (giữ nguyên)
└── features/
    ├── book/                     (giữ nguyên — đã gọn)
    ├── preview/                  (giữ nguyên)
    └── machine/
        ├── machine_screen.dart          ~80 dòng, chỉ điều hướng state
        ├── machine_controller.dart      tách phần crop ra
        ├── machine_capture_flow.dart
        ├── machine_metrics.dart
        ├── image_crop.dart
        ├── gallery_picker.dart
        └── widgets/
            ├── camera_view.dart
            ├── fallback_view.dart
            ├── eject_overlay.dart
            ├── camera_control.dart
            ├── camera_top_bar.dart
            ├── camera_bottom_bar.dart
            ├── machine_frame.dart       (giữ nguyên)
            └── shutter_button.dart      (giữ nguyên)
```

Ràng buộc: không file nào vượt ~200 dòng.

## Các thành phần

### `machine_capture_flow.dart`

Giữ toàn bộ trạng thái và trình tự chụp, tách khỏi widget.

```dart
class MachineCaptureFlow extends ChangeNotifier {
  bool get busy;
  bool get pressed;
  Uint8List? get ejectImage;
  AnimationController get ejectAnimation;

  Future<Uint8List?> captureFromCamera({
    required Rect? windowRect,
    required Size? screenSize,
  });
  Future<Uint8List?> pickFromGallery();
}
```

Trình tự trong `captureFromCamera` giữ nguyên đúng thứ tự hiện tại: press down →
delay `pressDown` → capture → release → delay `springBack` → eject.

Điều hướng (`Navigator.push` sang `PreviewScreen`) ở lại trong screen — đó là
mối quan tâm của UI, không phải của flow.

### `gallery_picker.dart`

```dart
Future<Uint8List?> pickImageBytes();
```

Bọc `ImagePicker` để widget không import trực tiếp package.

### `image_crop.dart`

Chuyển `_CropRequest` và `_cropJpeg` ra khỏi `machine_controller.dart`. Đây là
hàm thuần chạy trên isolate qua `compute`, không liên quan lifecycle camera.
Controller còn ~200 dòng.

### `core/platform/camera_capability.dart`

`_usePicker` chuyển thành hằng số public, đặt tên theo ý nghĩa (ví dụ
`usesGalleryPicker`).

### `core/theme/app_colors.dart`

```dart
class AppColors {
  static const paper, ink, metalLight, metalDark, slot;   // như PostmarkColors
  static const controlSurface = Color(0x66000000);        // black 40%
  static const controlBorder  = Colors.white24;
  static const hintText       = Colors.white38;
  static const scrimMax       = 0.35;
}
```

### `machine_metrics.dart`

```dart
class MachineMetrics {
  static const insets = EdgeInsets.fromLTRB(46, 32, 46, 132);
  static const pressScale = 0.92;
  static const controlSize = 46.0;
  static const rowPadX = 24.0;
  static const zoomGestureBottomInset = 160.0;
}
```

### `core/constants/app_durations.dart`

Gom `pressAnim` (440ms), `pressDown` (440ms), `springBack` (340ms),
`eject` (1700ms).

## Xử lý comment

- Xoá comment mô tả *cái gì* code đang làm, ví dụ
  `// Full-screen camera preview, filling the screen edge-to-edge.`
- Giữ comment giải thích *tại sao*, ví dụ
  `// previewSize is reported landscape (long side = width)...` và
  `// ChangeNotifierProvider already disposes the returned notifier...`

Những comment "tại sao" ghi lại các bug có thật; mất chúng là mất kiến thức.

## Kiểm chứng

- Chạy `flutter analyze` sau mỗi bước, phải sạch.
- Chạy app, xác nhận thủ công: chụp ảnh trên thiết bị thật, chọn ảnh từ gallery,
  lật camera, đổi flash, pinch zoom, animation eject, màn hình book và detail.
- Không có thay đổi nào về hành vi quan sát được.

## Ngoài phạm vi

- Không đổi sang Riverpod codegen hay freezed.
- Không thêm tầng `services/` hay `use_cases/`.
- Không refactor `book/`, `preview/`, `data/`, `domain/` ngoài việc sửa import.
- Không thêm test mới.
