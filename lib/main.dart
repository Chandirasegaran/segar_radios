import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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

// Splash screen that displays for 3 seconds
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

// Home screen displaying the radio stations
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> radios = [];

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
              showSearch(
                context: context,
                delegate: RadioSearchDelegate(radios),
              );
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

  // Fetch radio stations from Firebase and build the list
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

        final stations = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

        if (stations == null || stations.isEmpty) {
          return Center(child: Text('No radio stations found'));
        }

        radios = stations.entries.map((entry) {
          final data = entry.value as Map<dynamic, dynamic>;
          return {
            'station_name': data['station_name'] as String,
            'station_url': data['station_url'] as String,
            'album_art_url': data['album_art_url'] as String,
          };
        }).toList().cast<Map<String, String>>();

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1,
          ),
          itemCount: radios.length,
          itemBuilder: (context, index) {
            var radio = radios[index];
            return RadioTile(
              name: radio['station_name']!,
              streamUrl: radio['station_url']!,
              albumArt: radio['album_art_url']!,
            );
          },
        );
      },
    );
  }
}

// Search delegate for radio stations
class RadioSearchDelegate extends SearchDelegate {
  final List<Map<String, String>> radioStations;

  RadioSearchDelegate(this.radioStations);

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
    final results = radioStations
        .where((station) =>
        station['station_name']!.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return results.isEmpty
        ? Center(child: Text("No results found"))
        : GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        var radio = results[index];
        return RadioTile(
          name: radio['station_name']!,
          streamUrl: radio['station_url']!,
          albumArt: radio['album_art_url']!,
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Text("Search radio stations by name"),
    );
  }
}

// Widget representing each radio station tile
class RadioTile extends StatelessWidget {
  final String name;
  final String streamUrl;
  final String albumArt;

  RadioTile({
    required this.name,
    required this.streamUrl,
    required this.albumArt,
  });

  @override
  Widget build(BuildContext context) {
    final radioPlayer = Provider.of<RadioPlayer>(context);

    return GestureDetector(
      onTap: () {
        radioPlayer.playRadio(name, streamUrl, albumArt);
      },
      child: Card(
        color: Colors.grey[900],
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(albumArt, height: 80, width: 80, fit: BoxFit.cover),
                SizedBox(height: 8),
                Text(name, style: TextStyle(color: Colors.white)),
              ],
            ),
            // Show buffering indicator if applicable
            if (radioPlayer.currentRadio == name && radioPlayer.isBuffering)
              CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// Now playing bar that displays the current station and playback controls
class NowPlayingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final radioPlayer = Provider.of<RadioPlayer>(context);

    return Container(
      color: Colors.grey[850],
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          // Display album art or default icon
          if (radioPlayer.isPlaying || radioPlayer.isBuffering)
            Image.network(radioPlayer.albumArt, height: 50, width: 50, fit: BoxFit.cover)
          else
            Icon(Icons.radio, size: 50, color: Colors.white54),
          SizedBox(width: 10),
          // Display current station name or message
          Text(
            radioPlayer.isPlaying || radioPlayer.isBuffering
                ? radioPlayer.currentRadio
                : "No station playing",
            style: TextStyle(color: Colors.white),
          ),
          Spacer(),
          // Stop button
          if (radioPlayer.isPlaying || radioPlayer.isBuffering)
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

// Radio player logic and state management
class RadioPlayer extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String currentRadio = "";
  String albumArt = "";
  bool isPlaying = false;
  bool isBuffering = false;

  // Play selected radio station
  void playRadio(String name, String streamUrl, String albumArtUrl) async {
    print("Attempting to play: $streamUrl");
    currentRadio = name;
    albumArt = albumArtUrl;
    isBuffering = true;
    notifyListeners();

    try {
      await _audioPlayer.setUrl(streamUrl);
      _audioPlayer.playerStateStream.listen((playerState) {
        final isPlaying = playerState.playing;
        final processingState = playerState.processingState;

        this.isPlaying = isPlaying && processingState == ProcessingState.ready;
        this.isBuffering = processingState == ProcessingState.buffering;

        // Stop buffering when the stream is ready
        if (processingState == ProcessingState.ready) {
          isBuffering = false;
        }

        notifyListeners();
      });
      await _audioPlayer.play();
    } catch (e) {
      print("Error playing stream: $e");
      isPlaying = false;
      isBuffering = false;
    }
    notifyListeners();
  }

  // Stop playback
  void stopRadio() {
    _audioPlayer.stop();
    isPlaying = false;
    isBuffering = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
