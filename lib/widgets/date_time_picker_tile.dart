import 'package:flutter/material.dart';

import '../utils/date_format.dart';

class DateTimePickerTile extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  const DateTimePickerTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;

    onChanged(
      DateTime(
        date.year,
        date.month,
        date.day,
        12,
        0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: const Icon(Icons.event),
      title: Text(formatDay(value)),
      //trailing: const Icon(Icons.edit_calendar),
      onTap: () => _pickDateTime(context),
    );
  }
}
