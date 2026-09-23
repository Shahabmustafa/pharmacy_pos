/// Storage type values stored on [Medicines.storageType].
class StorageType {
  StorageType._();

  static const String normal = 'normal';
  static const String refrigerated = 'refrigerated';
  static const String frozen = 'frozen';

  static const Map<String, String> labels = {
    normal: 'Normal (Room Temp)',
    refrigerated: 'Refrigerated (Cold Storage)',
    frozen: 'Frozen',
  };

  static String labelFor(String? value) => labels[value] ?? labels[normal]!;

  static bool needsCold(String? value) => value == refrigerated || value == frozen;
}
