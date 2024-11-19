import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

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
    // TODO: implement initState
    super.initState();
    _localRTCVideoRenderer.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fi'),
      ),
      body: const Center(
        child: Text(''),
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
      log('Created peer connection $peerConnection');
      return peerConnection;
    }

    await createCallsSession();
    // var rtcPeerConnection = await createConnection();

    // get localStream
    _localStream = await navigator.mediaDevices.getUserMedia(
      {
        'audio': true,
        'video': true,
      },
    );
  }

  createCallsSession() async {
    final sessionResponse = await http.post(
      Uri.parse('$API_BASE/sessions/new'),
      headers: headers,
    );
    if (sessionResponse.statusCode == 201) {
      final sessionId = jsonDecode(sessionResponse.body)['sessionId'];
      log('Session ID: $sessionId');
    }
  }
}
