abstract interface class AppDataRepository {
  Future<String?> read();

  Future<void> write(String jsonText);
}

class MemoryAppDataRepository implements AppDataRepository {
  MemoryAppDataRepository([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String jsonText) async {
    value = jsonText;
  }
}
