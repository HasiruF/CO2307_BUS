import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverRouteScreen extends StatefulWidget {
  final String busId;

  DriverRouteScreen({required this.busId});

  @override
  _DriverRouteScreenState createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  late GoogleMapController _mapController;
  late Set<Marker> _markers;
  List<LatLng> _haltLocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _markers = Set();
    _fetchHaltLocations();
  }

  // Fetch existing halt locations from Firestore if any
  Future<void> _fetchHaltLocations() async {
    try {
      DocumentSnapshot busDoc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busId)
          .get();
      if (busDoc.exists) {
        List<dynamic> haltLocations = busDoc['haltLocations'] ?? [];
        setState(() {
          _haltLocations = haltLocations
              .map((location) => LatLng(location.latitude, location.longitude))
              .toList();
          _markers = _haltLocations
              .map((location) => Marker(
                    markerId: MarkerId(location.toString()),
                    position: location,
                    infoWindow: InfoWindow(title: 'Halt'),
                    onTap: () {
                      _onMarkerTapped(location);
                    },
                  ))
              .toSet();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching halt locations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save halt locations to Firestore
  Future<void> _saveHaltLocations() async {
    try {
      List<GeoPoint> geoPoints = _haltLocations
          .map((location) => GeoPoint(location.latitude, location.longitude))
          .toList();
      await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busId)
          .update({'haltLocations': geoPoints});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Halt locations saved successfully'),
      ));
    } catch (e) {
      print('Error saving halt locations: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save halt locations'),
      ));
    }
  }

  // Add marker for halt location
  void _onMapTapped(LatLng location) {
    setState(() {
      _haltLocations.add(location);
      _markers.add(Marker(
        markerId: MarkerId(location.toString()),
        position: location,
        infoWindow: InfoWindow(title: 'Halt'),
        onTap: () {
          _onMarkerTapped(location);
        },
      ));
    });
  }

  // Handle marker tap (select and delete marker)
  void _onMarkerTapped(LatLng location) {
    // Confirm deletion before removing the halt
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Halt'),
        content: Text('Are you sure you want to delete this halt?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _deleteHaltLocation(location);
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Delete halt location from map and Firestore
  Future<void> _deleteHaltLocation(LatLng location) async {
    setState(() {
      _haltLocations.remove(location);
      _markers.removeWhere((marker) => marker.position == location);
    });

    try {
      // Remove the halt location from Firestore
      List<GeoPoint> geoPoints = _haltLocations
          .map((location) => GeoPoint(location.latitude, location.longitude))
          .toList();
      await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busId)
          .update({'haltLocations': geoPoints});

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Halt deleted successfully'),
      ));
    } catch (e) {
      print('Error deleting halt location: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to delete halt location'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mark Halts for Bus'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(); // Pop the screen off the stack
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveHaltLocations,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _haltLocations.isNotEmpty
                    ? _haltLocations.first
                    : LatLng(0.0, 0.0),
                zoom: 15.0,
              ),
              markers: _markers,
              onTap: _onMapTapped, // Allows user to tap and add halt locations
            ),
    );
  }
}
