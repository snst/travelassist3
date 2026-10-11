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
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (!context.mounted) return;

    onChanged(
      DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? value.hour,
        time?.minute ?? value.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(formatDateTime(value)),
      trailing: const Icon(Icons.edit_calendar),
      onTap: () => _pickDateTime(context),
    );
  }
}
