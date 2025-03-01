import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapSelectionScreen extends StatefulWidget {
  final String busId;
  final String userId;
  final Function(int, String) onHaltSelected; // Update to pass halt index and type

  MapSelectionScreen({required this.busId, required this.userId, required this.onHaltSelected});

  @override
  _MapSelectionScreenState createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  List<LatLng> _haltLocations = [];
  bool isGettingOnHaltSelected = true; // Flag to determine which halt is being selected

  @override
  void initState() {
    super.initState();
    _fetchHalts();
  }

  Future<void> _fetchHalts() async {
    try {
      DocumentSnapshot busDoc = await FirebaseFirestore.instance.collection('buses').doc(widget.busId).get();
      if (busDoc.exists) {
        List<dynamic> haltList = busDoc['haltLocations'] ?? [];
        setState(() {
          _haltLocations = haltList.map((geoPoint) {
            GeoPoint point = geoPoint;
            return LatLng(point.latitude, point.longitude);
          }).toList();
          _markers = _haltLocations.asMap().map((index, latLng) {
            return MapEntry(
              index,
              Marker(
                markerId: MarkerId(index.toString()),
                position: latLng,
                onTap: () {
                  // Toggle the halt selection between Getting On and Getting Off
                  widget.onHaltSelected(index, isGettingOnHaltSelected ? 'gettingOn' : 'gettingOff');
                  setState(() {
                    // Toggle the selection flag for the next halt
                    isGettingOnHaltSelected = !isGettingOnHaltSelected;
                  });
                  Navigator.pop(context); // Close the screen after selection
                },
              ),
            );
          }).values.toSet();
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
        title: Text('Select Halt Location'),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(6.838271820056003, 79.86744079738855), // Default center point
          zoom: 14,
        ),
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      ),
    );
  }
}
