import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String geminiModel = 'gemini-3.8-flash-lite';
const String aiName = 'O-A AI';

const String aiInstructions =
    'You are O-A AI, an expert academic tutor inside a study chat app. '
    'Read the attached image carefully, then answer accurately and step by '
    'step: first restate what is asked in one short line, then solve it in '
    'clearly numbered steps showing the reasoning and calculations, then '
    'give the final answer on its own line. Double-check the result before '
    'answering. If the user wrote a caption, treat it as part of the '
    'question and reply in the same language as the caption; if there is no '
    'caption, reply in Arabic. If the image is unclear, say what is unclear '
    'instead of guessing.';

void main() {
  runApp(const OAStudyApp());
}

class OAStudyApp extends StatelessWidget {
  const OAStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'O-A Study App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? userId;
  List<String> rooms = ['General Study', 'Mathematics', 'Physics', 'Programming'];
  String selectedRoom = 'General Study';
  List<Map<String, String>> messages = [];
  bool aiLoading = false;
  bool _busy = false;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initUser();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // يُغلق التطبيق تماماً عند ذهابه للخلفية أو قفل الشاشة
    // (لا يُغلق أثناء فتح الكاميرا أو المعرض أو انتظار رد الذكاء الاصطناعي)
    if (state == AppLifecycleState.paused && !_busy && !aiLoading) {
      SystemNavigator.pop();
      exit(0);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('user_id');
    if (id == null) {
      id = 'Anon_${const Uuid().v4().substring(0, 6)}';
      await prefs.setString('user_id', id);
    }
    setState(() {
      userId = id;
    });
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('chat_$selectedRoom') ?? [];
    setState(() {
      messages = saved
          .map((m) => Map<String, String>.from(jsonDecode(m) as Map))
          .toList();
    });
    _scrollDown();
  }

  Future<void> _append(String room, Map<String, String> msg) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_$room';
    final list = prefs.getStringList(key) ?? [];
    list.add(jsonEncode(msg));
    await prefs.setStringList(key, list);
    if (room == selectedRoom && mounted) {
      setState(() {
        messages.add(msg);
      });
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    await _append(selectedRoom, {
      'user': userId ?? 'Anon',
      'text': text,
      'image': '',
    });
  }

  Future<void> _pickAndSend(ImageSource source) async {
    _busy = true;
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    _busy = false;
    if (picked == null) return;
    final caption = _msgController.text.trim();
    _msgController.clear();
    final room = selectedRoom;
    await _append(room, {
      'user': userId ?? 'Anon',
      'text': caption,
      'image': picked.path,
    });
    await _askAI(room, picked.path, caption);
  }

  Future<void> _askAI(String room, String path, String caption) async {
    setState(() {
      aiLoading = true;
    });
    String answer = '';
    try {
      final model =
          GenerativeModel(model: geminiModel, apiKey: geminiApiKey);
      final bytes = await File(path).readAsBytes();
      final List<Part> parts = [
        TextPart(aiInstructions),
        if (caption.isNotEmpty) TextPart('User caption: $caption'),
        DataPart('image/jpeg', bytes),
      ];
      const int maxAttempts = 10;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final response =
              await model.generateContent([Content.multi(parts)]);
          answer = response.text ?? 'No response generated.';
          break;
        } catch (e) {
          final msg = e.toString();
          final busy = msg.contains('high demand') ||
              msg.contains('overloaded') ||
              msg.contains('503');
          if (busy && attempt < maxAttempts) {
            await Future.delayed(const Duration(seconds: 5));
            continue;
          }
          answer = busy
              ? 'الخادم مزدحم الآن، أعد إرسال الصورة بعد قليل.'
              : 'Error: $e';
          break;
        }
      }
    } catch (e) {
      answer = 'Error: $e';
    }
    await _append(room, {'user': aiName, 'text': answer, 'image': ''});
    if (mounted) {
      setState(() {
        aiLoading = false;
      });
    }
  }

  Widget _bubble(Map<String, String> msg) {
    final user = msg['user'] ?? '';
    final text = msg['text'] ?? '';
    final image = msg['image'] ?? '';
    final isMe = user == userId;
    final isAI = user == aiName;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white12
              : (isAI ? Colors.white10 : Colors.transparent),
          border: Border.all(color: isAI ? Colors.white54 : Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isAI ? '🤖 $user' : user,
                style: const TextStyle(color: Colors.grey, fontSize: 10)),
            const SizedBox(height: 4),
            if (image.isNotEmpty && File(image).existsSync())
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(image), height: 180, fit: BoxFit.cover),
                ),
              ),
            if (text.isNotEmpty)
              SelectableText(text,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('O-A : $selectedRoom',
            style: const TextStyle(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.black,
        elevation: 1,
      ),
      drawer: Drawer(
        backgroundColor: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white24))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('O-A Anonymous',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text('ID: ${userId ?? "Loading..."}',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('STUDY ROOMS',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            ),
            ...rooms.map((room) => ListTile(
                  title: Text(room,
                      style: TextStyle(
                          color: room == selectedRoom
                              ? Colors.white
                              : Colors.grey)),
                  onTap: () {
                    setState(() {
                      selectedRoom = room;
                    });
                    _loadMessages();
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) => _bubble(messages[index]),
            ),
          ),
          if (aiLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('O-A AI is answering...',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white24))),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onPressed: () => _pickAndSend(ImageSource.camera),
                ),
                IconButton(
                  icon: const Icon(Icons.photo, color: Colors.white),
                  onPressed: () => _pickAndSend(ImageSource.gallery),
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
