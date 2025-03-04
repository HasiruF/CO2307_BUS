import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HaltDetailsPage extends StatefulWidget {
  final int haltIndex;
  final String busId;
  final LatLng haltCoordinates;

  HaltDetailsPage({
    required this.haltIndex,
    required this.busId,
    required this.haltCoordinates,
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

  @override
  void initState() {
    super.initState();
    _fetchHaltBookingData();
  }

  Future<void> _fetchHaltBookingData() async {
    try {
      String timeSlot = DateTime.now().hour < 12 ? 'morning' : 'evening';
      String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

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

      // Iterate over seat bookings
      for (var doc in seatSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        Map<String, dynamic> bookedSeats = data['bookedSeats'] ?? {};
        for (var seat in bookedSeats.values) {
          if (seat['gettingOnHaltIndex'] == widget.haltIndex) {
            onCount++;
            String userId = seat['userId'];
            // Fetch user data from the 'users' collection
            String userName = await _getUserName(userId);
            onNames.add(userName);
          }
          if (seat['gettingOffHaltIndex'] == widget.haltIndex) {
            offCount++;
            String userId = seat['userId'];
            // Fetch user data from the 'users' collection
            String userName = await _getUserName(userId);
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
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

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
                  // Halt Information Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Halt Details',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          Divider(),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Getting On Column
                              Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isGettingOnExpanded = !isGettingOnExpanded;
                                      });
                                    },
                                    child: Text(
                                      '$gettingOnCount',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ),
                                  Text('Getting On', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                              // Getting Off Column
                              Column(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        isGettingOffExpanded = !isGettingOffExpanded;
                                      });
                                    },
                                    child: Text(
                                      '$gettingOffCount',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                  ),
                                  Text('Getting Off', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          // If expanded, show the names
                          if (isGettingOnExpanded) ...[
                            Divider(),
                            Text('Getting On Passengers:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...gettingOnNames.map((name) => ListTile(title: Text(name))).toList(),
                          ],
                          if (isGettingOffExpanded) ...[
                            Divider(),
                            Text('Getting Off Passengers:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...gettingOffNames.map((name) => ListTile(title: Text(name))).toList(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Open Google Maps Button
                  ElevatedButton.icon(
                    onPressed: _openGoogleMaps,
                    icon: Icon(Icons.map),
                    label: Text('Open in Google Maps'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
