import 'package:flutter/material.dart';
import 'notification_helper.dart';
import '../Mood Journal/pastJournalEntries.dart';

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  State<Notifications> createState() =>
      _NotificationsState();
}

class _NotificationsState
    extends State<Notifications> {

  List<AppNotification> notifications = [

    AppNotification(
      title: "Journal Incomplete!",
      subtitle: "It's Reflection Time!",
      date: DateTime.now().subtract(Duration(hours: 3)),
      isRead: false,
      page: PastJournalEntriesScreen(),
      icon: Icons.book,
      color: Color(0xff8E7CFF),
    ),
  ];

  int get unreadCount =>
      notifications.where((n) => !n.isRead).length;

  Map<String, List<AppNotification>> groupNotifications() {
    Map<String, List<AppNotification>> grouped = {};
    for (var notification in notifications) {
      String group =
      getNotificationGroup(notification.date);
      if (!grouped.containsKey(group)) {
        grouped[group] = [];
      }
      grouped[group]!.add(notification);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {

    final grouped = groupNotifications();

    return Scaffold(
      backgroundColor: Color(0xffF7F4F2),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xffF7F4F2),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(
                        color: Color(0xff4B3425),
                        width: 2.0
                      ),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Color(0xff4B3425),
                    size: 25,
                  ),
                ),
              ),

              SizedBox(height: 40),

              // Title
              Row(
                children: [

                  Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff4B3425),
                    ),
                  ),

                  SizedBox(width: 10),

                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xffFFD2C2),
                      borderRadius:
                      BorderRadius.circular(30),
                    ),
                    child: Text(
                      "+$unreadCount",
                      style: TextStyle(
                        color: Color(0xffFE631B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),

              SizedBox(height: 33),

              Expanded(
                child: ListView(
                  children: grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // Group Title
                        Padding(
                          padding:
                          const EdgeInsets.only(bottom: 10),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xff4B3425),
                              fontSize: 20,
                            ),
                          ),
                        ),
                        ...entry.value.map(
                          (notification) => notificationCard(notification),
                        ),

                        SizedBox(height: 20),
                      ],
                    );
                  }).toList(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget notificationCard(
      AppNotification notification) {
    return GestureDetector(
      onTap: () {
        setState(() {
          notification.isRead = true;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
            notification.page,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: notification.color,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                notification.icon,
                color: Colors.white,
              ),
            ),

            SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xff4B3425),
                      fontSize: 18,
                    ),
                  ),

                  SizedBox(height: 4),

                  Text(
                    notification.subtitle,
                    style: TextStyle(
                      color: Color(0xff706A66),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            if (!notification.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              )
          ],
        ),
      ),
    );
  }
}