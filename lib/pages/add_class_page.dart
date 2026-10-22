import 'package:flutter/material.dart';
import '../main.dart';
import 'package:uuid/uuid.dart';
import '../services/notification_service.dart';

class AddClassPage extends StatefulWidget {
  final Map<String, dynamic>? existingClass;
  final List<Map<String, dynamic>> existingGroupClasses;

  const AddClassPage({
    super.key,
    this.existingClass,
    this.existingGroupClasses = const [],
  });
  @override
  State<AddClassPage> createState() => _AddClassPageState();
}

class _AddClassPageState extends State<AddClassPage> {
  final subjectController = TextEditingController();
  final teacherController = TextEditingController();
  final roomController = TextEditingController();

  bool get isEditing => widget.existingClass != null;

  List<String> selectedDays = [];

  int? startHour;
  int? startMinute;
  String? startPeriod;

  int? endHour;
  int? endMinute;
  String? endPeriod;

  bool reminderEnabled = true;
  int reminderMinutes = 15;

  bool isSaving = false;

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final List<int> hours = List.generate(12, (index) => index + 1);

  final List<int> minutes = [
    0,
    15,
    30,
    45,
  ];

  final List<String> periods = [
    'AM',
    'PM',
  ];

  final List<int> reminderOptions = [
    5,
    10,
    15,
    30,
    60,
  ];

  @override
  void initState() {
    super.initState();

    if (widget.existingClass != null) {
      final classItem = widget.existingClass!;

      subjectController.text = classItem['subject'] ?? '';
      teacherController.text = classItem['teacher'] ?? '';
      roomController.text = classItem['room'] ?? '';

      selectedDays = widget.existingGroupClasses
        .map((item) => item['day'] as String)
        .toList();

      final startParts =
          classItem['start_time'].toString().split(':');

      final endParts =
          classItem['end_time'].toString().split(':');

      setTimeFromDatabase(
        startParts,
        true,
      );

      setTimeFromDatabase(
        endParts,
        false,
      );

      reminderEnabled =
          classItem['reminder_enabled'] ?? true;

      reminderMinutes =
          classItem['reminder_minutes'] ?? 15;
    }
  }

  void setTimeFromDatabase(
    List<String> parts,
    bool isStartTime,
  ) {
    int hour24 = int.parse(parts[0]);
    int minute = int.parse(parts[1]);

    String period = hour24 >= 12 ? 'PM' : 'AM';

    int hour12;

    if (hour24 == 0) {
      hour12 = 12;
    } else if (hour24 > 12) {
      hour12 = hour24 - 12;
    } else {
      hour12 = hour24;
    }

    if (isStartTime) {
      startHour = hour12;
      startMinute = minute;
      startPeriod = period;
    } else {
      endHour = hour12;
      endMinute = minute;
      endPeriod = period;
    }
  }

  @override
  void dispose() {
    subjectController.dispose();
    teacherController.dispose();
    roomController.dispose();
    super.dispose();
  }

  // Converts 12-hour time into 24-hour time.
  int convertTo24Hour(int hour, String period) {
    if (period == 'AM') {
      if (hour == 12) {
        return 0;
      }
      return hour;
    } else {
      if (hour == 12) {
        return 12;
      }
      return hour + 12;
    }
  }

  // Converts the selected time into the format expected
  // by the Supabase TIME column: HH:mm:00
  String timeToDatabase(
    int hour,
    int minute,
    String period,
  ) {
    final hour24 = convertTo24Hour(hour, period);

    return '${hour24.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
  }

  // Converts a selected time into minutes since midnight.
  int timeToMinutes(
    int hour,
    int minute,
    String period,
  ) {
    final hour24 = convertTo24Hour(hour, period);
    return (hour24 * 60) + minute;
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> saveClass() async {
    // basiv valication

    if (subjectController.text.trim().isEmpty) {
      showMessage('Please enter a subject.');
      return;
    }

    if (selectedDays.isEmpty) {
      showMessage('Please select at least one day.');
      return;
    }

    if (startHour == null ||
        startMinute == null ||
        startPeriod == null) {
      showMessage('Please select a start time.');
      return;
    }

    if (endHour == null ||
        endMinute == null ||
        endPeriod == null) {
      showMessage('Please select an end time.');
      return;
    }

    // time validation

    final startTotalMinutes = timeToMinutes(
      startHour!,
      startMinute!,
      startPeriod!,
    );

    final endTotalMinutes = timeToMinutes(
      endHour!,
      endMinute!,
      endPeriod!,
    );

    if (endTotalMinutes <= startTotalMinutes) {
      showMessage(
        'End time must be after the start time.',
      );
      return;
    }

    // dtabase times

    final startTime = timeToDatabase(
      startHour!,
      startMinute!,
      startPeriod!,
    );

    final endTime = timeToDatabase(
      endHour!,
      endMinute!,
      endPeriod!,
    );

    // supahbase

    setState(() {
      isSaving = true;
    });

    try {
      if (isEditing) {
        final groupId =
            widget.existingClass!['schedule_group_id'];

        final commonData = {
          'subject': subjectController.text.trim(),
          'teacher': teacherController.text.trim(),
          'room': roomController.text.trim(),
          'start_time': startTime,
          'end_time': endTime,
          'reminder_enabled': reminderEnabled,
          'reminder_minutes': reminderMinutes,
          'schedule_group_id': groupId,
        };

        final existingByDay = {
          for (final item in widget.existingGroupClasses)
            item['day'] as String: item,
        };

        // Update existing days or add newly selected days.
        for (final day in selectedDays) {
          if (existingByDay.containsKey(day)) {
            await supabase
                .from('classes')
                .update({
                  ...commonData,
                  'day': day,
                })
                .eq('id', existingByDay[day]!['id']);
          } else {
            await supabase.from('classes').insert({
              ...commonData,
              'day': day,
            });
          }
        }

        // Delete days that were unchecked.
        for (final item in widget.existingGroupClasses) {
          final day = item['day'] as String;

          if (!selectedDays.contains(day)) {
            await supabase
                .from('classes')
                .delete()
                .eq('id', item['id']);
          }
        }
        await scheduleRemindersForGroup(groupId.toString());
      } else {
        final groupId = const Uuid().v4();

        for (final day in selectedDays) {
          await supabase.from('classes').insert({
            'subject': subjectController.text.trim(),
            'teacher': teacherController.text.trim(),
            'room': roomController.text.trim(),
            'day': day,
            'start_time': startTime,
            'end_time': endTime,
            'reminder_enabled': reminderEnabled,
            'reminder_minutes': reminderMinutes,
            'schedule_group_id': groupId,
          });
        }
        await scheduleRemindersForGroup(groupId);
      }

      if (!mounted) return;

      showMessage('Class added successfully!');

      // Return to HomePage and tell it that a class was added.
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      showMessage(
        'Failed to add class: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildTimeDropdowns({
    required String label,
    required int? selectedHour,
    required int? selectedMinute,
    required String? selectedPeriod,
    required ValueChanged<int?> onHourChanged,
    required ValueChanged<int?> onMinuteChanged,
    required ValueChanged<String?> onPeriodChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            // HOUR
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: selectedHour,
                decoration: const InputDecoration(
                  labelText: 'Hour',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Hour'),
                items: hours.map((hour) {
                  return DropdownMenuItem<int>(
                    value: hour,
                    child: Text(hour.toString()),
                  );
                }).toList(),
                onChanged: onHourChanged,
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // MINUTE
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: selectedMinute,
                decoration: const InputDecoration(
                  labelText: 'Minute',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Minute'),
                items: minutes.map((minute) {
                  return DropdownMenuItem<int>(
                    value: minute,
                    child: Text(
                      minute.toString().padLeft(2, '0'),
                    ),
                  );
                }).toList(),
                onChanged: onMinuteChanged,
              ),
            ),

            const SizedBox(width: 8),

            // AM / PM
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedPeriod,
                decoration: const InputDecoration(
                  labelText: 'AM/PM',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('AM/PM'),
                items: periods.map((period) {
                  return DropdownMenuItem<String>(
                    value: period,
                    child: Text(period),
                  );
                }).toList(),
                onChanged: onPeriodChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Class' : 'Add Class',),
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            // subject
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Database Management',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // teacher
            TextField(
              controller: teacherController,
              decoration: const InputDecoration(
                labelText: 'Teacher',
                hintText: 'e.g. Mr. Smith',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // room
            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: 'Room',
                hintText: 'e.g. Room 204',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // day
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Days',
                border: OutlineInputBorder(),
              ),
              child: Column(
                children: days.map((day) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(day),
                    value: selectedDays.contains(day),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          selectedDays.add(day);
                        } else {
                          selectedDays.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // start time
            buildTimeDropdowns(
              label: 'Start Time',
              selectedHour: startHour,
              selectedMinute: startMinute,
              selectedPeriod: startPeriod,
              onHourChanged: (value) {
                setState(() {
                  startHour = value;
                });
              },
              onMinuteChanged: (value) {
                setState(() {
                  startMinute = value;
                });
              },
              onPeriodChanged: (value) {
                setState(() {
                  startPeriod = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // end time
            buildTimeDropdowns(
              label: 'End Time',
              selectedHour: endHour,
              selectedMinute: endMinute,
              selectedPeriod: endPeriod,
              onHourChanged: (value) {
                setState(() {
                  endHour = value;
                });
              },
              onMinuteChanged: (value) {
                setState(() {
                  endMinute = value;
                });
              },
              onPeriodChanged: (value) {
                setState(() {
                  endPeriod = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // reminder
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enable Reminder',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Remind me before this class starts',
              ),
              value: reminderEnabled,
              onChanged: (value) {
                setState(() {
                  reminderEnabled = value;
                });
              },
            ),

            if (reminderEnabled) ...[
              const SizedBox(height: 8),

              DropdownButtonFormField<int>(
                initialValue: reminderMinutes,
                decoration: const InputDecoration(
                  labelText: 'Reminder Time',
                  border: OutlineInputBorder(),
                ),
                items: reminderOptions.map((minutes) {
                  return DropdownMenuItem<int>(
                    value: minutes,
                    child: Text(
                      '$minutes minutes before',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    reminderMinutes = value;
                  });
                },
              ),
            ],

            const SizedBox(height: 32),

            // save
            SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    isSaving
                        ? 'Saving...'
                        : isEditing
                            ? 'Update Class'
                            : 'Save Class',
                  ),
                  onPressed: isSaving ? null : saveClass,
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
  Future<void> scheduleRemindersForGroup(String groupId) async {
    final data = await supabase
        .from('classes')
        .select()
        .eq('schedule_group_id', groupId);

    for (final item in data) {
            if (item['reminder_enabled'] != true) {
        await NotificationService.cancelReminder(
          (item['id'] as num).toInt(),
        );
        continue;
      }
      await NotificationService.cancelReminder(
        (item['id'] as num).toInt(),
      );
    }

    const dayNumbers = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    final now = DateTime.now();

    for (final item in data) {
      final day = item['day'] as String?;
      final time = item['start_time']?.toString();

      if (day == null ||
          time == null ||
          !dayNumbers.containsKey(day)) {
        continue;
      }

      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      var daysUntil =
          (dayNumbers[day]! - now.weekday + 7) % 7;

      var classStart = DateTime(
        now.year,
        now.month,
        now.day + daysUntil,
        hour,
        minute,
      );

      if (!classStart.isAfter(now)) {
        classStart = classStart.add(const Duration(days: 7));
      }

      await NotificationService.scheduleClassReminder(
        id: (item['id'] as num).toInt(),
        subject: item['subject'] as String,
        classStart: classStart,
        minutesBefore:
            (item['reminder_minutes'] as num?)?.toInt() ?? 15,
      );
    }
  }
}
