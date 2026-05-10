/// Remove all matching header keys regardless of case.
void removeHeaderCaseInsensitive(Map<String, dynamic> headers, String name) {
  final normalizedName = name.toLowerCase();
  headers.removeWhere((key, _) => key.toLowerCase() == normalizedName);
}
