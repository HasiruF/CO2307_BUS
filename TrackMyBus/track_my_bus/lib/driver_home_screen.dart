import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'seatbooking_screen.dart';
import 'home_screen.dart';
import 'drive_route_screen.dart';
import 'seatviewing_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


class DriverHomePage extends StatefulWidget {
  final String userId;

  DriverHomePage({required this.userId});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  String userName = '';
  String userEmail = '';
  String userType = 'Driver'; // Hardcoded for Driver

  //current  tab
  int _currentIndex = 0;

  //BottomNavigationBar items
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails(); // Fetch driver's details
    _pages = [
      DriverTripsPage(userId: widget.userId), // iewing/managing trips
      DriverMapPage(userId: widget.userId), // New tab for Google Maps
      DriverProfilePage(userId: widget.userId), // Driver's profile page
      
    ];
  }

  Future<void> _fetchUserDetails() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userName = userDoc['username'];
          userEmail = userDoc['email'];
        });
      }
    } catch (e) {
      print('Error fetching driver details: $e');
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
          'Driver Dashboard, $userName',
        ),
        actions: [
          // Sign out button in the AppBar
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () async {
              // Sign out the user
              await FirebaseAuth.instance.signOut();

              //avigate back to the login page
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
            icon: Icon(Icons.directions_bus),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),  // Google Maps icon
            label: 'Map',           // Label for the new tab
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

class DriverTripsPage extends StatefulWidget {
  final String userId;

  DriverTripsPage({required this.userId});

  @override
  _DriverTripsPageState createState() => _DriverTripsPageState();
}

class _DriverTripsPageState extends State<DriverTripsPage> {
  Future<List<Map<String, dynamic>>> _fetchDriverTrips() async {
    List<Map<String, dynamic>> trips = [];

    try {
      // Fetch all buses assigned to this driver
      QuerySnapshot busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driver_id', isEqualTo: widget.userId)
          .get();

      for (var busDoc in busSnapshot.docs) {
        String busId = busDoc.id;
        String routeName = busDoc['route_name'] ?? 'Unknown Route';
        String busNumber = busDoc['bus_number'] ?? 'Unknown Number';

        // Fetch bookings for this bus from the seats collection
        QuerySnapshot seatSnapshot = await FirebaseFirestore.instance
            .collection('seats')
            .where('busId', isEqualTo: busId)
            .get();

        Map<String, Map<String, int>> bookingsByDateAndTime = {};

        for (var seatDoc in seatSnapshot.docs) {
          String date = seatDoc['date'] ?? 'Unknown Date';
          String timeSlot = seatDoc['timeSlot'] ?? 'Unknown Time Slot';
          Map<String, dynamic> bookedSeats = seatDoc['bookedSeats'] ?? {};

          if (bookedSeats.isNotEmpty) {
            // Ensure the map for this date exists
            if (bookingsByDateAndTime[date] == null) {
              bookingsByDateAndTime[date] = {};
            }

            // Ensure the time slot exists and initialize it to 0 if it's null
            if (bookingsByDateAndTime[date]![timeSlot] == null) {
              bookingsByDateAndTime[date]![timeSlot] = 0;
            }

            // Increment the booking count
            bookingsByDateAndTime[date]![timeSlot] =
                bookingsByDateAndTime[date]![timeSlot]! + bookedSeats.length;
          }
        }

        if (bookingsByDateAndTime.isNotEmpty) {
          trips.add({
            'routeName': routeName,
            'busNumber': busNumber,
            'busId': busId,
            'dayTimeBookings': bookingsByDateAndTime,
          });
        }
      }
    } catch (e) {
      print('Error fetching driver trips: $e');
    }

    return trips;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Trips'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>( 
        future: _fetchDriverTrips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading trips'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No trips found'));
          } else {
            List<Map<String, dynamic>> trips = snapshot.data!;
            return ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) {
                var trip = trips[index];
                String routeName = trip['routeName'] ?? 'Unknown Route';
                String busNumber = trip['busNumber'] ?? 'Unknown Bus';
                String busId = trip['busId'] ?? 'Unknown Bus ID';

                return Column(
                  children: [
                    // Bus Route and Number
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '$routeName - $busNumber',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Loop through the bookings
                    ...trip['dayTimeBookings']?.entries.map((entry) {
                      String date = entry.key;
                      Map<String, int> timeSlots = entry.value;

                      return GestureDetector(
                        onTap: () {
                          // Navigate to SeatViewerPage on tap
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SeatViewerPage(
                                busId: busId,
                                date: date,
                                timeSlot: timeSlots.keys.first,
                              ),
                            ),
                          );
                        },
                        child: Card(
                          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            title: Text('$date, ${timeSlots.keys.first}'), // date and time slot
                            subtitle: Text('Bookings: ${timeSlots.values.first}'), // booking count
                          ),
                        ),
                      );
                    }).toList() ?? [],
                    // Add Button to Navigate to DriverRouteScreen
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to the DriverRouteScreen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DriverRouteScreen(
                                busId: busId, // Pass busId to the DriverRouteScreen
                              ),
                            ),
                          );
                        },
                        child: Text('Manage Route for $routeName'),
                      ),
                    ),
                  ],
                );
              },
            );
          }
        },
      ),
    );
  }
}

class DriverProfilePage extends StatelessWidget {
  final String userId;

  DriverProfilePage({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your Profile Details, Driver ID: $userId',
        style: TextStyle(fontSize: 18),
      ),
    );
  }
}

class DriverMapPage extends StatefulWidget {
  final String userId;

  DriverMapPage({required this.userId});

  @override
  _DriverMapPageState createState() => _DriverMapPageState();
}

class _DriverMapPageState extends State<DriverMapPage> {
  late GoogleMapController _mapController;
  late LatLng _userLocation;
  bool _isLoading = true;
  late Set<Marker> _markers; 
  late Set<Polyline> _polylines; 
  List<LatLng> _haltLocations = [];

  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _haltIcon;

  @override
  void initState() {
    super.initState();
    _markers = Set();
    _polylines = Set();
    _loadCustomIcons();
    _fetchUserLocation();
    _fetchHaltLocations();
  }

  Future<void> _loadCustomIcons() async {
    _busIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(5, 5)),
      'assets/bus_icon.png',
    );
    _haltIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(5, 5)),
      'assets/halt_icon.png',
    );
  }

  Future<void> _fetchUserLocation() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        GeoPoint location = userDoc['location'];
        setState(() {
          _userLocation = LatLng(location.latitude, location.longitude);
          _markers.add(Marker(
            markerId: MarkerId('user_location'),
            position: _userLocation,
            icon: _busIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: 'Your Location'),
          ));
          _isLoading = false;
        });
      } else {
        print('User document not found');
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  Future<void> _fetchHaltLocations() async {
    try {
      QuerySnapshot busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driver_id', isEqualTo: widget.userId)
          .get();

      for (var busDoc in busSnapshot.docs) {
        List<dynamic> haltLocations = busDoc['haltLocations'] ?? [];
        setState(() {
          _haltLocations = haltLocations
              .map((location) => LatLng(location.latitude, location.longitude))
              .toList();

          for (var halt in _haltLocations) {
            _markers.add(Marker(
              markerId: MarkerId(halt.toString()),
              position: halt,
              icon: _haltIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(title: 'Halt'),
            ));
          }

          if (_haltLocations.isNotEmpty) {
            _polylines.add(Polyline(
              polylineId: PolylineId("driver_to_first_halt"),
              points: [_userLocation, _haltLocations[0]],
              color: Colors.blue,
              width: 5,
            ));
          }
        });
      }
    } catch (e) {
      print('Error fetching halt locations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Location'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _userLocation,
                zoom: 17.0,
              ),
              markers: _markers,
              polylines: _polylines,
            ),
    );
  }
}