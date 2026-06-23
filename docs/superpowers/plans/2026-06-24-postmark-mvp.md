# Postmark MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the UI-first v1 of Postmark — a live-camera "stamp machine" where pressing the shutter prints the photo into a perforated collectible stamp, captioned, and saved into a Stamp Book grouped by month.

**Architecture:** Feature-first Flutter app with Riverpod state and Go Router navigation. Data sits behind an abstract `StampRepository` with an in-memory implementation (no persistence in v1). A single `PerforatedBorder` CustomPainter is the one source of truth for stamp shape, reused across the live viewfinder, the printed stamp, book tiles, and detail. The print animation is built entirely in Flutter (AnimationController + Tweens), compositing the runtime photo — no Rive/Lottie.

**Tech Stack:** Flutter 3.44 · flutter_riverpod · go_router · camera · uuid · CustomPainter.

---

## File Structure

```
lib/
├── main.dart                                   # ProviderScope + PostmarkApp
├── app/
│   ├── app.dart                                # MaterialApp.router + theme wiring
│   ├── router.dart                             # GoRouter config
│   └── theme.dart                              # paper/metal colors, serif text theme
├── core/
│   └── widgets/
│       └── perforated_border.dart              # StampShape CustomPainter + StampFrame widget
├── domain/
│   └── stamp.dart                              # Stamp model + month-grouping helper
├── data/
│   ├── stamp_repository.dart                   # abstract StampRepository
│   └── in_memory_stamp_repository.dart         # InMemoryStampRepository + Riverpod providers
├── features/
│   ├── machine/
│   │   ├── machine_screen.dart                 # home: live camera in stamp viewfinder + shutter
│   │   ├── machine_controller.dart             # camera lifecycle + capture (Riverpod)
│   │   └── widgets/
│   │       ├── machine_frame.dart              # brushed-metal machine body
│   │       └── shutter_button.dart
│   ├── printing/
│   │   └── printing_screen.dart                # freeze → eject animation → preview
│   ├── preview/
│   │   └── preview_screen.dart                 # caption field + Retake / Save to Book
│   └── book/
│       ├── book_screen.dart                    # grid grouped by month
│       ├── stamp_detail_screen.dart
│       └── widgets/
│           ├── stamp_tile.dart
│           └── month_section.dart
test/
├── domain/stamp_test.dart
├── data/in_memory_stamp_repository_test.dart
└── core/perforated_border_test.dart
```

Test strategy: pure-Dart units (model, month grouping, repository) get real failing-first tests via `flutter test`. Camera/animation/screen widgets that depend on platform plugins are verified by **running the app** with explicit expected behavior, since the `camera` plugin cannot initialize in the headless test harness.

---

## Task 0: Project setup — dependencies, entry point, theme, router shell

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Create: `lib/app/app.dart`
- Create: `lib/app/theme.dart`
- Create: `lib/app/router.dart`

- [ ] **Step 1: Add dependencies**

Run:
```bash
flutter pub add flutter_riverpod go_router camera uuid
```
Expected: `pubspec.yaml` gains `flutter_riverpod`, `go_router`, `camera`, `uuid`; `flutter pub get` runs clean.

- [ ] **Step 2: Create the theme**

Create `lib/app/theme.dart`:
```dart
import 'package:flutter/material.dart';

/// Paper + brushed-metal palette. Warm, quiet, non-social.
class PostmarkColors {
  static const paper = Color(0xFFF2EFE9);
  static const ink = Color(0xFF2B2B2B);
  static const metalLight = Color(0xFFD9D9D9);
  static const metalDark = Color(0xFF8A8A8A);
  static const slot = Color(0xFF1C1C1C);
}

ThemeData buildPostmarkTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: PostmarkColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: PostmarkColors.ink,
      surface: PostmarkColors.paper,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'serif',
      bodyColor: PostmarkColors.ink,
      displayColor: PostmarkColors.ink,
    ),
  );
}
```

- [ ] **Step 3: Create the router shell (placeholder routes wired in later tasks)**

Create `lib/app/router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/machine/machine_screen.dart';
import '../features/book/book_screen.dart';
import '../features/book/stamp_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const MachineScreen()),
    GoRoute(path: '/book', builder: (_, __) => const BookScreen()),
    GoRoute(
      path: '/book/:id',
      builder: (_, state) =>
          StampDetailScreen(stampId: state.pathParameters['id']!),
    ),
  ],
);
```
Note: `printing` and `preview` are pushed imperatively with in-memory image bytes (not via URL), wired in Task 6–7. This file will not compile until the screens referenced exist; that is expected — it compiles after Task 5, 8, 9. Create placeholder screens now if implementing strictly top-to-bottom (see Step 5).

- [ ] **Step 4: Create the app widget**

Create `lib/app/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'app/../app/theme.dart';
import 'router.dart';

class PostmarkApp extends StatelessWidget {
  const PostmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Postmark',
      debugShowCheckedModeBanner: false,
      theme: buildPostmarkTheme(),
      routerConfig: appRouter,
    );
  }
}
```
Correct the import to `import 'theme.dart';` (same folder). Final imports:
```dart
import 'package:flutter/material.dart';
import 'theme.dart';
import 'router.dart';
```

- [ ] **Step 5: Replace main.dart**

Replace entire `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  runApp(const ProviderScope(child: PostmarkApp()));
}
```

To keep the project compiling before later screens exist, create temporary placeholders (replaced in Tasks 5/8/9):
- `lib/features/machine/machine_screen.dart`, `lib/features/book/book_screen.dart`, `lib/features/book/stamp_detail_screen.dart`, each a minimal `StatelessWidget` returning `const Scaffold()`. `StampDetailScreen` takes `final String stampId;` constructor param.

- [ ] **Step 6: Verify it builds**

Run: `flutter analyze`
Expected: No errors (warnings about unused params on placeholders are fine).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/
git commit -m "chore: project shell — deps, theme, router, app entry"
```

---

## Task 1: Stamp domain model

**Files:**
- Create: `lib/domain/stamp.dart`
- Test: `test/domain/stamp_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/stamp_test.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/domain/stamp.dart';

void main() {
  test('Stamp holds image, date, optional caption', () {
    final img = Uint8List.fromList([1, 2, 3]);
    final s = Stamp(
      id: 'a1',
      image: img,
      date: DateTime(2026, 6, 24),
      caption: 'sunset',
    );
    expect(s.id, 'a1');
    expect(s.image, img);
    expect(s.date, DateTime(2026, 6, 24));
    expect(s.caption, 'sunset');
  });

  test('caption is optional', () {
    final s = Stamp(
      id: 'a2',
      image: Uint8List(0),
      date: DateTime(2026, 5, 1),
    );
    expect(s.caption, isNull);
  });

  test('groupByMonth groups and sorts newest month first', () {
    Stamp at(int y, int m, int d) => Stamp(
          id: '$y-$m-$d',
          image: Uint8List(0),
          date: DateTime(y, m, d),
        );
    final stamps = [at(2026, 5, 2), at(2026, 6, 10), at(2026, 6, 1)];
    final groups = groupByMonth(stamps);

    expect(groups.length, 2);
    expect(groups.first.label, 'June 2026');
    expect(groups.first.stamps.length, 2);
    // within a month, newest day first
    expect(groups.first.stamps.first.date.day, 10);
    expect(groups.last.label, 'May 2026');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/stamp_test.dart`
Expected: FAIL — `Stamp` / `groupByMonth` not defined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/domain/stamp.dart`:
```dart
import 'dart:typed_data';

class Stamp {
  const Stamp({
    required this.id,
    required this.image,
    required this.date,
    this.caption,
  });

  final String id;
  final Uint8List image;
  final DateTime date;
  final String? caption;
}

class MonthGroup {
  const MonthGroup({required this.label, required this.stamps});
  final String label; // e.g. "June 2026"
  final List<Stamp> stamps;
}

const _monthNames = [
  '', 'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Groups stamps by (year, month), newest month first, newest day first.
List<MonthGroup> groupByMonth(List<Stamp> stamps) {
  final byKey = <int, List<Stamp>>{};
  for (final s in stamps) {
    final key = s.date.year * 100 + s.date.month;
    byKey.putIfAbsent(key, () => []).add(s);
  }
  final keys = byKey.keys.toList()..sort((a, b) => b.compareTo(a));
  return keys.map((k) {
    final list = byKey[k]!..sort((a, b) => b.date.compareTo(a.date));
    final year = k ~/ 100;
    final month = k % 100;
    return MonthGroup(label: '${_monthNames[month]} $year', stamps: list);
  }).toList();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/stamp_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/stamp.dart test/domain/stamp_test.dart
git commit -m "feat: Stamp model + month grouping"
```

---

## Task 2: Stamp repository (abstract + in-memory) and Riverpod providers

**Files:**
- Create: `lib/data/stamp_repository.dart`
- Create: `lib/data/in_memory_stamp_repository.dart`
- Test: `test/data/in_memory_stamp_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/in_memory_stamp_repository_test.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/data/in_memory_stamp_repository.dart';

void main() {
  test('starts empty', () {
    final repo = InMemoryStampRepository();
    expect(repo.state, isEmpty);
  });

  test('add inserts a stamp with a generated id and returns it', () {
    final repo = InMemoryStampRepository();
    final s = repo.add(image: Uint8List.fromList([9]), caption: 'hi');
    expect(s.id, isNotEmpty);
    expect(repo.state.length, 1);
    expect(repo.state.single.caption, 'hi');
  });

  test('byId returns the matching stamp or null', () {
    final repo = InMemoryStampRepository();
    final s = repo.add(image: Uint8List(0));
    expect(repo.byId(s.id)?.id, s.id);
    expect(repo.byId('missing'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/in_memory_stamp_repository_test.dart`
Expected: FAIL — `InMemoryStampRepository` not defined.

- [ ] **Step 3: Write the abstract interface**

Create `lib/data/stamp_repository.dart`:
```dart
import 'dart:typed_data';
import '../domain/stamp.dart';

abstract class StampRepository {
  List<Stamp> get state;
  Stamp add({required Uint8List image, String? caption});
  Stamp? byId(String id);
}
```

- [ ] **Step 4: Write the in-memory implementation + providers**

Create `lib/data/in_memory_stamp_repository.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/stamp.dart';
import 'stamp_repository.dart';

class InMemoryStampRepository extends StateNotifier<List<Stamp>>
    implements StampRepository {
  InMemoryStampRepository() : super(const []);

  static const _uuid = Uuid();

  @override
  Stamp add({required Uint8List image, String? caption}) {
    final stamp = Stamp(
      id: _uuid.v4(),
      image: image,
      date: DateTime.now(),
      caption: (caption != null && caption.trim().isNotEmpty)
          ? caption.trim()
          : null,
    );
    state = [...state, stamp];
    return stamp;
  }

  @override
  Stamp? byId(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// The repository as a StateNotifier so widgets rebuild on change.
final stampRepositoryProvider =
    StateNotifierProvider<InMemoryStampRepository, List<Stamp>>(
  (ref) => InMemoryStampRepository(),
);

/// Convenience: stamps grouped by month for the Stamp Book.
final stampGroupsProvider = Provider<List<MonthGroup>>((ref) {
  final stamps = ref.watch(stampRepositoryProvider);
  return groupByMonth(stamps);
});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/in_memory_stamp_repository_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/ test/data/
git commit -m "feat: StampRepository interface + in-memory impl + providers"
```

---

## Task 3: PerforatedBorder — the stamp shape (CustomPainter)

**Files:**
- Create: `lib/core/widgets/perforated_border.dart`
- Test: `test/core/perforated_border_test.dart`

- [ ] **Step 1: Write the failing test (geometry helper)**

We unit-test the scallop-count math (deterministic), not pixels.

Create `test/core/perforated_border_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:postmark/core/widgets/perforated_border.dart';

void main() {
  test('scallopCount fits whole notches across a side', () {
    // side 100, target radius 10 => diameter 20 => 5 notches
    expect(scallopCount(100, 10), 5);
  });

  test('scallopCount is at least 1', () {
    expect(scallopCount(5, 10), 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/perforated_border_test.dart`
Expected: FAIL — `scallopCount` not defined.

- [ ] **Step 3: Implement the painter + widget**

Create `lib/core/widgets/perforated_border.dart`:
```dart
import 'package:flutter/material.dart';

/// Number of semicircular notches that fit along a side of the given length
/// for a target notch radius. Always >= 1.
int scallopCount(double sideLength, double radius) {
  final n = (sideLength / (radius * 2)).floor();
  return n < 1 ? 1 : n;
}

/// Paints a classic stamp: white paper rectangle whose outer edge is cut into
/// even semicircular notches on all four sides, with a soft drop shadow.
/// The [child] (image) is clipped to the inner notched paper area.
class StampFrame extends StatelessWidget {
  const StampFrame({
    super.key,
    required this.child,
    this.notchRadius = 7,
    this.paperInset = 10,
  });

  final Widget child;
  final double notchRadius;
  final double paperInset; // white border thickness around the image

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StampShadowPainter(notchRadius: notchRadius),
      child: ClipPath(
        clipper: _StampClipper(notchRadius: notchRadius),
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(paperInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: child,
          ),
        ),
      ),
    );
  }
}

Path _stampPath(Size size, double r) {
  // Build a rectangle outline with outward... actually inward semicircle
  // notches (the paper is removed at each notch) along every side.
  final path = Path();
  final cols = scallopCount(size.width, r);
  final rows = scallopCount(size.height, r);
  final dx = size.width / cols;
  final dy = size.height / rows;

  path.moveTo(0, 0);
  // top edge, left -> right, notches dip downward (into the paper)
  for (var i = 0; i < cols; i++) {
    final cx = dx * i + dx / 2;
    path.lineTo(cx - r, 0);
    path.arcToPoint(Offset(cx + r, 0),
        radius: Radius.circular(r), clockwise: false);
  }
  path.lineTo(size.width, 0);
  // right edge, top -> bottom, notches dip leftward
  for (var i = 0; i < rows; i++) {
    final cy = dy * i + dy / 2;
    path.lineTo(size.width, cy - r);
    path.arcToPoint(Offset(size.width, cy + r),
        radius: Radius.circular(r), clockwise: false);
  }
  path.lineTo(size.width, size.height);
  // bottom edge, right -> left, notches dip upward
  for (var i = 0; i < cols; i++) {
    final cx = size.width - (dx * i + dx / 2);
    path.lineTo(cx + r, size.height);
    path.arcToPoint(Offset(cx - r, size.height),
        radius: Radius.circular(r), clockwise: false);
  }
  path.lineTo(0, size.height);
  // left edge, bottom -> top, notches dip rightward
  for (var i = 0; i < rows; i++) {
    final cy = size.height - (dy * i + dy / 2);
    path.lineTo(0, cy + r);
    path.arcToPoint(Offset(0, cy - r),
        radius: Radius.circular(r), clockwise: false);
  }
  path.close();
  return path;
}

class _StampClipper extends CustomClipper<Path> {
  _StampClipper({required this.notchRadius});
  final double notchRadius;

  @override
  Path getClip(Size size) => _stampPath(size, notchRadius);

  @override
  bool shouldReclip(_StampClipper old) => old.notchRadius != notchRadius;
}

class _StampShadowPainter extends CustomPainter {
  _StampShadowPainter({required this.notchRadius});
  final double notchRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _stampPath(size, notchRadius);
    canvas.drawShadow(path, Colors.black.withOpacity(0.4), 6, false);
  }

  @override
  bool shouldRepaint(_StampShadowPainter old) =>
      old.notchRadius != notchRadius;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/perforated_border_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Visual smoke check**

Temporarily set `MachineScreen` placeholder body (or a scratch route) to
`Center(child: SizedBox(width: 240, height: 320, child: StampFrame(child: Container(color: Colors.orange))))`
Run: `flutter run` → confirm a white stamp with even notches and a soft shadow over an orange fill. Revert the scratch change after confirming.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/perforated_border.dart test/core/perforated_border_test.dart
git commit -m "feat: StampFrame perforated-border painter"
```

---

## Task 4: Machine frame + shutter button widgets

**Files:**
- Create: `lib/features/machine/widgets/machine_frame.dart`
- Create: `lib/features/machine/widgets/shutter_button.dart`

- [ ] **Step 1: Build the brushed-metal machine body**

Create `lib/features/machine/widgets/machine_frame.dart`:
```dart
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Brushed-metal machine body with a dark recessed slot that hosts [slotChild]
/// (the live viewfinder or a printed stamp).
class MachineFrame extends StatelessWidget {
  const MachineFrame({super.key, required this.slotChild});
  final Widget slotChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(48),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PostmarkColors.metalLight, PostmarkColors.metalDark],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            color: PostmarkColors.slot,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: slotChild,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Build the shutter button**

Create `lib/features/machine/widgets/shutter_button.dart`:
```dart
import 'package:flutter/material.dart';

class ShutterButton extends StatelessWidget {
  const ShutterButton({super.key, required this.onPressed, this.enabled = true});
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.black26, width: 4),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify analyze**

Run: `flutter analyze lib/features/machine/widgets/`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/machine/widgets/
git commit -m "feat: machine frame + shutter button widgets"
```

---

## Task 5: Machine screen — live camera viewfinder + capture

**Files:**
- Create: `lib/features/machine/machine_controller.dart`
- Create/replace: `lib/features/machine/machine_screen.dart` (replaces Task 0 placeholder)
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add camera permissions**

In `ios/Runner/Info.plist`, add inside the top-level `<dict>`:
```xml
<key>NSCameraUsageDescription</key>
<string>Postmark uses the camera to print your photos into stamps.</string>
```
In `android/app/src/main/AndroidManifest.xml`, add above `<application>`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

- [ ] **Step 2: Camera controller (Riverpod)**

Create `lib/features/machine/machine_controller.dart`:
```dart
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the CameraController lifecycle. Exposes init + capture.
class MachineController extends ChangeNotifier {
  CameraController? controller;
  bool initializing = false;
  String? error;

  Future<void> init() async {
    if (controller != null || initializing) return;
    initializing = true;
    notifyListeners();
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final c = CameraController(back, ResolutionPreset.high,
          enableAudio: false);
      await c.initialize();
      controller = c;
    } catch (e) {
      error = e.toString();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  /// Captures a frame and returns its JPEG bytes.
  Future<Uint8List?> capture() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return null;
    final file = await c.takePicture();
    return file.readAsBytes();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

final machineControllerProvider =
    ChangeNotifierProvider<MachineController>((ref) {
  final m = MachineController();
  ref.onDispose(m.dispose);
  return m;
});
```

- [ ] **Step 3: Machine screen**

Replace `lib/features/machine/machine_screen.dart`:
```dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/perforated_border.dart';
import 'machine_controller.dart';
import 'widgets/machine_frame.dart';
import 'widgets/shutter_button.dart';
import '../printing/printing_screen.dart';

class MachineScreen extends ConsumerStatefulWidget {
  const MachineScreen({super.key});
  @override
  ConsumerState<MachineScreen> createState() => _MachineScreenState();
}

class _MachineScreenState extends ConsumerState<MachineScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(machineControllerProvider).init(),
    );
  }

  Future<void> _onShutter() async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes = await ref.read(machineControllerProvider).capture();
    if (!mounted) return;
    setState(() => _busy = false);
    if (bytes == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PrintingScreen(image: bytes)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(machineControllerProvider);
    final cam = m.controller;

    Widget viewfinder;
    if (cam != null && cam.value.isInitialized) {
      viewfinder = StampFrame(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: cam.value.previewSize!.height,
            height: cam.value.previewSize!.width,
            child: CameraPreview(cam),
          ),
        ),
      );
    } else {
      viewfinder = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: () => context.push('/book'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: MachineFrame(slotChild: viewfinder),
            ),
            const Spacer(),
            ShutterButton(
              onPressed: _onShutter,
              enabled: !_busy && cam != null && cam.value.isInitialized,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify on device**

Run: `flutter run` on a physical device or simulator with a camera.
Expected: machine body with live camera framed as a notched stamp; shutter enabled once camera is ready; book icon in app bar pushes `/book`. Pressing shutter navigates to the printing screen (blank until Task 6).

- [ ] **Step 5: Commit**

```bash
git add lib/features/machine/ ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "feat: machine screen with live camera stamp viewfinder + capture"
```

---

## Task 6: Printing screen — freeze → eject animation

**Files:**
- Create/replace: `lib/features/printing/printing_screen.dart`

- [ ] **Step 1: Build the printing animation**

Create `lib/features/printing/printing_screen.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../core/widgets/perforated_border.dart';
import '../preview/preview_screen.dart';

/// Freezes the captured photo, then animates the stamp ejecting upward out of
/// the machine slot, then reveals the Preview screen.
class PrintingScreen extends StatefulWidget {
  const PrintingScreen({super.key, required this.image});
  final Uint8List image;

  @override
  State<PrintingScreen> createState() => _PrintingScreenState();
}

class _PrintingScreenState extends State<PrintingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _flash;
  late final Animation<double> _eject;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _flash = CurvedAnimation(
        parent: _c, curve: const Interval(0.0, 0.12, curve: Curves.easeOut));
    _eject = CurvedAnimation(
        parent: _c, curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack));
    _c.forward().whenComplete(_goToPreview);
  }

  void _goToPreview() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => PreviewScreen(image: widget.image)),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final dy = (1 - _eject.value) * 220; // slides up into place
          final scale = 0.85 + _eject.value * 0.15;
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: 240,
                      height: 320,
                      child: StampFrame(
                        child: Image.memory(widget.image, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Opacity(
                  opacity: (1 - _flash.value).clamp(0.0, 1.0) *
                      (_c.value < 0.12 ? 1 : 0),
                  child: Container(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify on device**

Run: `flutter run`, press shutter.
Expected: brief white flash, then the captured photo as a notched stamp slides up and settles, then the Preview screen appears.

- [ ] **Step 3: Commit**

```bash
git add lib/features/printing/
git commit -m "feat: printing screen freeze+eject animation"
```

---

## Task 7: Preview screen — caption + Retake / Save to Book

**Files:**
- Create/replace: `lib/features/preview/preview_screen.dart`

- [ ] **Step 1: Build the preview screen**

Create `lib/features/preview/preview_screen.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/perforated_border.dart';
import '../../data/in_memory_stamp_repository.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key, required this.image});
  final Uint8List image;

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(stampRepositoryProvider.notifier).add(
          image: widget.image,
          caption: _caption.text,
        );
    // Clear the printing/preview stack, land in the book.
    context.go('/book');
  }

  void _retake() => Navigator.of(context).pop(); // back to machine

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  width: 240,
                  height: 320,
                  child: StampFrame(
                    child: Image.memory(widget.image, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Caption',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, fontSize: 16)),
                  Text('Optional', style: TextStyle(color: Colors.black45)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('A few words to keep the moment with the stamp.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              TextField(
                controller: _caption,
                decoration: const InputDecoration(
                  hintText: 'What do you see?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _retake,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      child: const Text('Save to Book'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify on device**

Run: `flutter run`. Capture → preview shows stamp + caption field + buttons.
Type a caption, tap **Save to Book** → navigates to `/book`. Tap **Retake** instead → returns to machine.

- [ ] **Step 3: Commit**

```bash
git add lib/features/preview/
git commit -m "feat: preview screen with caption and save/retake"
```

---

## Task 8: Stamp Book — grid grouped by month

**Files:**
- Create: `lib/features/book/widgets/stamp_tile.dart`
- Create: `lib/features/book/widgets/month_section.dart`
- Create/replace: `lib/features/book/book_screen.dart` (replaces Task 0 placeholder)

- [ ] **Step 1: Stamp tile**

Create `lib/features/book/widgets/stamp_tile.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/perforated_border.dart';
import '../../../domain/stamp.dart';

class StampTile extends StatelessWidget {
  const StampTile({super.key, required this.stamp});
  final Stamp stamp;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/book/${stamp.id}'),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: StampFrame(
          notchRadius: 5,
          paperInset: 6,
          child: Image.memory(stamp.image, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Month section**

Create `lib/features/book/widgets/month_section.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../domain/stamp.dart';
import 'stamp_tile.dart';

class MonthSection extends StatelessWidget {
  const MonthSection({super.key, required this.group});
  final MonthGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
          child: Text(group.label,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600)),
        ),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3 / 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final s in group.stamps) StampTile(stamp: s)],
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Book screen**

Replace `lib/features/book/book_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/in_memory_stamp_repository.dart';
import 'widgets/month_section.dart';

class BookScreen extends ConsumerWidget {
  const BookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(stampGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stamp Book'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: groups.isEmpty
          ? const Center(
              child: Text('No stamps yet.\nPrint your first one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [for (final g in groups) MonthSection(group: g)],
            ),
    );
  }
}
```

- [ ] **Step 4: Verify on device**

Run: `flutter run`. Save a couple of stamps across the session.
Expected: book shows a month header (e.g. "June 2026") with a 3-column grid of notched stamp tiles, newest first; empty state shows when no stamps.

- [ ] **Step 5: Commit**

```bash
git add lib/features/book/
git commit -m "feat: stamp book grid grouped by month"
```

---

## Task 9: Stamp Detail screen

**Files:**
- Create/replace: `lib/features/book/stamp_detail_screen.dart` (replaces Task 0 placeholder)

- [ ] **Step 1: Build the detail screen**

Replace `lib/features/book/stamp_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/perforated_border.dart';
import '../../data/in_memory_stamp_repository.dart';

class StampDetailScreen extends ConsumerWidget {
  const StampDetailScreen({super.key, required this.stampId});
  final String stampId;

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamp = ref.read(stampRepositoryProvider.notifier).byId(stampId);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: stamp == null
          ? const Center(child: Text('Stamp not found.'))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: StampFrame(
                            child:
                                Image.memory(stamp.image, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (stamp.caption != null)
                      Text(stamp.caption!,
                          style: const TextStyle(
                              fontSize: 20, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Text(_formatDate(stamp.date),
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
    );
  }
}
```

- [ ] **Step 2: Verify on device**

Run: `flutter run`. Tap a stamp tile in the book.
Expected: large notched stamp + caption (if any) + formatted date.

- [ ] **Step 3: Commit**

```bash
git add lib/features/book/stamp_detail_screen.dart
git commit -m "feat: stamp detail screen"
```

---

## Task 10: End-to-end pass + cleanup

**Files:**
- Modify: any leftover placeholder/scratch code

- [ ] **Step 1: Full analyze + tests**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all unit tests pass.

- [ ] **Step 2: Full manual flow on device**

Run: `flutter run` and walk the loop:
1. Machine shows live camera as a stamp.
2. Shutter → flash → eject animation → preview.
3. Caption + Save to Book → lands in book, stamp present under correct month.
4. Tap stamp → detail with caption + date.
5. Back to machine, print a second stamp → appears in book newest-first.
6. Retake path returns to machine without saving.

Confirm each step. Note any rough edges (timing, sizing) and adjust constants
(`PrintingScreen` durations/offsets, `StampFrame.notchRadius`) to taste.

- [ ] **Step 3: Commit any cleanup**

```bash
git add -A
git commit -m "chore: end-to-end cleanup for Postmark MVP"
```

---

## Self-Review Notes

- **Spec coverage:** Machine live-camera stamp viewfinder (T5) · shutter print animation (T6) · caption + Retake/Save (T7) · Stamp Book grouped by month (T8) · Stamp Detail (T9) · in-memory repository behind abstract interface (T2) · shared PerforatedBorder (T3) · theme/router/deps (T0). Location, auth, persistence, machine-picker, filters are explicitly out of scope per spec.
- **Type consistency:** `StampFrame` signature (`child`, `notchRadius`, `paperInset`) used identically in T3/T5/T6/T7/T8/T9. `stampRepositoryProvider` (StateNotifier) + `stampGroupsProvider` defined T2, consumed T7/T8/T9. `Stamp`/`MonthGroup`/`groupByMonth` defined T1, consumed T2/T8. `PrintingScreen(image:)`, `PreviewScreen(image:)`, `StampDetailScreen(stampId:)` constructors consistent across navigation calls.
- **No placeholders:** every code step contains full code; verification steps give exact run commands and expected behavior.
