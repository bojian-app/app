/// Display-only fallback: never write this placeholder back into profile data.
String userDisplayName(Object? value) {
  final name = value?.toString().trim() ?? '';
  return name.isEmpty ? '未设置用户昵称' : name;
}
