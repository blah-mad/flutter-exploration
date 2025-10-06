String formatShortDate(DateTime date) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final DateTime local = date.toLocal();
  final String month = months[local.month - 1];
  final String day = local.day.toString().padLeft(2, '0');
  final String year = local.year.toString();
  return '$day $month $year';
}

String formatRelative(DateTime timestamp) {
  final DateTime now = DateTime.now().toUtc();
  final Duration delta = now.difference(timestamp);
  if (delta.inMinutes < 1) {
    return 'just now';
  }
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes} min ago';
  }
  if (delta.inHours < 24) {
    return '${delta.inHours} h ago';
  }
  if (delta.inDays < 7) {
    return '${delta.inDays} d ago';
  }
  return formatShortDate(timestamp);
}
