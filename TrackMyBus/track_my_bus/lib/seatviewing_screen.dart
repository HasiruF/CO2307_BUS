import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SeatViewerPage extends StatefulWidget {
  final String busId;
  final String date;
  final String timeSlot;

  SeatViewerPage({required this.busId, required this.date, required this.timeSlot});

  @override
  _SeatViewerPageState createState() => _SeatViewerPageState();
}

class _SeatViewerPageState extends State<SeatViewerPage> {
  late Map<String, dynamic> bookedSeats;
  bool isLoading = true; // Flag to indicate loading state
  Map<String, String> userNames = {}; // Map to store userId -> username mapping

  @override
  void initState() {
    super.initState();
    bookedSeats = {}; 
    _fetchSeatDetails();
  }

  // Fetching seat details
  Future<void> _fetchSeatDetails() async {
    try {
      DocumentSnapshot seatDoc = await FirebaseFirestore.instance
          .collection('seats')
          .doc('bus${widget.busId}-${widget.date}-${widget.timeSlot}')
          .get();

      if (seatDoc.exists) {
        // If the document exists, update the bookedSeats map
        setState(() {
          bookedSeats = Map<String, dynamic>.from(seatDoc['bookedSeats'] ?? {});
          isLoading = false; // Set loading to false once data is fetched
        });

        // Fetch usernames for the booked seats
        _fetchUsernames();
      } else {
        // If the document doesn't exist, create it with an empty 'bookedSeats' map
        await FirebaseFirestore.instance
            .collection('seats')
            .doc('bus${widget.busId}-${widget.date}-${widget.timeSlot}')
            .set({
          'bookedSeats': {}, // Initialize with an empty map
          'busId': widget.busId,
          'date': widget.date,
          'timeSlot': widget.timeSlot,
        });

        // After creating the document, update the state with the empty bookedSeats map
        setState(() {
          bookedSeats = {};
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching seat details: $e');
    }
  }

  // Fetch the usernames for the booked seats
  Future<void> _fetchUsernames() async {
    try {
      // Create a list of userId from the bookedSeats
      List<String> userIds = bookedSeats.values.toList().cast<String>();
      
      for (var userId in userIds) {
        // Fetch user document for each userId
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          // Store the username in the userNames map
          setState(() {
            userNames[userId] = userDoc['username'] ?? 'Unknown User';
          });
        }
      }
    } catch (e) {
      print('Error fetching usernames: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalSeats = 12; // Example: assuming there are 12 seats for now.

    if (isLoading) {
      // Show a loading indicator while data is being fetched
      return Scaffold(
        appBar: AppBar(
          title: Text('View Seats for Bus ${widget.busId}'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('View Seats for Bus ${widget.busId}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // the number of seats per row
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: totalSeats,
          itemBuilder: (context, index) {
            int seatNumber = index + 1;

            return Card(
              color: bookedSeats.containsKey(seatNumber.toString())
                  ? Colors.red  // Red for booked seats
                  : Colors.green,  // Green for available seats
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Seat $seatNumber',
                      style: TextStyle(color: Colors.white),
                    ),
                    if (bookedSeats.containsKey(seatNumber.toString()))
                      Column(
                        children: [
                          Text(
                            'Booked by:',
                            style: TextStyle(color: Colors.white),
                          ),
                          Text(
                            userNames[bookedSeats[seatNumber.toString()]] ?? 'Loading...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
