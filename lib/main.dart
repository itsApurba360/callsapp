import 'dart:convert';
import 'dart:developer';
import 'package:uuid/uuid.dart';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calls Echo Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const VideoCallScreen(),
    );
  }
}

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final talker = TalkerFlutter.init();
  final API_BASE =
      'https://rtc.live.cloudflare.com/v1/apps/f4293f4a0b5ba133aea46f942ccb4129';
  final APP_TOKEN =
      "1b90bec53b211f68f1b89c35964d6740964853262c9f36613009919878562a4a";
  var headers = {
    'Authorization':
        'Bearer 1b90bec53b211f68f1b89c35964d6740964853262c9f36613009919878562a4a',
  };
  final _localRTCVideoRenderer = RTCVideoRenderer();
  // mediaStream for localPeer
  MediaStream? _localStream;

  @override
  void initState() {
    super.initState();
    _localRTCVideoRenderer.initialize();
    setupPeerConnection(); // Call this here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TalkerScreen(talker: talker),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const Text('Hello'),
            RTCVideoView(
              _localRTCVideoRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: true, // Mirror the local video
              filterQuality: FilterQuality.low, // Might help with performance
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await setupPeerConnection();
        },
        child: const Icon(Icons.call),
      ),
    );
  }

  // / Creates a peer connection with some default settings

  Future setupPeerConnection() async {
    await Permission.camera.request();
    await Permission.microphone.request();
    Future<RTCPeerConnection> createConnection() async {
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {
            'urls': 'stun:stun.cloudflare.com:3478',
          },
        ],
        'bundlePolicy': 'max-bundle',
      };

      // Create the peer connection
      RTCPeerConnection peerConnection =
          await createPeerConnection(configuration);
      talker.verbose('Created peer connection $peerConnection');
      return peerConnection;
    }

    final localSessionId = await createCallsSession();
    var rtcPeerConnection = await createConnection();

    // get localStream
    _localStream = await navigator.mediaDevices.getUserMedia(
      {
        'audio': true,
        'video': true,
      },
    );
    // set source for local video renderer
    _localRTCVideoRenderer.srcObject = _localStream;
    setState(() {}); // Force rebuild
    // Next we need to push our audio and video tracks. We will add them to the peer
    // connection using the addTransceiver API which allows us to specify the direction

    final transceivers = _localStream!
        .getTracks()
        .map(
          (track) => rtcPeerConnection.addTransceiver(
            track: track,
            init: RTCRtpTransceiverInit(
              direction: TransceiverDirection.SendOnly,
            ),
          ),
        )
        .toList();

// Now that the peer connection has tracks we create an SDP offer.
    final localOffer = await rtcPeerConnection.createOffer();
// And apply that offer as the local description.
    await rtcPeerConnection.setLocalDescription(localOffer);
    talker.verbose('Created local offer $localOffer');

    final transceiversResult = await Future.wait(transceivers);
    var uuid = const Uuid();
    var midCounter = 0;
    final tracks = transceiversResult.map(
      (item) {
        var mid = item.mid ??
            'generated-${uuid.v4()}'; // or 'generated-${midCounter++}'
        talker.verbose(
            'Processing transceiver: mid=${item.mid}, trackId=${item.sender.track?.id}');
        return {
          "location": "local",
          "mid": item.mid,
          "trackName": item.sender.track?.id,
        };
      },
    ).toList();

    talker.verbose('Tracks to be sent: $tracks');
    // Send the local session description to the Calls API, it will
    // respond with an answer and trackIds.

    talker.verbose('Transceivers result: ${transceiversResult.map((t) => {
          'mid': t.mid,
          'sender.track.id': t.sender.track?.id
        }).toList()}');

    talker.verbose('Tracks to be sent: $tracks');

    final pushTracksResponse = await http.post(
      Uri.parse('$API_BASE/sessions/$localSessionId/tracks/new'),
      headers: headers,
      body: jsonEncode(
        {
          "sessionDescription": {"sdp": localOffer.sdp, "type": "offer"},
          "tracks": tracks,
        },
      ),
    );

    talker.verbose('Pushed tracks ${pushTracksResponse.body}');
  }

  createCallsSession() async {
    final sessionResponse = await http.post(
      Uri.parse('$API_BASE/sessions/new'),
      headers: headers,
    );
    if (sessionResponse.statusCode == 201) {
      final sessionId = jsonDecode(sessionResponse.body)['sessionId'];
      talker.verbose('Session ID: $sessionId');
      return sessionId;
    }
  }
}

