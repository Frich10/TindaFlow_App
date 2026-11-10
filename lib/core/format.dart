const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

/// ₱1,234 (whole numbers) or ₱1,234.50. Pass [decimals] to always show 2 decimals.
String peso(num value, {bool decimals = false}) {
  final v = value.toDouble();
  final neg = v < 0;
  final a = v.abs();
  final showDecimals = decimals || a != a.roundToDouble();
  final fixed = a.toStringAsFixed(showDecimals ? 2 : 0);
  final parts = fixed.split('.');
  final s = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final out = '₱$buf${parts.length > 1 ? '.${parts[1]}' : ''}';
  return neg ? '-$out' : out;
}

double parseMoney(String s) => double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

String _two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
String fmtDateLong(DateTime d) => '${_monthsLong[d.month - 1]} ${d.day}, ${d.year}';
String fmtMonth(int month) => _months[month - 1];

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${_two(d.minute)} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String fmtDateTime(DateTime d) => '${fmtDate(d)} • ${fmtTime(d)}';

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
