# Postmark — MVP Design Spec

**Date:** 2026-06-24
**Status:** Approved (UI-first v1, no persistence)

## Vision

Postmark là một cuốn album kỹ thuật số nơi mỗi bức ảnh được "đóng dấu" thành một
con tem sưu tầm. Thay vì lưu ảnh vô tận trong gallery, người dùng chọn những
khoảnh khắc đáng nhớ để biến thành tem và cất vào Stamp Book.

Trọng tâm sản phẩm — và của v1 này — là **khoảnh khắc ảnh đi vào máy và một con
tem được "in" ra**. Nếu animation đó đủ thú vị, người dùng sẽ muốn tạo thêm tem.

**Design vibe:** Apple Journal · Paper Memories · Film Camera · Physical Stamp
Collection. KHÔNG social — không feed, follower, like, comment.

## Phạm vi v1

Mục tiêu: dựng trọn vẹn *cảm giác* "ảnh vào máy → tem in ra → cất vào sổ".

**Trong phạm vi:**
- 4 màn hình: Machine, Printing→Preview, Stamp Book, Stamp Detail.
- Live camera hiển thị trực tiếp trong khe máy, đã mask sẵn theo hình tem (WYSIWYG).
- Animation "in tem" khi bấm shutter.
- Lưu tem vào bộ nhớ (in-memory) trong phiên chạy.

**Ngoài phạm vi v1 (làm sau):**
- Auth (Anonymous / Apple / Google).
- Lưu trữ vĩnh viễn (SQLite/Drift) và sync/backup (Supabase).
- Chọn "máy" trước khi chụp (mỗi máy = một style filter/khung tem khác nhau).
- Filter / stylize ảnh (AI hoặc preset).
- Collections, Shared Books, Physical Printing (PDF).
- Location trên tem (cần GPS permission).

> v1 KHÔNG persistence: tắt app là mất data. Chấp nhận được — mục tiêu là validate
> cảm giác core loop, không phải lưu trữ.

## Màn hình & Luồng

| # | Màn hình | Vai trò |
|---|----------|---------|
| 1 | **Machine** (home) | Khe máy hiện live camera đã mask theo hình tem (viền răng cưa real-time). Shutter button + nút nhỏ vào Stamp Book. |
| 2 | **Printing → Preview** | Bấm shutter → freeze ảnh → animation tem trồi lên khỏi máy → màn preview tem + ô Caption ("What do you see?") + nút Retake / Save to Book. |
| 3 | **Stamp Book** | Lưới 3 cột, tem nhóm theo Tháng/Năm (vd "June 2026"), mới nhất trên cùng. |
| 4 | **Stamp Detail** | Mở 1 tem: ảnh lớn dạng tem, caption, ngày. |

**Luồng chính:**
```
Machine (live camera trong khung tem răng cưa)
   │ bấm shutter
   ▼
Freeze ảnh → hiệu ứng IN (tem trồi lên khỏi máy)
   │
   ▼
Preview (caption + Retake / Save to Book)
   │ Save to Book                │ Retake → quay lại Machine
   ▼
Stamp Book  ──tap tem──►  Stamp Detail
```

## Kiến trúc

**Stack:** Flutter · Riverpod · Go Router · package `camera` · CustomPainter ·
in-memory repository (v1).

**Nguyên tắc:** Feature-first + tách lớp sạch. Lớp data nằm sau interface trừu
tượng để sau này thay in-memory bằng Drift/Supabase mà không đụng UI.

```
lib/
├── main.dart
├── app/
│   ├── app.dart                  # MaterialApp.router + theme
│   ├── router.dart               # Go Router config
│   └── theme.dart                # màu giấy/kim loại, font serif
├── core/
│   └── widgets/
│       └── perforated_border.dart   # CustomPainter viền tem răng cưa (dùng chung)
├── features/
│   ├── machine/
│   │   ├── machine_screen.dart
│   │   ├── machine_controller.dart   # camera lifecycle, capture
│   │   └── widgets/                  # MachineFrame, StampViewfinder, ShutterButton
│   ├── printing/
│   │   └── printing_screen.dart      # freeze ảnh → tem trồi lên
│   ├── preview/
│   │   ├── preview_screen.dart
│   │   └── preview_controller.dart
│   └── book/
│       ├── book_screen.dart
│       ├── stamp_detail_screen.dart
│       └── widgets/                  # StampTile, MonthSection
├── domain/
│   └── stamp.dart                # model Stamp
└── data/
    ├── stamp_repository.dart            # abstract interface
    └── in_memory_stamp_repository.dart  # impl v1
```

**Điểm mấu chốt:**
- `StampRepository` là interface trừu tượng. v1 dùng `InMemoryStampRepository`
  (giữ `List<Stamp>` qua một StateNotifier). Thay impl sau chỉ cần đổi 1 provider.
- `PerforatedBorder` (CustomPainter) là widget độc lập, là **một nguồn chân lý**
  cho hình dáng con tem, tái dùng ở: viewfinder live, tem in ra, tile trong book,
  detail.
- Mỗi feature tự gói screen + widget + controller riêng → dễ đọc, dễ test.

## Domain Model

```dart
class Stamp {
  final String id;          // uuid sinh khi tạo
  final Uint8List image;    // bytes ảnh đã chụp (v1 in-memory)
  final DateTime date;      // = thời điểm chụp
  final String? caption;    // optional
}
```

Stamp Book group theo `(year, month)` của `date`, sắp xếp giảm dần (mới nhất trước).

## Animation "in tem" (chi tiết)

Một AnimationController chạy chuỗi giai đoạn (~1.2–1.8s tổng):
1. **Shutter flash:** chớp trắng nhanh + freeze frame ảnh vừa chụp.
2. **Eject:** con tem (ảnh đã đóng khung răng cưa) trượt từ trong khe máy **trồi
   lên trên**, kèm scale nhẹ và đổ bóng tăng dần — như tờ tem được nhả ra.
3. **Settle:** tem dừng lại ở vị trí preview, máy lùi xuống/mờ đi, lộ ô caption +
   nút Retake / Save to Book.

Dùng `AnimationController` + `Tween`/`Interval` cho từng giai đoạn; ảnh runtime
được composite trực tiếp trong Flutter (không cần asset Rive/Lottie).

## Viền tem (PerforatedBorder)

CustomPainter vẽ con tem cổ điển:
- Tỉ lệ portrait ~3:4 (khớp ảnh ref).
- Viền giấy trắng quanh ảnh, mép ngoài cắt răng cưa (scallop nửa hình tròn đều
  nhau dọc cả 4 cạnh).
- Clip ảnh theo path răng cưa; vẽ nền giấy trắng; đổ bóng mềm.
- Cùng một painter dùng cho cả live viewfinder (mask đè lên camera preview) lẫn
  tem tĩnh.

## Theme

- Nền: tông giấy off-white (paper).
- Máy: kim loại brushed-steel (PNG asset hoặc gradient + bo góc lớn).
- Font: serif cho caption/header ("A few words to keep the moment with the stamp.").
- Tĩnh lặng, ấm, không rực rỡ — đúng vibe physical stamp collection.

## Điều hướng (Go Router)

| Route | Screen |
|-------|--------|
| `/` | Machine (home) |
| `/printing` | Printing→Preview (nhận ảnh vừa chụp qua state/extra) |
| `/book` | Stamp Book |
| `/book/:id` | Stamp Detail |

(Preview có thể là end-state của printing screen thay vì route riêng — tránh
truyền bytes ảnh qua URL.)

## Quyền hệ thống

- iOS: `NSCameraUsageDescription` trong `Info.plist`.
- Android: `<uses-permission android:name="android.permission.CAMERA"/>`.

## Dependencies cần thêm

`flutter_riverpod`, `go_router`, `camera`, `uuid`. (Không cần Supabase/Drift/Rive
ở v1.)

## Success criteria

- Mở app thấy máy với live camera trong khung tem răng cưa.
- Bấm shutter → animation in tem mượt, đã ra "đời" con tem.
- Nhập caption, Save → tem xuất hiện trong Stamp Book nhóm theo tháng.
- Tap tem trong book → xem detail.
- Toàn bộ chạy mượt trên iOS + Android, không cần mạng/đăng nhập.
