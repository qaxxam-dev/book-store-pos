class ShopSettings {
  final String key;
  final String value;

  ShopSettings({required this.key, required this.value});

  Map<String, dynamic> toMap() {
    return {'key': key, 'value': value};
  }

  factory ShopSettings.fromMap(Map<String, dynamic> map) {
    return ShopSettings(key: map['key'], value: map['value']);
  }
}
