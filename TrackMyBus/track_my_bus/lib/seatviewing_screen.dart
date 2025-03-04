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
  bool isLoading = true; 
  Map<String, String> userNames = {}; 

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
      // Create a new seat document if it doesn't exist
      await FirebaseFirestore.instance
          .collection('seats')
          .doc('bus${widget.busId}-${widget.date}-${widget.timeSlot}')
          .set({
        'bookedSeats': {}, 
        'busId': widget.busId,
        'date': widget.date,
        'timeSlot': widget.timeSlot,
      });

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
    // Iterate through the bookedSeats map where the key is the seat number and the value is a nested map
    for (var seatNumber in bookedSeats.keys) {
      // Access the 'userId' from the nested map for each seat
      Map<String, dynamic> seatDetails = bookedSeats[seatNumber];
      String userId = seatDetails['userId'];

      if (userId != null) {
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
            bool isBooked = bookedSeats.containsKey(seatNumber.toString());

            return Card(
              color: isBooked ? Colors.red : Colors.green,  // Red for booked seats, Green for available seats
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Seat $seatNumber',
                      style: TextStyle(color: Colors.white),
                    ),
                    // Conditionally show the user details if the seat is booked
                    if (isBooked) 
                      Column(
                        children: [
                          Text(
                            'Booked by:',
                            style: TextStyle(color: Colors.white),
                          ),
                          Text(
                            userNames[bookedSeats[seatNumber.toString()]['userId']] ?? 'Loading...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    else 
                      Text(
                        'Seat not booked',
                        style: TextStyle(color: Colors.white),
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
