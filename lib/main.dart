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
            crossAxisCount: 2,
            childAspectRatio: 1,
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


class RadioTile extends StatelessWidget {
  final String name;
  final String streamUrl;
  final String albumArt;

  RadioTile({required this.name, required this.streamUrl, required this.albumArt});

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
            if (radioPlayer.currentRadio == name && radioPlayer.isBuffering)
              CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class NowPlayingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final radioPlayer = Provider.of<RadioPlayer>(context);

    return Container(
      color: Colors.grey[850],
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          if (radioPlayer.isPlaying || radioPlayer.isBuffering)
            Image.network(radioPlayer.albumArt,
                height: 50, width: 50, fit: BoxFit.cover)
          else
            Icon(Icons.radio, size: 50, color: Colors.white54),
          SizedBox(width: 10),
          Text(
            radioPlayer.isPlaying || radioPlayer.isBuffering
                ? radioPlayer.currentRadio
                : "No station playing",
            style: TextStyle(color: Colors.white),
          ),
          Spacer(),
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

class RadioPlayer extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String currentRadio = "";
  String albumArt = "";
  bool isPlaying = false;
  bool isBuffering = false;

  void playRadio(String name, String streamUrl, String albumArtUrl) async {
    print("Attempting to play: $streamUrl");
    currentRadio = name;
    albumArt = albumArtUrl;
    isBuffering = true;
    notifyListeners();

    try {
      await _audioPlayer.setUrl(streamUrl);
      await _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((playerState) {
        final isPlaying = playerState.playing;
        final processingState = playerState.processingState;
        print("Player state: playing=$isPlaying, processingState=$processingState");
        this.isPlaying = isPlaying && processingState == ProcessingState.ready;
        this.isBuffering = processingState == ProcessingState.buffering;
        notifyListeners();
      });
    } catch (e) {
      print("Error playing stream: $e");
      isPlaying = false;
      isBuffering = false;
    }
    notifyListeners();
  }

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