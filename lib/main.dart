import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(SegarRadiosApp());
}

class SegarRadiosApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RadioPlayer(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Segar Radios',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
        ),
        home: SplashScreen(),
      ),
    );
  }
}

// Splash Screen
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.radio, color: Colors.white, size: 100),
            SizedBox(height: 20),
            Text(
              'Segar Radios',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Segar Radios'),
        leading: Icon(Icons.radio),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: RadioSearchDelegate());
            },
          ),
        ],
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(child: buildRadioList()),
          NowPlayingBar(),
        ],
      ),
    );
  }

  // Function to fetch and display radios from Firestore
  Widget buildRadioList() {
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance.ref('radio_stations').once(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Get the data from the DatabaseEvent
        final stations =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

        if (stations == null || stations.isEmpty) {
          return Center(child: Text('No radio stations found'));
        }

        // Convert to a list
        final radios = stations.entries.map((entry) {
          final data = entry.value;
          return {
            'station_name': data['station_name'],
            'station_url': data['station_url'],
            'album_art_url': data['album_art_url'],
          };
        }).toList();

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 tiles per row
            childAspectRatio: 1, // Square tiles
          ),
          itemCount: radios.length,
          itemBuilder: (context, index) {
            var radio = radios[index];
            return RadioTile(
              name: radio['station_name'],
              streamUrl: radio['station_url'],
              albumArt: radio['album_art_url'],
            );
          },
        );
      },
    );
  }
}

// Search Functionality
class RadioSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = "";
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Text("Search results for '$query'");
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Text("Search for radios");
  }
}

// Radio Tile Widget
class RadioTile extends StatelessWidget {
  final String name;
  final String streamUrl;
  final String albumArt;

  RadioTile(
      {required this.name, required this.streamUrl, required this.albumArt});

  @override
  Widget build(BuildContext context) {
    final radioPlayer = Provider.of<RadioPlayer>(context, listen: false);

    return GestureDetector(
      onTap: () {
        radioPlayer.playRadio(name, streamUrl, albumArt);
      },
      child: Card(
        color: Colors.grey[900],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(albumArt, height: 80, width: 80, fit: BoxFit.cover),
            SizedBox(height: 8),
            Text(name, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// Now Playing Bar
class NowPlayingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final radioPlayer = Provider.of<RadioPlayer>(context);

    if (!radioPlayer.isPlaying)
      return Container(); // Hide if nothing is playing

    return Container(
      color: Colors.grey[850],
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          Image.network(radioPlayer.albumArt,
              height: 50, width: 50, fit: BoxFit.cover),
          SizedBox(width: 10),
          Text(radioPlayer.currentRadio, style: TextStyle(color: Colors.white)),
          Spacer(),
          IconButton(
            icon: Icon(Icons.stop, color: Colors.white),
            onPressed: () {
              radioPlayer.stopRadio();
            },
          ),
        ],
      ),
    );
  }
}

// Radio Player Provider (handles audio streaming)
class RadioPlayer extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String currentRadio = "";
  String albumArt = "";
  bool isPlaying = false;

  void playRadio(String name, String streamUrl, String albumArtUrl) {
    currentRadio = name;
    albumArt = albumArtUrl;
    _audioPlayer.play(UrlSource(streamUrl)); // Use UrlSource instead of String

    isPlaying = true;
    notifyListeners();
  }

  void stopRadio() {
    _audioPlayer.stop();
    isPlaying = false;
    notifyListeners();
  }
}
