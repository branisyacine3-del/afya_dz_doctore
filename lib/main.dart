import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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
        primaryColor: const Color(0xFF00BFA5), // أخضر طبي
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // خلفية رمادية فاتحة جداً
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BFA5)),
        fontFamily: 'SansSerif', // خط نظيف
      ),
      home: const AuthGate(),
    );
  }
}

// --- بوابة التحقق ---
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
    // رقم الأدمن (أنت)
    if (user.phoneNumber == "+213697443312" || user.phoneNumber == "+2130697443312") {
       return const DoctorScreen(isAdmin: true);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        bool isPaid = userData?['isPaid'] ?? false;

        if (isPaid) return const DoctorScreen(isAdmin: false);
        return PaymentScreen(user: user);
      },
    );
  }
}

// --- شاشة الطبيب المحترفة (تصميم جديد) ---
class DoctorScreen extends StatefulWidget {
  final bool isAdmin;
  const DoctorScreen({super.key, required this.isAdmin});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _statusText = "اضغط على المايكروفون للتحدث";
  final List<Map<String, String>> _messages = []; // لتخزين المحادثة
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // مفتاح Gemini
  final String _apiKey = 'AIzaSyBhZPtxFDvuH1pAMuZjJlAyu1ZESjRC9r4';

  // أنيميشن للزر
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.0,
      upperBound: 0.1,
    )..addListener(() { setState(() {}); });
    
    // رسالة ترحيبية
    _addMessage("role", "assistant", "مرحباً بك في Afya DZ 🩺\nأنا طبيبك الذكي، بماذا تشعر اليوم؟");
  }

  void _addMessage(String key, String role, String text) {
    setState(() {
      _messages.add({"role": role, "text": text});
    });
    // النزول لآخر الرسالة
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _listen() async {
    // 1. طلب الصلاحية أولاً
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _addMessage("role", "assistant", "⚠️ يرجى تفعيل صلاحية الميكروفون من إعدادات الهاتف لكي أسمعك.");
      return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize(
        onError: (val) => setState(() {
          _isListening = false;
          _statusText = "حدث خطأ، حاول مرة أخرى";
          _animationController.stop();
        }),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _statusText = "جاري الاستماع...";
          _animationController.repeat(reverse: true); // تشغيل الأنيميشن
        });
        
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              setState(() {
                _isListening = false;
                _animationController.stop();
                _animationController.reset();
              });
              if (val.recognizedWords.isNotEmpty) {
                _handleUserMessage(val.recognizedWords);
              }
            }
          },
          localeId: 'ar-DZ', // محاولة فهم اللهجة
        );
      } else {
        _addMessage("role", "assistant", "⚠️ الميكروفون غير متوفر في جهازك حالياً.");
      }
    } else {
      setState(() {
        _isListening = false;
        _animationController.stop();
        _animationController.reset();
        _statusText = "اضغط للتحدث";
      });
      _speech.stop();
    }
  }

  Future<void> _handleUserMessage(String message) async {
    _addMessage("role", "user", message);
    setState(() => _isLoading = true);

    try {
      final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
      final content = [Content.text('''
        System Instruction:
        أنت طبيب ذكي جزائري في تطبيق Afya DZ.
        1. تكلم بالدارجة الجزائرية المفهومة والمهذبة.
        2. حلل أعراض المريض: "$message".
        3. إذا الحالة بسيطة (زكام، تعب) انصحه بالراحة وسوائل.
        4. إذا الحالة خطيرة (قلب، ضيق تنفس) قله يروح للسبيطار فوراً.
        5. ردك يجب أن يكون قصيراً ومباشراً (لا تتجاوز 4 أسطر).
      ''')];
      
      final response = await model.generateContent(content);
      _addMessage("role", "assistant", response.text ?? "لم أفهم، أعد المحاولة.");
    } catch (e) {
      _addMessage("role", "assistant", "مشكلة في الإنترنت، تأكد من اتصالك.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Afya DZ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF00BFA5),
        elevation: 0,
        actions: [
          if (widget.isAdmin)
             const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.admin_panel_settings, color: Colors.white)),
        ],
      ),
      body: Column(
        children: [
          // قائمة الرسائل (الشات)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00BFA5) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15),
                        bottomLeft: isUser ? const Radius.circular(15) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(15),
                      ),
                      boxShadow: [
                        if (!isUser) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // مؤشر التحميل
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("جاري التشخيص...", style: TextStyle(color: Colors.grey)),
            ),

          // منطقة الزر السفلي
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
            ),
            child: Column(
              children: [
                Text(_statusText, style: TextStyle(color: _isListening ? Colors.red : Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                // زر المايكروفون الكبير مع الأنيميشن
                GestureDetector(
                  onTap: _listen,
                  child: ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.1).animate(_animationController),
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.redAccent : const Color(0xFF00BFA5),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : const Color(0xFF00BFA5)).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          )
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 40,
                      ),
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
}

// --- (احتفظ بشاشات تسجيل الدخول والدفع كما هي، انسخها من الكود السابق وضعها هنا) ---
// لتوفير المساحة، افترضت أنك ستنسخ كلاس LoginScreen و PaymentScreen و SlickPayWebView من الكود السابق وتضعها هنا في الأسفل.
// إذا كنت تريدني أن أعيد كتابتها كاملة أخبرني.
