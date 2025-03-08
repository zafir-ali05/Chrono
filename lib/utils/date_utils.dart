String getDueInDays(DateTime dueDate) {
  final now = DateTime.now();
  // Reset time components to compare just the dates
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final difference = due.difference(today).inDays;
  
  if (difference < 0) {
    return 'Overdue by ${-difference} days';
  } else if (difference == 0) {
    return 'Due today';
  } else if (difference == 1) {
    return 'Due tomorrow';
  } else {
    return 'Due in $difference days';
  }
}

String getShortDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final dateToCheck = DateTime(date.year, date.month, date.day);
  
  if (dateToCheck == today) {
    return 'Today';
  } else if (dateToCheck == tomorrow) {
    return 'Tomorrow';
  } else {
    // Format as "Mon 12" or similar
    final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = dayNames[date.weekday];
    return '$dayName ${date.day}';
  }
}
