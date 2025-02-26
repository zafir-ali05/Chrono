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
