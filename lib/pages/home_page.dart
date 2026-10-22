import 'package:flutter/material.dart';
import '../main.dart';
import 'login_page.dart';
import 'add_class_page.dart';
import 'package:intl/intl.dart';
import 'schedule_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> classes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadClasses();
  }

  String getToday() {
    return DateFormat('EEEE').format(DateTime.now());
  }

  
  Map<String, dynamic>? getUpcomingClass() {
    if (classes.isEmpty) {
      return null;
    }

    final now = DateTime.now();

    final dayNumbers = {
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
      'Sunday': DateTime.sunday,
    };

    Map<String, dynamic>? upcomingClass;
    DateTime? earliestDateTime;

    for (final classItem in classes) {
      final day = classItem['day'] as String?;
      final startTime = classItem['start_time']?.toString();

      if (day == null ||
          startTime == null ||
          !dayNumbers.containsKey(day)) {
        continue;
      }

      try {
        final parts = startTime.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        if (hour < 0 || hour > 23 ||
            minute < 0 || minute > 59) {
          continue;
        }

        final targetWeekday = dayNumbers[day]!;

        var daysUntil = (targetWeekday - now.weekday + 7) % 7;

        var classDateTime = DateTime(
          now.year,
          now.month,
          now.day + daysUntil,
          hour,
          minute,
        );

        // If today's class has already started, consider
        // its next weekly occurrence.
        if (!classDateTime.isAfter(now)) {
          classDateTime = classDateTime.add(
            const Duration(days: 7),
          );
        }

        if (earliestDateTime == null ||
            classDateTime.isBefore(earliestDateTime)) {
          earliestDateTime = classDateTime;

          upcomingClass = {
            ...classItem,
            '_upcoming_datetime': classDateTime,
          };
        }
      } catch (_) {
        // Skip a record with an invalid start time.
        continue;
      }
    }

    return upcomingClass;
  }


  Future<void> loadClasses() async {
    try {
      final data = await supabase
          .from('classes')
          .select()
          .order('start_time');

      if (!mounted) return;

      setState(() {
        classes = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load classes: $error'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Schedule Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await supabase.auth.signOut();

              if (!context.mounted) return;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Here is your class schedule.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 25),

            
            // Upcoming class
            const Text(
              'Upcoming Class',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final upcomingClass = getUpcomingClass();

                  if (upcomingClass == null) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          classes.isEmpty
                              ? 'No classes have been added yet. '
                                  'Add a class to see your upcoming schedule.'
                              : 'No upcoming class could be found. '
                                  'Check your saved class details.',
                        ),
                      ),
                    );
                  }

                  final classDateTime =
                      upcomingClass['_upcoming_datetime']
                          as DateTime;

                  final classDay = DateFormat(
                    'EEEE, MMM d',
                  ).format(classDateTime);

                  final teacher =
                      upcomingClass['teacher']?.toString() ?? '';

                  final room =
                      upcomingClass['room']?.toString() ?? '';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            upcomingClass['subject'] ??
                                'Unknown Subject',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(classDay),

                          const SizedBox(height: 8),

                          Text(
                            '${formatDatabaseTime(
                              upcomingClass['start_time'],
                            )} - ${formatDatabaseTime(
                              upcomingClass['end_time'],
                            )}',
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Room: ${room.isEmpty ? 'No room assigned' : room}',
                          ),

                          Text(
                            'Teacher: ${teacher.isEmpty ? 'No teacher assigned' : teacher}',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 25),

            // Today's classes
            const Text(
              "Today's Classes",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final today = getToday();

                  final todayClasses = classes
                      .where((classItem) => classItem['day'] == today)
                      .toList();

                  if (todayClasses.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No classes scheduled for today.',
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: todayClasses.map((classItem) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.school),
                          title: Text(
                            classItem['subject'] ?? 'Unknown Subject',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${formatDatabaseTime(classItem['start_time'])} - '
                            '${formatDatabaseTime(classItem['end_time'])}\n'
                            '${classItem['room'] ?? 'No room'}'
                            '${classItem['teacher'] != null && classItem['teacher'].toString().isNotEmpty ? '\n${classItem['teacher']}' : ''}',
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            const SizedBox(height: 30),

            // Add class
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Class'),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddClassPage(),
                    ),
                  );

                  if (result == true) {
                    loadClasses();
                  }
                },
              ),
            ),

            const SizedBox(height: 12),

            // View schedule
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: const Text('View Schedule'),      
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SchedulePage(),
                    ),
                  );

                  if (!mounted) return;

                  await loadClasses();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}