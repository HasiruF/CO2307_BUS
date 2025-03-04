import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'seatbooking_screen.dart';
import 'driver_home_screen.dart';
import 'halt_selection_screen.dart';
import 'user_map_screen.dart';


class HomePage extends StatefulWidget {
  final String userId;

  HomePage({required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = '';
  String userEmail = '';
  String userType = ''; 

  //selected tab
  int _currentIndex = 0;

  //tab navigtion bar
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _checkUserType(); // Check user type 
    _pages = [
      UserBookingsPage(
        userId: widget.userId,
      ),
      SelectionScreen(
        userId: widget.userId,
      ),
      ProfilePage(),
    ];
  }

  // Check the user type and redirect if driver
  Future<void> _checkUserType() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        userType = userDoc['usertype'];
        if (userType == 'Driver') {
          //Navigate to driverHomePage
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DriverHomePage(userId: widget.userId)),
          );
        } else {
          // Fetch and display user details for "Client"
          setState(() {
            userName = userDoc['username'];
            userEmail = userDoc['email'];
          });
        }
      }
    } catch (e) {
      print('Error checking user type: $e');
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          'Welcome, $userName',
        ),
        actions: [
          // Sign out button in the AppBar
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () async {
              // Sign out the user
              await FirebaseAuth.instance.signOut();

              // Navigate back to the login page after sign out
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      body: _pages[_currentIndex], // Show the selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // Current selected index
        onTap: _onTabTapped, // Update selected tab
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.my_library_books),
            label: 'My Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'Book a seat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}


class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

   @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Profile Tab'),
    );
  }
}



class SelectionScreen extends StatefulWidget {
  final String userId;

  SelectionScreen({required this.userId});

  @override
  _SelectionScreenState createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  String? selectedRoute;
  String? selectedOnHalt;
  String? selectedOffHalt;
  int? gettingOnHaltIndex;
  int? gettingOffHaltIndex;
  String selectedDate = '2024-11-15';
  String selectedTimeSlot = 'morning';
  List<Map<String, String>> busRoutes = [];
  final List<String> timeSlots = ['morning', 'evening'];

  @override
  void initState() {
    super.initState();
    _fetchBusRoutes();
  }

  Future<void> _fetchBusRoutes() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('buses').get();
      setState(() {
        busRoutes = snapshot.docs.map((doc) {
          return {
            'route_name': (doc['route_name'] ?? 'Unnamed Route').toString(),
            'busId': doc.id.toString(),
          };
        }).toList();
        if (busRoutes.isNotEmpty) {
          selectedRoute = busRoutes[0]['route_name'];
        }
      });
    } catch (e) {
      print('Error fetching bus routes: $e');
    }
  }

  void _onHaltSelected(int haltIndex, String haltType) {
    setState(() {
      if (haltType == 'gettingOn') {
        gettingOnHaltIndex = haltIndex;
        selectedOnHalt = 'Halt ${haltIndex + 1}';
      } else if (haltType == 'gettingOff') {
        gettingOffHaltIndex = haltIndex;
        selectedOffHalt = 'Halt ${haltIndex + 1}';
      }
    });
  }

  bool _isValidHaltSelection() {
    if (gettingOnHaltIndex == null || gettingOffHaltIndex == null) {
      return false;
    }
    if (selectedTimeSlot == 'morning') {
      return gettingOffHaltIndex! > gettingOnHaltIndex!;
    } else {
      return gettingOffHaltIndex! < gettingOnHaltIndex!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Bus, Date, and Time Slot'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Bus Route:'),
            busRoutes.isEmpty
                ? CircularProgressIndicator()
                : DropdownButton<String>(
                    value: selectedRoute,
                    onChanged: (newValue) {
                      setState(() {
                        selectedRoute = newValue!;
                      });
                    },
                    items: busRoutes.map<DropdownMenuItem<String>>((route) {
                      return DropdownMenuItem<String>(
                        value: route['route_name'],
                        child: Text(route['route_name']!),
                      );
                    }).toList(),
                  ),
            SizedBox(height: 20),

            // Date Picker
            Text('Select Date:'),
            ElevatedButton(
              onPressed: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(Duration(days: 0)),
                  firstDate: DateTime.now().add(Duration(days: 0)),
                  lastDate: DateTime.now().add(Duration(days: 30)),
                );

                if (pickedDate != null) {
                  setState(() {
                    selectedDate = pickedDate.toIso8601String().split('T')[0];
                  });
                }
              },
              child: Text('Pick Date'),
            ),
            Text('Selected Date: $selectedDate'),
            SizedBox(height: 20),

            // Time Slot Dropdown
            Text('Select Time Slot:'),
            DropdownButton<String>(
              value: selectedTimeSlot,
              onChanged: (newValue) {
                setState(() {
                  selectedTimeSlot = newValue!;
                });
              },
              items: timeSlots.map<DropdownMenuItem<String>>((String slot) {
                return DropdownMenuItem<String>(
                  value: slot,
                  child: Text(slot),
                );
              }).toList(),
            ),

            SizedBox(height: 20),

            // Getting On Halt Button
            ElevatedButton(
              onPressed: selectedRoute == null
                  ? null
                  : () {
                      String busId = busRoutes.firstWhere((route) => route['route_name'] == selectedRoute)['busId']!;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapSelectionScreen(
                            busId: busId,
                            userId: widget.userId,
                            onHaltSelected: (index, type) => _onHaltSelected(index, 'gettingOn'),
                          ),
                        ),
                      );
                    },
              child: Text('Select Getting On Halt'),
            ),
            Text('Selected Getting On Halt: $selectedOnHalt'),
            SizedBox(height: 20),

            // Getting Off Halt Button
            ElevatedButton(
              onPressed: selectedRoute == null || selectedOnHalt == null
                  ? null
                  : () {
                      String busId = busRoutes.firstWhere((route) => route['route_name'] == selectedRoute)['busId']!;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapSelectionScreen(
                            busId: busId,
                            userId: widget.userId,
                            onHaltSelected: (index, type) => _onHaltSelected(index, 'gettingOff'),
                          ),
                        ),
                      );
                    },
              child: Text('Select Getting Off Halt'),
            ),
            Text('Selected Getting Off Halt: $selectedOffHalt'),
            Spacer(),

            // Button to navigate to the booking page
            Center(
              child: ElevatedButton(
                onPressed: selectedRoute == null || selectedOnHalt == null || selectedOffHalt == null || !_isValidHaltSelection()
                    ? null
                    : () {
                        String busId = busRoutes.firstWhere((route) => route['route_name'] == selectedRoute)['busId']!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SeatSelectionPage(
                              busId: busId,
                              date: selectedDate,
                              timeSlot: selectedTimeSlot,
                              userId: widget.userId,
                              gettingOnHalt: selectedOnHalt!,
                              gettingOffHalt: selectedOffHalt!,
                            ),
                          ),
                        );
                      },
                child: Text('Go to Seat Selection'),
              ),
            ),

            // Display error if halt selection is invalid
            if (selectedOnHalt != null && selectedOffHalt != null && !_isValidHaltSelection())
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  selectedTimeSlot == 'morning'
                      ? 'Invalid Trip direction'
                      : 'Invalid Trip direction',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class UserBookingsPage extends StatefulWidget {
  final String userId;

  UserBookingsPage({required this.userId});

  @override
  _UserBookingsPageState createState() => _UserBookingsPageState();
}

class _UserBookingsPageState extends State<UserBookingsPage> {
  // Fetch user bookings asynchronously
  Future<List<Map<String, dynamic>>> _fetchUserBookings() async {
    List<Map<String, dynamic>> bookings = [];

    try {
      // Fetch all seats data from Firestore
      QuerySnapshot seatSnapshot = await FirebaseFirestore.instance.collection('seats').get();
      for (var doc in seatSnapshot.docs) {
        Map<String, dynamic> seatData = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> bookedSeats = seatData['bookedSeats'] ?? {};

        // Iterate through the bookedSeats map
        for (var entry in bookedSeats.entries) {
          Map<String, dynamic> seatDetails = entry.value;

          
          if (seatDetails['userId'] == widget.userId) {
            // Fetch the corresponding bus data
            String busId = seatData['busId'];
            DocumentSnapshot busDoc = await FirebaseFirestore.instance.collection('buses').doc(busId).get();

            if (busDoc.exists) {
              String routeName = busDoc['route_name'] ?? 'Unknown Route';
              String busNumber = busDoc['bus_number'] ?? 'Unknown Number';

              // Add to bookings list
              bookings.add({
                'busId':busId,
                'documentId': doc.id,
                'routeName': routeName,
                'busNumber': busNumber,
                'date': seatData['date'],
                'timeSlot': seatData['timeSlot'],
                'seatNumber': entry.key,  // Storing the seat number as well
                'gettingOnHalt': seatDetails['gettingOnHaltIndex'],
                'gettingOffHalt': seatDetails['gettingOffHaltIndex'],
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching user bookings: $e');
    }

    return bookings;
  }

  // Cancel booking asynchronously
  Future<void> _cancelBooking(String documentId, String seatNumber) async {
    try {
      DocumentReference docRef = FirebaseFirestore.instance.collection('seats').doc(documentId);
      DocumentSnapshot docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> seatData = docSnapshot.data() as Map<String, dynamic>;
        Map<String, dynamic> bookedSeats = seatData['bookedSeats'] ?? {};

        // Remove booking for the specified seat
        bookedSeats.remove(seatNumber);

        // Update Firestore doc
        await docRef.update({'bookedSeats': bookedSeats});

        setState(() {}); // Refresh
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking cancelled successfully')),
        );
      }
    } catch (e) {
      print('Error cancelling booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling booking')),
      );
    }
  }

  // Navigate to the BusRouteMapPage when a booking is tapped
  void _navigateToBusRouteMapPage(Map<String, dynamic> booking) {
    if (booking != null) {
      print('booking: $booking');
    } else {
      print('booking is null');
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusRouteMapPage(
          userId: widget.userId,
          busId: booking['busId'],  // Pass the bus ID
          gettingOnHaltIndex: booking['gettingOnHalt'],  // Pass the getting on halt index
          gettingOffHaltIndex: booking['gettingOffHalt'],  // Pass the getting off halt index
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(  // FutureBuilder to fetch bookings
        future: _fetchUserBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading bookings'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No bookings found'));
          } else {
            List<Map<String, dynamic>> bookings = snapshot.data!;

            return ListView.builder(  // ListView for displaying bookings
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                var booking = bookings[index];
                return ListTile(
                  title: Text('${booking['routeName']} - ${booking['busNumber']}'),
                  subtitle: Text('Date: ${booking['date']}, Time Slot: ${booking['timeSlot']}'),
                  onTap: () {
                    _navigateToBusRouteMapPage(booking);  // Navigate on tap
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _cancelBooking(booking['documentId'], booking['seatNumber']);
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}