import 'package:flutter/material.dart';

class EntryDatePickerHelper {
  /// Prompts the user to pick an entry date before updating.
  /// Defaults to the entry's original creation date.
  /// Preserves the original time of day.
  /// Returns the updated ISO 8601 string, or null if cancelled/dismissed.
  static Future<String?> promptEntryDate(
    BuildContext context, {
    required String currentTimestamp,
    String? helpText,
  }) async {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(currentTimestamp);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final now = DateTime.now();
    final firstDate = DateTime(2000);
    final lastDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    DateTime initialDate;
    if (dateOnly.isAfter(lastDate)) {
      initialDate = DateTime(now.year, now.month, now.day);
    } else if (dateOnly.isBefore(firstDate)) {
      initialDate = firstDate;
    } else {
      initialDate = dateOnly;
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText ?? 'Select Entry Date',
    );

    if (pickedDate == null) {
      return null;
    }

    // Preserve original time of day
    final updatedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      parsedDate.hour,
      parsedDate.minute,
      parsedDate.second,
      parsedDate.millisecond,
      parsedDate.microsecond,
    );

    return updatedDateTime.toIso8601String();
  }
}
