
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import 'add_class_page.dart';
import '../services/notification_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map<String, dynamic>> classes = [];
  bool isLoading = true;
  bool selectionMode = false;
  bool isDeletingSelected = false;

  final Set<int> selectedClassIds = {};

  final List<String> days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    loadSchedule();
  }

  int classId(Map<String, dynamic> classItem) {
    return (classItem['id'] as num).toInt();
  }

  Future<void> loadSchedule() async {
    try {
      final data = await supabase
          .from('classes')
          .select()
          .order('start_time');

      if (!mounted) return;

      final loadedClasses = List<Map<String, dynamic>>.from(data);
      final loadedIds = loadedClasses.map(classId).toSet();

      setState(() {
        classes = loadedClasses;
        selectedClassIds.removeWhere(
          (id) => !loadedIds.contains(id),
        );
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load schedule: $error'),
        ),
      );
    }
  }

  void toggleSelection(Map<String, dynamic> classItem) {
    final id = classId(classItem);

    setState(() {
      if (selectedClassIds.contains(id)) {
        selectedClassIds.remove(id);
      } else {
        selectedClassIds.add(id);
      }
    });
  }

  void startSelection() {
    setState(() {
      selectionMode = true;
      selectedClassIds.clear();
    });
  }

  void cancelSelection() {
    setState(() {
      selectionMode = false;
      selectedClassIds.clear();
    });
  }

  void toggleSelectAll() {
    setState(() {
      if (selectedClassIds.length == classes.length) {
        selectedClassIds.clear();
      } else {
        selectedClassIds
          ..clear()
          ..addAll(classes.map(classId));
      }
    });
  }

  Future<void> deleteClass(
    Map<String, dynamic> classItem,
  ) async {
    try {
      await NotificationService.cancelReminder(
        classId(classItem),
      );

      await supabase
          .from('classes')
          .delete()
          .eq('id', classItem['id']);

      if (!mounted) return;

      setState(() {
        classes.removeWhere(
          (item) => item['id'] == classItem['id'],
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class deleted successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete class: $error'),
        ),
      );
    }
  }

  void confirmDelete(Map<String, dynamic> classItem) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Class?'),
          content: Text(
            'Are you sure you want to delete '
            '"${classItem['subject']}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                deleteClass(classItem);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> confirmDeleteSelected() async {
    if (selectedClassIds.isEmpty || isDeletingSelected) {
      return;
    }

    final count = selectedClassIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Selected Classes?'),
          content: Text(
            'Are you sure you want to delete '
            '$count selected schedule '
            '${count == 1 ? 'entry' : 'entries'}? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Delete Selected',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await deleteSelectedClasses();
    }
  }

  Future<void> deleteSelectedClasses() async {
    if (selectedClassIds.isEmpty || isDeletingSelected) {
      return;
    }

    final idsToDelete = Set<int>.from(selectedClassIds);
    final selectedItems = classes
        .where((item) => idsToDelete.contains(classId(item)))
        .toList();

    setState(() {
      isDeletingSelected = true;
    });

    try {
      // Cancel reminders for every selected schedule entry.
      for (final classItem in selectedItems) {
        await NotificationService.cancelReminder(
          classId(classItem),
        );
      }

      // Delete all selected database rows in one operation.
      await supabase
          .from('classes')
          .delete()
          .inFilter('id', idsToDelete.toList());

      if (!mounted) return;

      setState(() {
        classes.removeWhere(
          (item) => idsToDelete.contains(classId(item)),
        );

        selectedClassIds.clear();
        selectionMode = false;
        isDeletingSelected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedItems.length} schedule '
            '${selectedItems.length == 1 ? 'entry' : 'entries'} '
            'deleted successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isDeletingSelected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete selected classes: $error',
          ),
        ),
      );
    }
  }

  String formatDatabaseTime(String? time) {
    if (time == null || time.isEmpty) {
      return 'No time';
    }

    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final dateTime = DateTime(
      2000,
      1,
      1,
      hour,
      minute,
    );

    return DateFormat('h:mm a').format(dateTime);
  }

  List<Map<String, dynamic>> getClassesForDay(String day) {
    return classes
        .where((classItem) => classItem['day'] == day)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = classes.isNotEmpty &&
        selectedClassIds.length == classes.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectionMode
              ? '${selectedClassIds.length} selected'
              : 'My Schedule',
        ),
        actions: [
          if (selectionMode) ...[
            TextButton(
              onPressed: classes.isEmpty ? null : toggleSelectAll,
              child: Text(allSelected ? 'Deselect All' : 'Select All'),
            ),
            IconButton(
              tooltip: 'Delete selected',
              onPressed: selectedClassIds.isEmpty ||
                      isDeletingSelected
                  ? null
                  : confirmDeleteSelected,
              icon: isDeletingSelected
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
            ),
            IconButton(
              tooltip: 'Cancel selection',
              onPressed:
                  isDeletingSelected ? null : cancelSelection,
              icon: const Icon(Icons.close),
            ),
          ] else if (classes.isNotEmpty) ...[
            TextButton.icon(
              onPressed: startSelection,
              icon: const Icon(Icons.checklist),
              label: const Text('Select'),
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadSchedule,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...days.map((day) {
                    final dayClasses = getClassesForDay(day);

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (dayClasses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(
                              bottom: 20,
                            ),
                            child: Text(
                              'No classes',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          )
                        else
                          ...dayClasses.map((classItem) {
                            final id = classId(classItem);
                            final isSelected =
                                selectedClassIds.contains(id);

                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: 10,
                              ),
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                  : null,
                              child: ListTile(
                                onTap: selectionMode
                                    ? () => toggleSelection(
                                          classItem,
                                        )
                                    : null,
                                leading: selectionMode
                                    ? Checkbox(
                                        value: isSelected,
                                        onChanged: (_) {
                                          toggleSelection(
                                            classItem,
                                          );
                                        },
                                      )
                                    : const Icon(Icons.school),
                                title: Text(
                                  classItem['subject'] ??
                                      'Unknown Subject',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${formatDatabaseTime(classItem['start_time'])}'
                                  ' - '
                                  '${formatDatabaseTime(classItem['end_time'])}\n'
                                  '${classItem['room'] ?? 'No room'}'
                                  '${classItem['teacher'] != null && classItem['teacher'].toString().isNotEmpty ? '\n${classItem['teacher']}' : ''}',
                                ),
                                isThreeLine:
                                    classItem['teacher'] != null &&
                                    classItem['teacher']
                                        .toString()
                                        .isNotEmpty,
                                trailing: selectionMode
                                    ? null
                                    : Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                            ),
                                            tooltip: 'Edit',
                                            onPressed: () async {
                                              final groupId =
                                                  classItem[
                                                      'schedule_group_id'];

                                              final groupClasses =
                                                  classes
                                                      .where(
                                                        (item) =>
                                                            item['schedule_group_id'] ==
                                                            groupId,
                                                      )
                                                      .toList();

                                              final result =
                                                  await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AddClassPage(
                                                    existingClass:
                                                        classItem,
                                                    existingGroupClasses:
                                                        groupClasses,
                                                  ),
                                                ),
                                              );

                                              if (result == true) {
                                                loadSchedule();
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                            ),
                                            tooltip: 'Delete',
                                            onPressed: () {
                                              confirmDelete(
                                                classItem,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          }),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                ],
              ),
            ),
      bottomNavigationBar: selectionMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: selectedClassIds.isEmpty ||
                            isDeletingSelected
                        ? null
                        : confirmDeleteSelected,
                    icon: const Icon(Icons.delete),
                    label: Text(
                      isDeletingSelected
                          ? 'Deleting...'
                          : 'Delete Selected (${selectedClassIds.length})',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
