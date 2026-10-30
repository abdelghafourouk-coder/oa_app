import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() {
  runApp(const OAStudyApp());
}

const String geminiApiKey = "YOUR_GEMINI_API_KEY_HERE";
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
  List> messages = [];
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
          return {'user': parts[0], 'text': parts[1]};
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
    List<String> raw = messages.map((m) => '${m['user']}||${m['text']}').toList();
    await prefs.setStringList('msgs_$selectedRoom', raw);
    _msgController.clear();
  }
  
