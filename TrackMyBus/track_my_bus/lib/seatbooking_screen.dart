import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SeatSelectionPage extends StatefulWidget {
  final String busId;
  final String date;
  final String timeSlot;
  final String userId;
  final String gettingOnHalt;
  final String gettingOffHalt;

  SeatSelectionPage({
    required this.busId,
    required this.date,
    required this.timeSlot,
    required this.userId,
    required this.gettingOnHalt,
    required this.gettingOffHalt,
  });

  @override
  _SeatSelectionPageState createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> {
  late Map<String, dynamic> bookedSeats;
  bool isLoading = true; // Flag to indicate loading state

  @override
  void initState() {
    super.initState();
    bookedSeats = {}; 
    _fetchSeatDetails();
  }

  // Fetching seat booking 
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
      } else {
        // If the document doesn't exist, create it with an empty 'bookedSeats' map
        await FirebaseFirestore.instance
            .collection('seats')
            .doc('bus${widget.busId}-${widget.date}-${widget.timeSlot}')
            .set({
          'bookedSeats': {}, // Initialize with an empty map
          'busId': widget.busId,
          'current': -2,
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

  // book a seat
  Future<void> _bookSeat(int seatNumber) async {
    try {
      if (bookedSeats.containsKey(seatNumber.toString())) {
        // Seat already booked
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This seat is already booked')),
        );
        return;
      }

      // Get the indices of getting on and getting off halts
      int gettingOnHaltIndex = int.parse(widget.gettingOnHalt.split(' ')[1]) - 1; // Convert halt name to index
      int gettingOffHaltIndex = int.parse(widget.gettingOffHalt.split(' ')[1]) - 1;

      // Firestore update the seat booking status with getting on and getting off halt indices
      await FirebaseFirestore.instance.collection('seats').doc('bus${widget.busId}-${widget.date}-${widget.timeSlot}').update({
        'bookedSeats.$seatNumber': {
          'userId': widget.userId,
          'gettingOnHaltIndex': gettingOnHaltIndex,
          'gettingOffHaltIndex': gettingOffHaltIndex,
        },  
      });

      // Update local state to reflect booking
      setState(() {
        bookedSeats[seatNumber.toString()] = {
          'userId': widget.userId,
          'gettingOnHaltIndex': gettingOnHaltIndex,
          'gettingOffHaltIndex': gettingOffHaltIndex,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat $seatNumber successfully booked!')),
      );
    } catch (e) {
      print('Error booking seat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error booking seat')),
      );
    }
  }

  // Listen for live updates on bookedSeats
  void _listenForUpdates() {
    FirebaseFirestore.instance
        .collection('seats')
        .doc('${widget.busId}-${widget.date}-${widget.timeSlot}')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          bookedSeats = Map<String, dynamic>.from(snapshot['bookedSeats'] ?? {});
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start listening for updates once the widget is fully built
    if (!isLoading) {
      _listenForUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalSeats = 12; // Example: assuming there are 12 seats for now.

    if (isLoading) {
      // Show a loading indicator while data is being fetched
      return Scaffold(
        appBar: AppBar(
          title: Text('Select Seat for Bus ${widget.busId}'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Seat for Bus ${widget.busId}'),
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

            return ElevatedButton(
              onPressed: () {
                _bookSeat(seatNumber);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: bookedSeats.containsKey(seatNumber.toString())
                    ? Colors.red  // Red for booked seats
                    : Colors.green,  // Green for available seats
              ),
              child: Text(
                'Seat $seatNumber',
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}
