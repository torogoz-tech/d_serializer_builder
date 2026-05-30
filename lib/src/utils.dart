String toSnakeCase(String input) {
  final chars = input.split('');
  final result = <String>[];
  for (var i = 0; i < chars.length; i++) {
    final c = chars[i];
    if (c == c.toUpperCase() && c != c.toLowerCase()) {
      if (i > 0) result.add('_');
      result.add(c.toLowerCase());
    } else {
      result.add(c);
    }
  }
  return result.join();
}
