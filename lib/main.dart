import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

const String geminiApiKey = "YOUR_GEMINI_API_KEY_HERE";

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

class _HomeScreenState extends State<HomeScreen> {
  String? userId;
  List<String> rooms = ['General Study', 'Mathematics', 'Physics', 'Programming'];
  String selectedRoom = 'General Study';
  List<Map<String, String>> messages = [];
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initUser();
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
    List<String>? saved = prefs.getStringList('msgs_$selectedRoom');
    if (saved != null) {
      setState(() {
        messages = saved.map((m) {
          final parts = m.split('||');
          return <String, String>{
            'user': parts[0],
            'text': parts.length > 1 ? parts.sublist(1).join('||') : '',
          };
        }).toList();
      });
    } else {
      setState(() {
        messages = [];
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      messages.add({'user': userId ?? 'Anon', 'text': text});
    });
    List<String> raw =
        messages.map((m) => '${m['user']}||${m['text']}').toList();
    await prefs.setStringList('msgs_$selectedRoom', raw);
    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('O-A : $selectedRoom',
            style: const TextStyle(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy, color: Colors.white),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AISolverScreen()));
            },
          ),
        ],
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
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                bool isMe = msg['user'] == userId;
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white12 : Colors.transparent,
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['user']!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(msg['text']!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white24))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () => _sendMessage(_msgController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AISolverScreen extends StatefulWidget {
  const AISolverScreen({super.key});

  @override
  State<AISolverScreen> createState() => _AISolverScreenState();
}

class _AISolverScreenState extends State<AISolverScreen> {
  File? _image;
  bool _loading = false;
  String _solution = '';
  final TextEditingController _promptController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  Future<void> _solve() async {
    if (_image == null && _promptController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _solution = '';
    });

    try {
      final model =
          GenerativeModel(model: 'gemini-2.5-flash', apiKey: geminiApiKey);
      final List<Part> contentList = [];

      if (_promptController.text.trim().isNotEmpty) {
        contentList.add(TextPart(_promptController.text.trim()));
      } else {
        contentList.add(TextPart('Solve this academic problem step-by-step:'));
      }

      if (_image != null) {
        final imageBytes = await _image!.readAsBytes();
        contentList.add(DataPart('image/jpeg', imageBytes));
      }

      final response = await model.generateContent([Content.multi(contentList)]);
      setState(() {
        _solution = response.text ?? 'No response generated.';
      });
    } catch (e) {
      setState(() {
        _solution = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Study Solver',
            style: TextStyle(fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_image != null)
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text('Camera',
                      style: TextStyle(color: Colors.white)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo, color: Colors.white),
                  label: const Text('Gallery',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ask or describe the problem...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _loading ? null : _solve,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('SOLVE WITH AI',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            if (_solution.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SOLUTION:',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text(_solution,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
