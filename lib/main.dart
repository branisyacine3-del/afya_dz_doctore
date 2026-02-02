import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // مكتبة الاتصال الجديدة
import 'dart:convert'; // لتحليل البيانات
import 'package:webview_flutter/webview_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AfyaDZApp());
}

class AfyaDZApp extends StatelessWidget {
  const AfyaDZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Afya DZ',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00BFA5),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoginScreen();
        return PaymentCheckGate(user: snapshot.data!);
      },
    );
  }
}

class PaymentCheckGate extends StatelessWidget {
  final User user;
  const PaymentCheckGate({super.key, required this.user});
  @override
  Widget build(BuildContext context) {
    if (user.phoneNumber == "+213697443312" || user.phoneNumber == "+2130697443312") {
       return const DoctorScreen(isAdmin: true);
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData?['isPaid'] ?? false) return const DoctorScreen(isAdmin: false);
        return PaymentScreen(user: user);
      },
    );
  }
}

// --- شاشة الطبيب (باستخدام Groq / Llama 3) ---
class DoctorScreen extends StatefulWidget {
  final bool isAdmin;
  const DoctorScreen({super.key, required this.isAdmin});
  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _statusText = "اضغط للتحدث";
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late AnimationController _animationController;

  // 🔴🔴 ضع مفتاح Groq الجديد هنا (يبدأ بـ gsk_) 🔴🔴
  final String _apiKey = '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';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000), lowerBound: 0.0, upperBound: 0.1,
    )..addListener(() { setState(() {}); });
    _addMessage("role", "assistant", "مرحباً بك في Afya DZ 🩺\nأنا طبيبك الذكي، بماذا تشعر اليوم؟");
  }

  void _addMessage(String key, String role, String text) {
    setState(() { _messages.add({"role": role, "text": text}); });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _listen() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) { _addMessage("role", "assistant", "⚠️ فعل المايكروفون من الإعدادات"); return; }
    if (!_isListening) {
      bool available = await _speech.initialize(
        onError: (val) => setState(() { _isListening = false; _statusText = "خطأ مايكروفون"; _animationController.stop(); }),
      );
      if (available) {
        setState(() { _isListening = true; _statusText = "جاري الاستماع..."; _animationController.repeat(reverse: true); });
        _speech.listen(onResult: (val) {
          if (val.finalResult) {
            setState(() { _isListening = false; _animationController.stop(); _animationController.reset(); _statusText = "اضغط للتحدث"; });
            if (val.recognizedWords.isNotEmpty) _handleUserMessage(val.recognizedWords);
          }
        }, localeId: 'ar-DZ');
      }
    } else {
      setState(() { _isListening = false; _animationController.stop(); _animationController.reset(); _statusText = "اضغط للتحدث"; });
      _speech.stop();
    }
  }

  // دالة الاتصال الجديدة (Groq API)
  Future<void> _handleUserMessage(String message) async {
    _addMessage("role", "user", message);
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey', // استخدام المفتاح
        },
        body: jsonEncode({
          'model': 'llama3-70b-8192', // موديل قوي جداً وسريع
          'messages': [
            {
              'role': 'system', 
              'content': 'أنت طبيب ذكي جزائري في تطبيق Afya DZ. تكلم بالدارجة الجزائرية المفهومة. حلل الأعراض باختصار وإذا الحالة خطيرة اطلب المستشفى.'
            },
            {'role': 'user', 'content': message}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];
        _addMessage("role", "assistant", reply);
      } else {
        _addMessage("role", "assistant", "حدث خطأ في الاتصال: ${response.statusCode}");
      }
    } catch (e) {
      _addMessage("role", "assistant", "🔴 حدث خطأ:\n$e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Afya DZ", style: TextStyle(color: Colors.white)), centerTitle: true, backgroundColor: const Color(0xFF00BFA5)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, padding: const EdgeInsets.all(20), itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(color: isUser ? const Color(0xFF00BFA5) : Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [if(!isUser) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]),
                    child: Text(msg['text']!, style: TextStyle(fontSize: 16, color: isUser ? Colors.white : Colors.black87)),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: Text("جاري التشخيص...", style: TextStyle(color: Colors.grey))),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
            child: Column(children: [
              Text(_statusText, style: TextStyle(color: _isListening ? Colors.red : Colors.grey[600], fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: _listen,
                child: ScaleTransition(scale: Tween(begin: 1.0, end: 1.1).animate(_animationController),
                  child: Container(height: 80, width: 80, decoration: BoxDecoration(color: _isListening ? Colors.redAccent : const Color(0xFF00BFA5), shape: BoxShape.circle, boxShadow: [BoxShadow(color: (_isListening ? Colors.red : const Color(0xFF00BFA5)).withOpacity(0.4), blurRadius: 20, spreadRadius: 5)]), child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 40)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// الكلاسات الأخرى (LoginScreen, PaymentScreen)
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(); final _nameController = TextEditingController(); final FirebaseAuth _auth = FirebaseAuth.instance; String? _verificationId; bool _isLoading = false;
  Future<void> _verifyPhone() async { setState(() => _isLoading = true); await _auth.verifyPhoneNumber(phoneNumber: '+213${_phoneController.text.trim()}', verificationCompleted: (c) async { await _auth.signInWithCredential(c); }, verificationFailed: (e) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.message}'))); }, codeSent: (v, t) { setState(() { _verificationId = v; _isLoading = false; }); _showOtpDialog(); }, codeAutoRetrievalTimeout: (v) {}); }
  void _showOtpDialog() { final otpController = TextEditingController(); showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(title: const Text('كود التحقق'), content: TextField(controller: otpController, keyboardType: TextInputType.number), actions: [TextButton(onPressed: () async { PhoneAuthCredential c = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: otpController.text); await _auth.signInWithCredential(c); if (_auth.currentUser != null) { await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).set({'name': _nameController.text, 'phone': _auth.currentUser!.phoneNumber, 'isPaid': false}, SetOptions(merge: true)); } Navigator.pop(context); }, child: const Text('تأكيد'))])); }
  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.white, body: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.health_and_safety, size: 80, color: Color(0xFF00BFA5)), const SizedBox(height: 20), const Text("Afya DZ", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))), const SizedBox(height: 40), TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف (بدون 0)', prefixText: '+213 ', border: OutlineInputBorder())), const SizedBox(height: 20), _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _verifyPhone, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), child: const Text("دخول"))]))); }
}
class PaymentScreen extends StatelessWidget { final User user; const PaymentScreen({super.key, required this.user}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("تفعيل الحساب")), body: Center(child: Text("يرجى الدفع لتفعيل الحساب"))); } }
