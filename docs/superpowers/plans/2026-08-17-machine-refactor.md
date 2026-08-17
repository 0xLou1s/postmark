# Machine Feature Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tách `machine_screen.dart` (539 dòng) thành các unit một-trách-nhiệm và gom các giá trị dùng chung vào design token, giữ nguyên 100% hành vi.

**Architecture:** Refactor thuần túy theo từng bước nhỏ. Mỗi task di chuyển hoặc tách một mảnh, chạy `flutter analyze` + `flutter test`, rồi commit. Không có test mới — bộ test hiện có (4 file) là lưới an toàn hồi quy. Không sửa logic camera, thứ tự animation, phép tính crop, hay xử lý zoom.

**Tech Stack:** Flutter, Riverpod (ChangeNotifierProvider), camera ^0.12.0+1, image_picker ^1.2.2, image ^4.5.4, go_router.

---

## Lưu ý về TDD

Đây là refactor không đổi hành vi, nên không có "test đỏ trước". Thay vào đó mỗi
task kết thúc bằng cùng một cổng kiểm chứng:

```bash
flutter analyze && flutter test
```

Cả hai phải sạch trước khi commit. Nếu `flutter analyze` báo lỗi import sau khi
di chuyển file, sửa import — đừng đổi logic.

Sau **Task 5** và **Task 11** cần kiểm thử thủ công trên thiết bị thật (xem mô
tả trong từng task) vì test widget không phủ được camera.

---

## File Structure

**Tạo mới:**

| File | Trách nhiệm |
|---|---|
| `lib/core/theme/app_colors.dart` | Toàn bộ color token |
| `lib/core/theme/app_theme.dart` | `buildPostmarkTheme()` (chuyển từ `app/theme.dart`) |
| `lib/core/constants/app_durations.dart` | Duration animation dùng chung |
| `lib/core/platform/camera_capability.dart` | Cờ platform `usesGalleryPicker` |
| `lib/features/machine/machine_metrics.dart` | Số liệu bố cục của machine |
| `lib/features/machine/image_crop.dart` | Crop JPEG chạy trên isolate |
| `lib/features/machine/gallery_picker.dart` | Bọc `ImagePicker` |
| `lib/features/machine/machine_capture_flow.dart` | Trạng thái + trình tự chụp |
| `lib/features/machine/widgets/camera_control.dart` | Nút tròn control (public hoá) |
| `lib/features/machine/widgets/camera_top_bar.dart` | Hàng flash + zoom |
| `lib/features/machine/widgets/camera_bottom_bar.dart` | Hàng gallery + shutter + flip |
| `lib/features/machine/widgets/camera_view.dart` | View camera trực tiếp |
| `lib/features/machine/widgets/fallback_view.dart` | View desktop/simulator |
| `lib/features/machine/widgets/eject_overlay.dart` | Animation stamp nhả ra |

**Sửa:**

| File | Thay đổi |
|---|---|
| `lib/features/machine/machine_screen.dart` | 539 → ~85 dòng |
| `lib/features/machine/machine_controller.dart` | 274 → ~200 dòng (bỏ phần crop) |
| `lib/app/app.dart` | Đổi import theme |
| `lib/core/widgets/postmark_nav.dart` | `PostmarkColors` → `AppColors` |

**Xoá:** `lib/app/theme.dart` (nội dung chuyển sang `core/theme/`)

---

## Task 1: Chuyển theme sang `core/theme/`

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_theme.dart`
- Delete: `lib/app/theme.dart`
- Modify: `lib/app/app.dart:2`
- Modify: `lib/core/widgets/postmark_nav.dart:5,34,36,76,136`

- [ ] **Step 1: Tạo `lib/core/theme/app_colors.dart`**

Gom cả màu cũ từ `PostmarkColors` lẫn các màu đang hardcode rải rác. Các giá trị
`controlSurface`, `controlBorder`, `hintText`, `scrim` lấy đúng từ
`machine_screen.dart` hiện tại — không đổi giá trị.

```dart
import 'package:flutter/material.dart';

/// Paper + brushed-metal palette. Warm, quiet, non-social.
class AppColors {
  static const paper = Color(0xFFF2EFE9);
  static const ink = Color(0xFF2B2B2B);
  static const metalLight = Color(0xFFD9D9D9);
  static const metalDark = Color(0xFF8A8A8A);
  static const slot = Color(0xFF1C1C1C);

  /// Round camera controls: translucent black disc with a hairline rim.
  static const controlSurface = Color(0x66000000);
  static const controlBorder = Colors.white24;

  /// Muted text/icons over a dark viewfinder.
  static const hintText = Colors.white38;

  /// Peak opacity of the scrim behind the ejecting stamp.
  static const double scrimMaxOpacity = 0.35;
}
```

- [ ] **Step 2: Tạo `lib/core/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData buildPostmarkTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.ink,
      surface: AppColors.paper,
    ),
    textTheme: GoogleFonts.loraTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
```

- [ ] **Step 3: Xoá file theme cũ**

```bash
rm lib/app/theme.dart
```

- [ ] **Step 4: Sửa import trong `lib/app/app.dart`**

Đổi dòng 2 từ `import 'theme.dart';` thành:

```dart
import '../core/theme/app_theme.dart';
```

- [ ] **Step 5: Sửa `lib/core/widgets/postmark_nav.dart`**

Đổi dòng 5 từ `import '../../app/theme.dart';` thành:

```dart
import '../theme/app_colors.dart';
```

Rồi thay toàn bộ `PostmarkColors.` bằng `AppColors.` (5 chỗ: dòng 34, 36, 76, 136 — dòng 136 có 2 lần):

```bash
sed -i '' 's/PostmarkColors\./AppColors./g' lib/core/widgets/postmark_nav.dart
```

- [ ] **Step 6: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!` và tất cả test PASS. Nếu còn chỗ nào tham chiếu
`PostmarkColors`, analyze sẽ chỉ ra — sửa import ở file đó.

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/ lib/app/app.dart lib/core/widgets/postmark_nav.dart
git add -u lib/app/theme.dart
git commit -m "refactor: move theme to core/theme with shared color tokens"
```

---

## Task 2: Tách hằng số duration và platform

**Files:**
- Create: `lib/core/constants/app_durations.dart`
- Create: `lib/core/platform/camera_capability.dart`
- Create: `lib/features/machine/machine_metrics.dart`

- [ ] **Step 1: Tạo `lib/core/constants/app_durations.dart`**

Giá trị lấy đúng từ `machine_screen.dart:30-35` và `:62`.

```dart
/// Timings for the capture sequence — deliberate but a touch snappier.
class AppDurations {
  /// Scale down/up while the shutter presses the machine.
  static const pressAnim = Duration(milliseconds: 440);

  /// Hold while pressed, before the frame is captured.
  static const pressDown = Duration(milliseconds: 440);

  /// Settle after release, before the stamp ejects.
  static const springBack = Duration(milliseconds: 340);

  /// Full eject animation.
  static const eject = Duration(milliseconds: 1700);
}
```

- [ ] **Step 2: Tạo `lib/core/platform/camera_capability.dart`**

Giữ nguyên comment "tại sao" từ `machine_screen.dart:15-16` — nó ghi lại một
ràng buộc thật của package.

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';

// macOS/desktop: camera_avfoundation is iOS-only — use image_picker instead.
// Also falls back to picker when camera reports no-camera error (e.g. simulator).
bool get usesGalleryPicker =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
```

- [ ] **Step 3: Tạo `lib/features/machine/machine_metrics.dart`**

Giá trị lấy từ `machine_screen.dart:24, 27, 454, 458, 277`. Giữ comment "tại sao"
cho `insets` và `zoomGestureBottomInset` — cả hai ghi lại lý do bố cục.

```dart
import 'package:flutter/widgets.dart';

class MachineMetrics {
  /// Insets around the machine. The horizontal padding shrinks the body (the
  /// AspectRatio is width-limited) so it reads as a smaller device; the bottom
  /// padding keeps it clear of the shutter row. Shared by the live frame and the
  /// eject overlay so they sit in exactly the same place.
  static const insets = EdgeInsets.fromLTRB(46, 32, 46, 132);

  /// How far the machine shrinks while the shutter "presses" it down.
  static const double pressScale = 0.92;

  /// Diameter shared by every round on-screen control (flash, zoom, gallery,
  /// flip) so the top and bottom rows line up.
  static const double controlSize = 46;

  /// Horizontal inset of the top/bottom control rows, shared so flash lines up
  /// over the gallery button and zoom over the flip button.
  static const double rowPadX = 24;

  /// The zoom gesture stops short of the bottom so its scale recognizer can't
  /// steal taps meant for the control buttons.
  static const double zoomGestureBottomInset = 160;

  /// Width reserved between the flash button and the zoom badge, matching the
  /// shutter so the top and bottom rows align.
  static const double shutterSpacerWidth = 76;
}
```

- [ ] **Step 4: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!` — các file mới chưa được dùng nhưng phải hợp lệ.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/ lib/core/platform/ lib/features/machine/machine_metrics.dart
git commit -m "refactor: extract durations, platform flag and machine metrics"
```

---

## Task 3: Tách phần crop ảnh khỏi controller

**Files:**
- Create: `lib/features/machine/image_crop.dart`
- Modify: `lib/features/machine/machine_controller.dart:1-7,174,217-220,231-267`

- [ ] **Step 1: Tạo `lib/features/machine/image_crop.dart`**

Chuyển nguyên `_CropRequest` và `_cropJpeg` từ `machine_controller.dart:231-267`,
đổi thành public. Giữ toàn bộ comment "tại sao" — chúng ghi lại thứ tự bake/flip
đã tốn công tìm ra.

```dart
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Crop parameters as fractions [0,1] of the (orientation-baked) image.
class CropRequest {
  const CropRequest(
    this.bytes,
    this.u0,
    this.v0,
    this.u1,
    this.v1, {
    this.flipH = false,
  });
  final Uint8List bytes;
  final double u0, v0, u1, v1;

  /// Mirror horizontally before cropping (front-camera un-mirroring).
  final bool flipH;
}

/// Runs on a background isolate via [compute]: decode, normalise orientation,
/// crop to the requested fractions, and re-encode as JPEG. Falls back to the
/// original bytes if anything is off.
Uint8List cropJpeg(CropRequest r) {
  final decoded = img.decodeImage(r.bytes);
  if (decoded == null) return r.bytes;
  var baked = img.bakeOrientation(decoded);
  // Mirror first so screen-space crop fractions (from the mirrored preview)
  // map onto the same pixels and the result matches what the user saw.
  if (r.flipH) baked = img.flipHorizontal(baked);

  final x = (r.u0 * baked.width).round();
  final y = (r.v0 * baked.height).round();
  final w = ((r.u1 - r.u0) * baked.width).round();
  final h = ((r.v1 - r.v0) * baked.height).round();
  if (w <= 0 || h <= 0) return r.bytes;

  final cropped = img.copyCrop(baked, x: x, y: y, width: w, height: h);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}
```

- [ ] **Step 2: Xoá `_CropRequest` và `_cropJpeg` khỏi controller**

Trong `lib/features/machine/machine_controller.dart`, xoá toàn bộ dòng 231–267
(từ `/// Crop parameters as fractions...` đến hết hàm `_cropJpeg`).

- [ ] **Step 3: Sửa import và call site trong controller**

Bỏ import `package:image/image.dart` (dòng 7) — controller không còn dùng. Thêm:

```dart
import 'image_crop.dart';
```

Đổi dòng 174 từ:

```dart
    return compute(_cropJpeg, _CropRequest(bytes, 0, 0, 1, 1, flipH: true));
```

thành:

```dart
    return compute(cropJpeg, CropRequest(bytes, 0, 0, 1, 1, flipH: true));
```

Đổi dòng 217–220 từ:

```dart
    return compute(
      _cropJpeg,
      _CropRequest(bytes, u0, v0, u1, v1, flipH: _isFront),
    );
```

thành:

```dart
    return compute(
      cropJpeg,
      CropRequest(bytes, u0, v0, u1, v1, flipH: _isFront),
    );
```

- [ ] **Step 4: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`, test PASS. Controller giờ khoảng 200 dòng —
kiểm tra bằng `wc -l lib/features/machine/machine_controller.dart`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/machine/image_crop.dart lib/features/machine/machine_controller.dart
git commit -m "refactor: move isolate JPEG crop out of machine controller"
```

---

## Task 4: Bọc gallery picker

**Files:**
- Create: `lib/features/machine/gallery_picker.dart`

- [ ] **Step 1: Tạo `lib/features/machine/gallery_picker.dart`**

Hành vi khớp đúng `machine_screen.dart:159-170`: mở gallery, trả `null` nếu người
dùng huỷ, ngược lại trả bytes.

```dart
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the system gallery. Returns null when the user cancels.
Future<Uint8List?> pickImageBytes() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  return picked.readAsBytes();
}
```

- [ ] **Step 2: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/machine/gallery_picker.dart
git commit -m "refactor: wrap ImagePicker behind pickImageBytes"
```

---

## Task 5: Tách trình tự chụp thành `MachineCaptureFlow`

Đây là task rủi ro nhất — nó di chuyển trình tự press → capture → eject. Thứ tự
và các `await` phải giữ nguyên tuyệt đối.

**Files:**
- Create: `lib/features/machine/machine_capture_flow.dart`

- [ ] **Step 1: Tạo `lib/features/machine/machine_capture_flow.dart`**

`captureFromCamera` giữ nguyên trình tự từ `machine_screen.dart:104-127`.
`ejectAndHold` giữ nguyên `machine_screen.dart:134-136` (phần trước khi điều
hướng); việc `Navigator.push` và dọn dẹp sau đó ở lại screen.

```dart
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/constants/app_durations.dart';
import 'gallery_picker.dart';
import 'machine_controller.dart';

/// Owns the capture sequence and the transient UI state around it: whether a
/// capture is in flight, whether the machine is pressed down, and the image
/// currently ejecting from the slot.
class MachineCaptureFlow extends ChangeNotifier {
  MachineCaptureFlow({required this.vsync}) {
    ejectAnimation = AnimationController(
      vsync: vsync,
      duration: AppDurations.eject,
    );
  }

  final TickerProvider vsync;
  late final AnimationController ejectAnimation;

  bool _busy = false;
  bool _pressed = false;
  Uint8List? _ejectImage;

  bool get busy => _busy;
  bool get pressed => _pressed;
  Uint8List? get ejectImage => _ejectImage;

  set busy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  set pressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    notifyListeners();
  }

  /// Presses the machine down, captures a frame cropped to the bezel window,
  /// then releases and settles. Returns the captured bytes, or null if the
  /// capture failed (in which case [busy] is cleared).
  Future<Uint8List?> captureFromCamera(
    MachineController controller, {
    required Rect? windowRect,
    required Size? screenSize,
  }) async {
    pressed = true;
    await Future.delayed(AppDurations.pressDown);

    final bytes = (windowRect != null && screenSize != null)
        ? await controller.captureCropped(
            windowRect: windowRect,
            screenSize: screenSize,
          )
        : await controller.capture();

    pressed = false;
    if (bytes == null) {
      busy = false;
      return null;
    }
    await Future.delayed(AppDurations.springBack);
    return bytes;
  }

  /// Opens the gallery. Returns the chosen bytes, or null on cancel (in which
  /// case [busy] is cleared).
  Future<Uint8List?> pickFromGallery() async {
    final bytes = await pickImageBytes();
    if (bytes == null) {
      busy = false;
      return null;
    }
    return bytes;
  }

  /// Runs the eject animation with [bytes] showing in the slot, leaving the
  /// image on screen when it completes so the caller can navigate over it.
  Future<void> eject(Uint8List bytes) async {
    _ejectImage = bytes;
    notifyListeners();
    await ejectAnimation.forward(from: 0);
  }

  /// Clears the ejected image and releases the busy latch.
  void reset() {
    _ejectImage = null;
    _busy = false;
    ejectAnimation.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    ejectAnimation.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!` — class mới chưa được nối vào screen.

- [ ] **Step 3: Commit**

```bash
git add lib/features/machine/machine_capture_flow.dart
git commit -m "refactor: extract MachineCaptureFlow from machine screen"
```

---

## Task 6: Tách `CameraControl`

**Files:**
- Create: `lib/features/machine/widgets/camera_control.dart`

- [ ] **Step 1: Tạo `lib/features/machine/widgets/camera_control.dart`**

Chuyển `_CameraControl` từ `machine_screen.dart:472-539` và
`_controlDecoration()` từ `:460-464`, dùng token thay số hardcode. Comment lớp
được rút gọn — bỏ phần so sánh với React (mô tả *cái gì*), giữ phần mô tả hai
biến thể vì nó là hợp đồng sử dụng.

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../machine_metrics.dart';

/// A round, translucent camera control with two variants:
///   • [CameraControl.icon]  — a tappable icon button (flash / gallery / flip).
///                             Pass a null `onPressed` to render it disabled.
///   • [CameraControl.label] — a non-interactive text readout (zoom).
class CameraControl extends StatelessWidget {
  const CameraControl._({
    required this.child,
    required this.interactive,
    this.onPressed,
    this.tooltip,
  });

  factory CameraControl.icon({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    return CameraControl._(
      interactive: true,
      onPressed: onPressed,
      tooltip: tooltip,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  factory CameraControl.label(String text) {
    return CameraControl._(
      interactive: false,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  final Widget child;
  final bool interactive;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final disabled = interactive && onPressed == null;
    Widget control = Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Container(
        width: MachineMetrics.controlSize,
        height: MachineMetrics.controlSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.controlSurface,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.controlBorder, width: 1),
          ),
        ),
        child: child,
      ),
    );

    if (!interactive) return control;

    control = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: control,
    );
    return tooltip == null
        ? control
        : Tooltip(message: tooltip!, child: control);
  }
}
```

- [ ] **Step 2: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/machine/widgets/camera_control.dart
git commit -m "refactor: promote CameraControl to its own widget file"
```

---

## Task 7: Tách thanh điều khiển trên và dưới

**Files:**
- Create: `lib/features/machine/widgets/camera_top_bar.dart`
- Create: `lib/features/machine/widgets/camera_bottom_bar.dart`

- [ ] **Step 1: Tạo `lib/features/machine/widgets/camera_top_bar.dart`**

Từ `machine_screen.dart:307-337`, cộng `_flashIcon` từ `:440-450`. Giữ comment
"tại sao" ở `crossAxisAlignment` và ở `ValueListenableBuilder`.

```dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../machine_metrics.dart';
import 'camera_control.dart';

/// Flash (left) + live zoom readout (right). The middle spacer matches the
/// shutter so these line up with the bottom row.
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.flashMode,
    required this.zoomNotifier,
    required this.onToggleFlash,
  });

  final FlashMode flashMode;
  final ValueListenable<double> zoomNotifier;
  final VoidCallback? onToggleFlash;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 8,
            left: MachineMetrics.rowPadX,
            right: MachineMetrics.rowPadX,
          ),
          child: Row(
            // Pin to the top edge; without this the Row centres itself in
            // the full-height Positioned.fill.
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CameraControl.icon(
                icon: _flashIcon(flashMode),
                onPressed: onToggleFlash,
                tooltip: 'Flash',
              ),
              const SizedBox(width: MachineMetrics.shutterSize),
              // Only the badge rebuilds while pinching, not the preview.
              ValueListenableBuilder<double>(
                valueListenable: zoomNotifier,
                builder: (context, zoom, _) =>
                    CameraControl.label('${zoom.toStringAsFixed(1)}×'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _flashIcon(FlashMode mode) {
  switch (mode) {
    case FlashMode.always:
    case FlashMode.torch:
      return Icons.flash_on;
    case FlashMode.auto:
      return Icons.flash_auto;
    case FlashMode.off:
      return Icons.flash_off;
  }
}
```

Lưu ý: `ValueListenable` cần `import 'package:flutter/foundation.dart';` — nhưng
`material.dart` đã export nó, nên không cần thêm import.

- [ ] **Step 2: Tạo `lib/features/machine/widgets/camera_bottom_bar.dart`**

Từ `machine_screen.dart:339-375`.

```dart
import 'package:flutter/material.dart';

import '../machine_metrics.dart';
import 'camera_control.dart';
import 'shutter_button.dart';

/// Gallery + shutter + flip, kept clear of the bottom safe area.
class CameraBottomBar extends StatelessWidget {
  const CameraBottomBar({
    super.key,
    required this.onPick,
    required this.onShutter,
    required this.onFlip,
    required this.shutterEnabled,
    required this.onShutterPressedChanged,
  });

  final VoidCallback? onPick;
  final VoidCallback onShutter;
  final VoidCallback? onFlip;
  final bool shutterEnabled;
  final ValueChanged<bool> onShutterPressedChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MachineMetrics.rowPadX,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CameraControl.icon(
                    icon: Icons.photo_library_outlined,
                    onPressed: onPick,
                    tooltip: 'Pick from gallery',
                  ),
                  ShutterButton(
                    onPressed: onShutter,
                    enabled: shutterEnabled,
                    onPressedChanged: onShutterPressedChanged,
                  ),
                  CameraControl.icon(
                    icon: Icons.cameraswitch_outlined,
                    onPressed: onFlip,
                    tooltip: 'Switch camera',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/machine/widgets/camera_top_bar.dart lib/features/machine/widgets/camera_bottom_bar.dart
git commit -m "refactor: extract camera top and bottom control bars"
```

---

## Task 8: Tách `CameraView`

**Files:**
- Create: `lib/features/machine/widgets/camera_view.dart`

- [ ] **Step 1: Tạo `lib/features/machine/widgets/camera_view.dart`**

Từ `machine_screen.dart:241-379`. Giữ comment "tại sao" ở phần `showPreview` và
phần cửa sổ bezel.

```dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/perforated_border.dart';
import '../machine_controller.dart';
import '../machine_metrics.dart';
import 'camera_bottom_bar.dart';
import 'camera_top_bar.dart';
import 'machine_frame.dart';

/// Full-screen live preview with the machine bezel overlaid; the photo is
/// cropped to the bezel window on capture.
class CameraView extends StatelessWidget {
  const CameraView({
    super.key,
    required this.machine,
    required this.stackKey,
    required this.windowKey,
    required this.pressed,
    required this.busy,
    required this.onShutter,
    required this.onShutterPressedChanged,
    required this.onPick,
    required this.onFlip,
    required this.onToggleFlash,
    required this.onZoomStart,
    required this.onZoomUpdate,
  });

  final MachineController machine;
  final GlobalKey stackKey;
  final GlobalKey windowKey;
  final bool pressed;
  final bool busy;
  final VoidCallback onShutter;
  final ValueChanged<bool> onShutterPressedChanged;
  final VoidCallback onPick;
  final VoidCallback onFlip;
  final VoidCallback onToggleFlash;
  final VoidCallback onZoomStart;
  final ValueChanged<double> onZoomUpdate;

  @override
  Widget build(BuildContext context) {
    final cam = machine.controller;
    // While flipping lenses the old controller is disposed before the new one
    // is ready — keep the bezel + controls, but show black/loading in place of
    // the preview so we never render CameraPreview against a disposed camera.
    final showPreview =
        !machine.switching && cam != null && cam.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        key: stackKey,
        fit: StackFit.expand,
        children: [
          if (showPreview)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cam.value.previewSize!.height,
                height: cam.value.previewSize!.width,
                child: CameraPreview(cam),
              ),
            )
          else
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: MachineMetrics.zoomGestureBottomInset,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: (_) => onZoomStart(),
              onScaleUpdate: (d) => onZoomUpdate(d.scale),
            ),
          ),
          Padding(
            padding: MachineMetrics.insets,
            child: Center(
              child: AnimatedScale(
                scale: pressed ? MachineMetrics.pressScale : 1,
                duration: AppDurations.pressAnim,
                curve: Curves.easeOutCubic,
                child: MachineOverlayFrame(
                  windowKey: windowKey,
                  // Stamp perforation drawn in code over the live preview; its
                  // dark border bleeds under the bezel to hide any rim gap.
                  windowBuilder: (bleed) => StampNotchOverlay(bleed: bleed),
                ),
              ),
            ),
          ),
          CameraTopBar(
            flashMode: machine.flashMode,
            zoomNotifier: machine.zoomNotifier,
            onToggleFlash: (busy || machine.switching) ? null : onToggleFlash,
          ),
          CameraBottomBar(
            onPick: busy ? null : onPick,
            onShutter: onShutter,
            onFlip: (busy || machine.switching || !machine.canSwitchCamera)
                ? null
                : onFlip,
            shutterEnabled: !busy && !machine.switching,
            onShutterPressedChanged: onShutterPressedChanged,
          ),
        ],
      ),
    );
  }
}
```

Thêm import còn thiếu ở đầu file:

```dart
import '../../../core/constants/app_durations.dart';
```

- [ ] **Step 2: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!` Nếu analyze báo thiếu `AppDurations`, thêm import ở
trên.

- [ ] **Step 3: Commit**

```bash
git add lib/features/machine/widgets/camera_view.dart
git commit -m "refactor: extract live CameraView widget"
```

---

## Task 9: Tách `FallbackView`

**Files:**
- Create: `lib/features/machine/widgets/fallback_view.dart`

- [ ] **Step 1: Tạo `lib/features/machine/widgets/fallback_view.dart`**

Từ `machine_screen.dart:382-436`. `Color(0xFF1C1C1C)` đổi thành `AppColors.slot`
(cùng giá trị), `Colors.white38` đổi thành `AppColors.hintText`.

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/perforated_border.dart';
import 'machine_frame.dart';
import 'shutter_button.dart';

/// macOS / desktop / simulator (no live camera): static bezel + pick hint.
class FallbackView extends StatelessWidget {
  const FallbackView({
    super.key,
    required this.ready,
    required this.enabled,
    required this.onShutter,
  });

  /// Whether the viewfinder placeholder can be shown, as opposed to a spinner
  /// while a camera is still initialising.
  final bool ready;
  final bool enabled;
  final VoidCallback onShutter;

  @override
  Widget build(BuildContext context) {
    final Widget viewfinder = ready
        ? StampFrame(
            child: Container(
              color: AppColors.slot,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.hintText,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Press shutter\nto pick a photo',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.hintText, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        : const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: MachineFrame(slotChild: viewfinder)),
              ),
            ),
            ShutterButton(onPressed: onShutter, enabled: enabled),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/machine/widgets/fallback_view.dart
git commit -m "refactor: extract FallbackView widget"
```

---

## Task 10: Tách `EjectOverlay`

**Files:**
- Create: `lib/features/machine/widgets/eject_overlay.dart`

- [ ] **Step 1: Tạo `lib/features/machine/widgets/eject_overlay.dart`**

Từ `machine_screen.dart:214-237`. `0.35` đổi thành `AppColors.scrimMaxOpacity`.

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/perforated_border.dart';
import '../machine_metrics.dart';
import 'machine_frame.dart';

/// The cut-out stamp ejecting up out of the slot over the bezel, with the
/// window left black. Anchored to the same spot as the live frame so it
/// reads as the same machine.
class EjectOverlay extends StatelessWidget {
  const EjectOverlay({
    super.key,
    required this.animation,
    required this.image,
  });

  final Animation<double> animation;
  final Uint8List image;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value.clamp(0.0, 1.0);
          return ColoredBox(
            color: Colors.black.withValues(
              alpha: AppColors.scrimMaxOpacity * t,
            ),
            child: Padding(
              padding: MachineMetrics.insets,
              child: Center(
                child: MachineEjectFrame(
                  progress: t,
                  stamp: StampFrame(
                    child: Image.memory(image, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Kiểm chứng**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!` (`Uint8List` đến từ `material.dart` re-export
`foundation.dart`; nếu analyze phàn nàn, thêm `import 'dart:typed_data';`.)

- [ ] **Step 3: Commit**

```bash
git add lib/features/machine/widgets/eject_overlay.dart
git commit -m "refactor: extract EjectOverlay widget"
```

---

## Task 11: Viết lại `machine_screen.dart` dùng các unit mới

Task cuối và lớn nhất về mặt thay thế. Sau task này screen chỉ còn điều phối.

**Files:**
- Modify: `lib/features/machine/machine_screen.dart` (thay toàn bộ nội dung)

- [ ] **Step 1: Thay toàn bộ `lib/features/machine/machine_screen.dart`**

Giữ nguyên comment "tại sao" ở phần đo geometry (`:89-90`) — nó ghi lại một bug
thật về việc press làm lệch vùng crop.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/camera_capability.dart';
import 'machine_capture_flow.dart';
import 'machine_controller.dart';
import 'widgets/camera_view.dart';
import 'widgets/eject_overlay.dart';
import 'widgets/fallback_view.dart';
import '../preview/preview_screen.dart';

class MachineScreen extends ConsumerStatefulWidget {
  const MachineScreen({super.key});
  @override
  ConsumerState<MachineScreen> createState() => _MachineScreenState();
}

class _MachineScreenState extends ConsumerState<MachineScreen>
    with SingleTickerProviderStateMixin {
  late final MachineCaptureFlow _flow;
  double _baseZoom = 1.0;

  // The stack defines screen-space; the window marks the bezel opening we crop
  // the captured photo to.
  final _stackKey = GlobalKey();
  final _windowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _flow = MachineCaptureFlow(vsync: this)..addListener(_onFlowChanged);
    if (!usesGalleryPicker) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(machineControllerProvider).init(),
      );
    }
  }

  void _onFlowChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flow.removeListener(_onFlowChanged);
    _flow.dispose();
    super.dispose();
  }

  /// Measures the bezel window at rest (scale 1) BEFORE pressing — the press is
  /// a visual scale only and must not skew the crop region.
  (Rect?, Size?) _measureWindow() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final windowBox =
        _windowKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || windowBox == null) return (null, null);
    final origin = stackBox.localToGlobal(Offset.zero);
    final rect =
        (windowBox.localToGlobal(Offset.zero) - origin) & windowBox.size;
    return (rect, stackBox.size);
  }

  Future<void> _onShutter() async {
    final machine = ref.read(machineControllerProvider);
    final useGallery = usesGalleryPicker || machine.error != null;

    final Uint8List? bytes;
    if (useGallery) {
      bytes = await _flow.pickFromGallery();
    } else {
      final (windowRect, screenSize) = _measureWindow();
      bytes = await _flow.captureFromCamera(
        machine,
        windowRect: windowRect,
        screenSize: screenSize,
      );
    }

    if (!mounted || bytes == null) return;
    await _ejectAndDescribe(bytes);
  }

  Future<void> _onPick() async {
    final bytes = await _flow.pickFromGallery();
    if (!mounted || bytes == null) return;
    await _ejectAndDescribe(bytes);
  }

  /// Ejects the freshly-stamped photo, then opens the description screen.
  Future<void> _ejectAndDescribe(Uint8List bytes) async {
    await _flow.eject(bytes);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PreviewScreen(image: bytes)));
    if (!mounted) return;
    _flow.reset();
  }

  @override
  Widget build(BuildContext context) {
    final ejectImage = _flow.ejectImage;
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildContent(),
        if (ejectImage != null)
          EjectOverlay(animation: _flow.ejectAnimation, image: ejectImage),
      ],
    );
  }

  Widget _buildContent() {
    if (usesGalleryPicker) {
      return FallbackView(
        ready: true,
        enabled: !_flow.busy,
        onShutter: _onShutter,
      );
    }

    final machine = ref.watch(machineControllerProvider);
    final cam = machine.controller;
    final cameraLive =
        machine.switching ||
        (machine.error == null && cam != null && cam.value.isInitialized);

    if (cameraLive) {
      return CameraView(
        machine: machine,
        stackKey: _stackKey,
        windowKey: _windowKey,
        pressed: _flow.pressed,
        busy: _flow.busy,
        onShutter: _onShutter,
        onShutterPressedChanged: (p) => _flow.pressed = p,
        onPick: _onPick,
        onFlip: () => machine.switchCamera(),
        onToggleFlash: () => machine.cycleFlash(),
        onZoomStart: () => _baseZoom = machine.zoom,
        onZoomUpdate: (scale) => machine.setZoom(_baseZoom * scale),
      );
    }

    final ready = machine.error != null;
    return FallbackView(
      ready: ready,
      enabled: !_flow.busy && ready,
      onShutter: _onShutter,
    );
  }
}
```

- [ ] **Step 2: Kiểm chứng bằng phân tích tĩnh**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`, tất cả test PASS.

- [ ] **Step 3: Xác nhận kích thước file**

```bash
wc -l lib/features/machine/*.dart lib/features/machine/widgets/*.dart
```

Expected: không file nào vượt 210 dòng; `machine_screen.dart` khoảng 150 dòng.

- [ ] **Step 4: Kiểm thử thủ công trên thiết bị thật**

Chạy `flutter run` trên iOS hoặc Android thật (không phải simulator) và xác nhận
từng mục:

1. Camera trực tiếp hiện lên, khung máy nằm đúng chỗ như trước.
2. Bấm shutter: máy nhấn xuống, giữ, chụp, bật lại, stamp nhả ra, sang màn hình
   mô tả.
3. Quay lại từ màn mô tả: overlay eject biến mất, shutter dùng lại được.
4. Nút gallery: chọn ảnh → eject → màn mô tả. Huỷ chọn → shutter dùng lại được.
5. Lật camera: preview chuyển sang camera trước, ảnh chụp không bị soi gương.
6. Đổi flash: icon đổi off → auto → always.
7. Pinch zoom: badge zoom đổi mượt, preview không giật.
8. Tab Book: ảnh mới xuất hiện đúng nhóm tháng; mở detail xem được.

- [ ] **Step 5: Commit**

```bash
git add lib/features/machine/machine_screen.dart
git commit -m "refactor: slim MachineScreen down to state routing"
```

---

## Task 12: Rà soát lần cuối

**Files:** không tạo/sửa file nguồn — chỉ kiểm tra.

- [ ] **Step 1: Kiểm tra không còn màu hardcode trùng token**

```bash
grep -rn "0xFF1C1C1C\|white38\|white24\|PostmarkColors" lib --include="*.dart"
```

Expected: không có kết quả nào trong `lib/features/machine/`. Nếu còn ở file
khác ngoài phạm vi refactor (ví dụ `book/`, `preview/`), để nguyên — ngoài phạm
vi theo spec.

- [ ] **Step 2: Kiểm tra không còn file quá lớn**

```bash
find lib -name "*.dart" -exec wc -l {} + | sort -rn | head -8
```

Expected: file lớn nhất dưới ~245 dòng (`machine_frame.dart` giữ nguyên 241 dòng
— ngoài phạm vi).

- [ ] **Step 3: Kiểm chứng lần cuối**

```bash
flutter analyze && flutter test
```

Expected: `No issues found!`, tất cả test PASS.

- [ ] **Step 4: Commit nếu có chỉnh sửa**

Nếu Step 1–2 phát hiện sót và bạn đã sửa:

```bash
git add -u lib/
git commit -m "refactor: clean up remaining hardcoded values in machine feature"
```

Nếu không có gì để sửa, bỏ qua step này.
