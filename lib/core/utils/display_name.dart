/// Turns an email handle into a friendly name: `jian.ming@x.com` → `Jian Ming`.
/// Falls back to `Athlete` when there is no email (demo mode).
String displayNameFromEmail(String? email) {
  if (email == null || email.isEmpty) return 'Athlete';
  return email
      .split('@')
      .first
      .split(RegExp(r'[._-]'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0].toUpperCase() + s.substring(1))
      .join(' ');
}
