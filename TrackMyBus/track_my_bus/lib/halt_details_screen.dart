import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HaltDetailsPage extends StatefulWidget {
  final int haltIndex;
  final String busId;
  final LatLng haltCoordinates;
  final bool isFirstHalt;
  final bool isNextHalt;

  HaltDetailsPage({
    required this.haltIndex,
    required this.busId,
    required this.haltCoordinates,
    required this.isFirstHalt,
    required this.isNextHalt,
  });

  @override
  _HaltDetailsPageState createState() => _HaltDetailsPageState();
}

class _HaltDetailsPageState extends State<HaltDetailsPage> {
  int gettingOnCount = 0;
  int gettingOffCount = 0;
  bool isLoading = true;
  List<String> gettingOnNames = [];
  List<String> gettingOffNames = [];
  bool isGettingOnExpanded = false;
  bool isGettingOffExpanded = false;
  int? currentHalt;

  @override
  void initState() {
    super.initState();
    _fetchHaltBookingData();
    _fetchCurrentHalt();
  }

  Future<void> _fetchCurrentHalt() async {
    try {
      String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String timeSlot = DateTime.now().hour < 12 ? 'morning' : 'evening';

      DocumentSnapshot seatDoc = await FirebaseFirestore.instance
          .collection('seats')
          .doc('${widget.busId}-$selectedDate-$timeSlot')
          .get();

      if (seatDoc.exists) {
        setState(() {
          currentHalt = seatDoc['current'];
        });
      }
    } catch (e) {
      print('Error fetching current halt: $e');
    }
  }

  Future<void> _updateCurrentHalt(int newIndex) async {
    try {
      String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String timeSlot = DateTime.now().hour < 12 ? 'morning' : 'evening';

      await FirebaseFirestore.instance
          .collection('seats')
          .doc('${widget.busId}-$selectedDate-$timeSlot')
          .update({'current': newIndex});

      setState(() {
        currentHalt = newIndex;
      });
    } catch (e) {
      print('Error updating current halt: $e');
    }
  }

  Future<void> _fetchHaltBookingData() async {
    try {
      String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String timeSlot = DateTime.now().hour < 12 ? 'morning' : 'evening';

      QuerySnapshot seatSnapshot = await FirebaseFirestore.instance
          .collection('seats')
          .where('busId', isEqualTo: widget.busId)
          .where('date', isEqualTo: selectedDate)
          .where('timeSlot', isEqualTo: timeSlot)
          .get();

      List<String> onNames = [];
      List<String> offNames = [];
      int onCount = 0;
      int offCount = 0;

      for (var doc in seatSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> bookedSeats = data['bookedSeats'] ?? {};

        for (var seat in bookedSeats.values) {
          if (seat['gettingOnHaltIndex'] == widget.haltIndex) {
            onCount++;
            String userName = await _getUserName(seat['userId']);
            onNames.add(userName);
          }
          if (seat['gettingOffHaltIndex'] == widget.haltIndex) {
            offCount++;
            String userName = await _getUserName(seat['userId']);
            offNames.add(userName);
          }
        }
      }

      setState(() {
        gettingOnCount = onCount;
        gettingOffCount = offCount;
        gettingOnNames = onNames;
        gettingOffNames = offNames;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching halt booking data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        return userData['username'] ?? 'Unknown User';
      } else {
        return 'Unknown User';
      }
    } catch (e) {
      print('Error fetching user name: $e');
      return 'Unknown User';
    }
  }

  void _openGoogleMaps() async {
    final String url =
        'https://www.google.com/maps/dir/?api=1&destination=${widget.haltCoordinates.latitude},${widget.haltCoordinates.longitude}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      print('Could not open Google Maps.');
    }
  }
  Future<void> sendNotificationToUsers(List<String> userIds, String message) async {
    try {
      for (String userId in userIds) {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(userId).get();

        if (userDoc.exists) {
          String? fcmToken = userDoc['fcmToken']; // Assuming you store fcmToken for each user
          if (fcmToken != null && fcmToken.isNotEmpty) {
            
            await FirebaseMessaging.instance.sendMessage(
              to: fcmToken,
              data: {
                'title': 'Bus Update',
                'body': message,
              },
            );
            print('Notification sent to user: $userId');
          }
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      appBar: AppBar(title: Text('Halt Details')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text('Halt Details',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          Divider(),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isGettingOnExpanded = !isGettingOnExpanded;
                                      });
                                    },
                                    child: Text('$gettingOnCount',
                                        style: TextStyle(
                                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                  ),
                                  Text('Getting On', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                              Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isGettingOffExpanded = !isGettingOffExpanded;
                                      });
                                    },
                                    child: Text('$gettingOffCount',
                                        style: TextStyle(
                                            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                                  ),
                                  Text('Getting Off', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: Icon(Icons.map),
                    label: Text('Open in Google Maps'),
                  ),

                  if (widget.isFirstHalt)
                  ElevatedButton(
                    onPressed: () async {
                      String timeSlot = DateTime.now().hour < 12 ? 'morning' : 'evening';
                      String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

                      // Query the seats collection to find users who have booked seats on the selected date and time slot
                      await FirebaseFirestore.instance
                          .collection('seats')
                          .where('busId', isEqualTo: widget.busId)
                          .where('date', isEqualTo: selectedDate)
                          .where('timeSlot', isEqualTo: timeSlot)
                          .get()
                          .then((snapshot) async {
                        for (var doc in snapshot.docs) {
                          // Update the current halt to mark the bus as started at the first halt
                          await doc.reference.update({'current': -1});

                          // Retrieve the booked seats for each document
                          Map<String, dynamic> bookedSeats = doc['bookedSeats'] ?? {};

                          // List to hold the userIds for users who are getting on
                          List<String> userIdsToNotify = [];

                          // Iterate over the booked seats to find users who are getting on at the current halt
                          bookedSeats.forEach((key, value) {
                            if (value['gettingOnHaltIndex'] == widget.haltIndex) {
                              // Add the userId of the user who is getting on
                              userIdsToNotify.add(value['userId']);
                            }
                          });

                          // Send notifications to users who are getting on
                          if (userIdsToNotify.isNotEmpty) {
                            sendNotificationToUsers(userIdsToNotify, 'The bus has started its journey. Stay tuned!');
                          }
                        }
                      });
                    },
                    child: Text('Start Bus'),
                  ),
                
                  if (widget.isNextHalt)
                  ElevatedButton(
                    onPressed: () async {
                      String timeSlot = DateTime.now().hour < 12 ? 'morning' : 'evening';
                      String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      
                      await FirebaseFirestore.instance
                          .collection('seats')
                          .where('busId', isEqualTo: widget.busId)
                          .where('date', isEqualTo: selectedDate)
                          .where('timeSlot', isEqualTo: timeSlot)
                          .get()
                          .then((snapshot) {
                        for (var doc in snapshot.docs) {
                          doc.reference.update({'current': widget.haltIndex}); // Mark halt as reached
                        }
                      });
                    },
                    child: Text('Arrived at Halt'),
                  ),

                ],
              ),
            ),
    );
  }
}
