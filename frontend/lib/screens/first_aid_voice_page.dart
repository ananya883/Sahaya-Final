import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class FirstAidVoicePage extends StatefulWidget {
  const FirstAidVoicePage({super.key});

  @override
  State<FirstAidVoicePage> createState() => _FirstAidVoicePageState();
}

class _FirstAidVoicePageState extends State<FirstAidVoicePage> {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isLoading = false;
  String _userText = "Tap the mic and speak";
  String _botReply = "";
  final List<Map<String, dynamic>> _chatHistory = [];
  final ScrollController _scrollController = ScrollController();

  // RASA Configuration
  static const String _rasaUrl = "http://192.168.174.138:5002/webhooks/rest/webhook";
  // For real device: "http://192.168.1.100:5005/webhooks/rest/webhook"
  late String _senderId;
  @override
  void initState() {
    super.initState();
    _senderId = "sahaya_user_${DateTime.now().millisecondsSinceEpoch}";
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initializeTTS();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _initializeTTS() async {
    await _tts.setLanguage("ml-IN"); // Malayalam
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onError: (error) => print("Speech error: $error"),
      );

      if (available) {
        setState(() => _isListening = true);

        _speech.listen(
          onResult: (result) async {
            setState(() {
              _userText = result.recognizedWords;
            });

            if (result.finalResult) {
              _speech.stop();
              setState(() => _isListening = false);
              await _sendToRasa(_userText);
            }
          },
          listenFor: Duration(seconds: 30),
          localeId: 'ml_IN', // Malayalam
        );
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }
  Future<void> _sendToRasa(String message) async {
    print("🔄 ====== START _sendToRasa ======");
    print("📱 Device: Physical Phone");
    print("💻 PC IP: localhost");
    print("🔗 Rasa URL: $_rasaUrl");
    print("✉️ Message: '$message' (length: ${message.length})");
    print("👤 Sender ID: $_senderId");

    if (message.trim().isEmpty) {
      print("❌ Empty message, returning");
      return;
    }

    // Add user message
    setState(() {
      _chatHistory.add({
        'text': message,
        'isUser': true,
        'time': DateTime.now(),
      });
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      print("📤 Preparing HTTP POST request...");

      // Prepare the request
      final uri = Uri.parse(_rasaUrl);
      final headers = {"Content-Type": "application/json"};
      final body = jsonEncode({
        "sender": _senderId,
        "message": message,
      });

      print("🔗 URI: $uri");
      print("📝 Headers: $headers");
      print("📦 Body: $body");

      // Send the request with timeout
      print("🚀 Sending request...");
      final stopwatch = Stopwatch()..start();

      final response = await http.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(Duration(seconds: 10));

      stopwatch.stop();
      print("⏱️ Request took: ${stopwatch.elapsedMilliseconds}ms");
      print("📥 HTTP Status: ${response.statusCode}");
      print("📥 Response Headers: ${response.headers}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        print("✅ HTTP 200 OK");
        final data = jsonDecode(response.body);

        if (data is List && data.isNotEmpty) {
          String botReply = data[0]["text"];
          print("🤖 Bot reply: $botReply");

          setState(() {
            _botReply = botReply;
            _chatHistory.add({
              'text': botReply,
              'isUser': false,
              'time': DateTime.now(),
            });
            _isLoading = false;
          });

          await _speakResponse(botReply);
        } else {
          print("⚠️ Empty or invalid response array");
          throw Exception("Empty response from Rasa: $data");
        }
      } else {
        print("❌ HTTP Error: ${response.statusCode}");
        print("❌ Error body: ${response.body}");
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException catch (e) {
      print("⏰ TIMEOUT ERROR: $e");
      print("💡 The request took too long (>10 seconds)");

      setState(() {
        _chatHistory.add({
          'text': "⏰ Timeout - Server took too long to respond",
          'isUser': false,
          'time': DateTime.now(),
        });
        _isLoading = false;
      });
    } on http.ClientException catch (e) {
      print("🌐 NETWORK ERROR: $e");
      print("💡 This is a network-level error (DNS, connection refused, etc.)");

      setState(() {
        _chatHistory.add({
          'text': "🌐 Network Error: ${e.message}\n\nCheck:\n1. Rasa server running?\n2. Server URL: localhost:5002\n3. Running on emulator? (localhost works for emulator)",
          'isUser': false,
          'time': DateTime.now(),
        });
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print("❌ UNEXPECTED ERROR: $e");
      print("📋 Stack trace: $stackTrace");
      print("🔍 Error type: ${e.runtimeType}");

      setState(() {
        _chatHistory.add({
          'text': "❌ Error: ${e.toString().split('\n').first}",
          'isUser': false,
          'time': DateTime.now(),
        });
        _isLoading = false;
      });
    }

    print("🔄 ====== END _sendToRasa ======");
    _scrollToBottom();
  }
  Future<void> _speakResponse(String text) async {
    if (text.isNotEmpty) {
      await _tts.speak(text);
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    return Align(
      alignment: message['isUser'] ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message['isUser'] ? Colors.blue[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: message['isUser'] ? Colors.blue[100]! : Colors.green[100]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['isUser'] ? 'You' : 'Sahaya',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              message['text'],
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("First Aid Voice Assistant"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          if (_isSpeaking)
            IconButton(
              icon: Icon(Icons.volume_off),
              onPressed: _stopSpeaking,
              tooltip: 'Stop speaking',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status indicator
          Container(
            padding: EdgeInsets.all(12),
            color: _isListening ? Colors.red[50] : Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : Colors.blue,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  _isListening ? "Listening... Speak now" : "Tap mic to speak",
                  style: TextStyle(
                    color: _isListening ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Chat area
          Expanded(
            child: _chatHistory.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services, size: 80, color: Colors.blueAccent.withOpacity(0.3)),
                  SizedBox(height: 20),
                  Text(
                    "Sahaya Medical Assistant",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Speak your medical query in English or Malayalam\n\nExamples:\n• 'heart pain'\n• 'നമസ്കാരം'\n• 'പനി'\n• 'snake bite'",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(8),
              itemCount: _chatHistory.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _chatHistory.length) {
                  return _buildMessageBubble(_chatHistory[index]);
                } else {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 16),
                        Text("Sahaya is thinking..."),
                      ],
                    ),
                  );
                }
              },
            ),
          ),

          // Input area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      onSubmitted: (value) => _sendToRasa(value),
                      decoration: InputDecoration(
                        hintText: "Type your message...",
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.send, color: Colors.blueAccent),
                          onPressed: () => _sendToRasa(_userText),
                        ),
                      ),
                      onChanged: (value) => setState(() => _userText = value),
                      controller: TextEditingController(text: _userText),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _listen,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? Colors.red : Colors.blueAccent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _scrollController.dispose();
    super.dispose();
  }
}