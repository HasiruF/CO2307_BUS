import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class BusRouteMapPage extends StatefulWidget {
  final String userId;
  final String busId;
  final int gettingOnHaltIndex;
  final int gettingOffHaltIndex;

  BusRouteMapPage({
    required this.userId,
    required this.busId,
    required this.gettingOnHaltIndex,
    required this.gettingOffHaltIndex,
  });

  @override
  _BusRouteMapPageState createState() => _BusRouteMapPageState();
}

class _BusRouteMapPageState extends State<BusRouteMapPage> {
  late GoogleMapController _mapController;
  late LatLng _userLocation;
  late LatLng _busLocation;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  List<LatLng> _halts = [];
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _haltIcon;
  BitmapDescriptor? _userIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons();
    _fetchUserLocation();
    _fetchBusRouteDetails();
  }

  // Load custom icons for bus, halt, and user
  Future<void> _loadCustomIcons() async {
    _busIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(5, 5)),
      'assets/bus_icon.png',
    );
    _haltIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(5, 5)),
      'assets/halt_icon.png',
    );
    _userIcon = await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(5, 5)),
      'assets/user_icon.png',
    );
  }

  // Fetch user location from Firestore
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
            icon: _userIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: 'Your Location'),
          ));
        });
      } else {
        print('User document not found');
      }
    } catch (e) {
      print('Error fetching user location: $e');
    }
  }

  // Fetch bus and halts data from Firestore
  Future<void> _fetchBusRouteDetails() async {
    try {
      DocumentSnapshot busDoc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busId)
          .get();

      if (busDoc.exists) {
        List<dynamic> haltLocations = busDoc['haltLocations'] ?? [];
        setState(() {
          _halts = haltLocations
              .map((location) => LatLng(location.latitude, location.longitude))
              .toList();

          // Add markers for getting on and getting off halts
          if (_halts.isNotEmpty) {
            // Getting on halt
            _markers.add(Marker(
              markerId: MarkerId('getting_on_halt'),
              position: _halts[widget.gettingOnHaltIndex],
              icon: _haltIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(title: 'Getting On Halt', onTap: () {
                _openGoogleMapsDirections(_halts[widget.gettingOnHaltIndex]);
              }),
            ));

            // Getting off halt
            /*_markers.add(Marker(
              markerId: MarkerId('getting_off_halt'),
              position: _halts[widget.gettingOffHaltIndex],
              icon: _haltIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(title: 'Getting Off Halt', onTap: () {
                _openGoogleMapsDirections(_halts[widget.gettingOffHaltIndex]);
              }),
            ));*/
          }

          // Fetching driver location from users collection
          _fetchDriverLocation(busDoc['driver_id']);
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bus route details: $e');
    }
  }

  // Fetch the driver's location from the users collection
  Future<void> _fetchDriverLocation(String driverId) async {
    try {
      DocumentSnapshot driverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        // Extracting driver's location from the document
        GeoPoint driverLocation = driverDoc['location'];
        LatLng driverLatLng = LatLng(driverLocation.latitude, driverLocation.longitude);

        // Add driver marker as bus location
        setState(() {
          _markers.add(Marker(
            markerId: MarkerId('driver'),
            position: driverLatLng,
            icon: _busIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: 'Driver Location'),
          ));
        });
      }
    } catch (e) {
      print('Error fetching driver location: $e');
    }
  }

  // Open Google Maps with directions to the halt location
  Future<void> _openGoogleMapsDirections(LatLng haltLocation) async {
    final String googleMapsUrl = 
      'https://www.google.com/maps/dir/?api=1&origin=${_userLocation.latitude},${_userLocation.longitude}&destination=${haltLocation.latitude},${haltLocation.longitude}&travelmode=driving';
    
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus Route Map'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _userLocation,
                zoom: 15.0,
              ),
              markers: _markers,
            ),
    );
  }
}
