import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'seatbooking_screen.dart';


class HomePage extends StatefulWidget {
  final String userId;

  HomePage({required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = '';
  String userEmail = '';

  // The current index of the selected tab
  int _currentIndex = 0;

  // List of pages for each BottomNavigationBar item
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Initialize the pages list after widget is initialized
    _pages = [
      UserBookingsPage(
        userId: widget.userId
        ),
      SelectionScreen(
        userId: widget.userId
        ),
      ProfilePage(),
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
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
      print('Error fetching user details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black26,
        title: Text(
          'Welcome, $userName'
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
      body: _pages[_currentIndex],  // Show the selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,  // Current selected index
        onTap: _onTabTapped,  // Update selected tab
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
  String selectedBusId = '1';
  String selectedDate = '2024-11-15'; 
  String selectedTimeSlot = 'morning';

  final List<String> busIds = ['1', '2', '3', '4'];
  final List<String> timeSlots = ['morning', 'evening'];

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
            // Bus ID Dropdown
            Text('Select Bus ID:'),
            DropdownButton<String>(
              value: selectedBusId,
              onChanged: (newValue) {
                setState(() {
                  selectedBusId = newValue!;
                });
              },
              items: busIds.map<DropdownMenuItem<String>>((String busId) {
                return DropdownMenuItem<String>(
                  value: busId,
                  child: Text(busId),
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
                  initialDate: DateTime.now().add(Duration(days: 1)), //Tomorrow
                  firstDate: DateTime.now().add(Duration(days: 1)),   //Tomorrow
                  lastDate: DateTime.now().add(Duration(days: 90)),   //i n 3 months
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

            Spacer(),

            // Button to navigate to the booking page
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeatSelectionPage(
                        busId: selectedBusId,
                        date: selectedDate,
                        timeSlot: selectedTimeSlot,
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
                child: Text('Go to Seat Selection'),
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
  Future<List<Map<String, dynamic>>> _fetchUserBookings() async {
    List<Map<String, dynamic>> bookings = [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('seats').get();
      for (var doc in snapshot.docs) {
        Map<String, dynamic> seatData = doc.data() as Map<String, dynamic>;
        Map<String, dynamic> bookedSeats = seatData['bookedSeats'] ?? {};

        // Check if the userId exists in the bookedSeats map
        if (bookedSeats.containsValue(widget.userId)) {
          bookings.add({
            'documentId': doc.id,
            'busId': seatData['busId'],
            'date': seatData['date'],
            'timeSlot': seatData['timeSlot'],
            'seatNumbers': bookedSeats.keys.where((key) => bookedSeats[key] == widget.userId).toList(),
          });
        }
      }
    } catch (e) {
      print('Error fetching user bookings: $e');
    }

    return bookings;
  }

  Future<void> _cancelBooking(String documentId, List<String> seatNumbers) async {
    try {
      DocumentReference docRef = FirebaseFirestore.instance.collection('seats').doc(documentId);
      DocumentSnapshot docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> seatData = docSnapshot.data() as Map<String, dynamic>;
        Map<String, dynamic> bookedSeats = seatData['bookedSeats'] ?? {};

        // Remove bookinggs
        for (String seatNumber in seatNumbers) {
          bookedSeats.remove(seatNumber);
        }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUserBookings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading bookings'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No bookings found'));
          }

          List<Map<String, dynamic>> bookings = snapshot.data!;

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return ListTile(
                title: Text('Bus ID: ${booking['busId']}'),
                subtitle: Text('Date: ${booking['date']} | Time Slot: ${booking['timeSlot']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Seats: ${booking['seatNumbers'].join(', ')}'),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _cancelBooking(booking['documentId'], booking['seatNumbers']);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}