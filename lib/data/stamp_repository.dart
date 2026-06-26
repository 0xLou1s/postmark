import 'dart:typed_data';
import '../domain/stamp.dart';

abstract class StampRepository {
  List<Stamp> get state;
  Stamp add({required Uint8List image, String? caption});
  Stamp? byId(String id);
}
