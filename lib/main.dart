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
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // خلفية رمادية فاتحة
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BFA5)),
        fontFamily: 'Roboto',
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
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
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

        if (isPaid) {
          return const DoctorScreen(isAdmin: false);
        } else {
          return PaymentScreen(user: user);
        }
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
  String _statusText = "اضغط للتحدث";
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late AnimationController _animationController;

  // مفتاح Gemini API
  final String _apiKey = 'AIzaSyBhZPtxFDvuH1pAMuZjJlAyu1ZESjRC9r4';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.0,
      upperBound: 0.1,
    )..addListener(() { setState(() {}); });
    
    _addMessage("role", "assistant", "مرحباً بك في Afya DZ 🩺\nأنا طبيبك الذكي، بماذا تشعر اليوم؟");
  }

  void _addMessage(String key, String role, String text) {
    setState(() {
      _messages.add({"role": role, "text": text});
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _listen() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _addMessage("role", "assistant", "⚠️ يرجى تفعيل صلاحية الميكروفون.");
      return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize(
        onError: (val) => setState(() {
          _isListening = false;
          _statusText = "خطأ، حاول مرة أخرى";
          _animationController.stop();
        }),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _statusText = "جاري الاستماع...";
          _animationController.repeat(reverse: true);
        });
        
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              setState(() {
                _isListening = false;
                _animationController.stop();
                _animationController.reset();
                _statusText = "اضغط للتحدث";
              });
              if (val.recognizedWords.isNotEmpty) {
                _handleUserMessage(val.recognizedWords);
              }
            }
          },
          localeId: 'ar-DZ',
        );
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
        تكلم بالدارجة الجزائرية المفهومة.
        حلل الأعراض التالية: "$message"
        إذا كانت خطيرة اطلب الذهاب للمستشفى.
      ''')];
      
      final response = await model.generateContent(content);
      _addMessage("role", "assistant", response.text ?? "لم أفهم، أعد المحاولة.");
    } catch (e) {
      _addMessage("role", "assistant", "تأكد من اتصال الإنترنت.");
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
        actions: [
          if (widget.isAdmin)
             const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.security, color: Colors.white)),
        ],
      ),
      body: Column(
        children: [
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
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(8.0), child: Text("جاري التشخيص...", style: TextStyle(color: Colors.grey))),

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

// --- شاشة تسجيل الدخول ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  bool _isLoading = false;

  Future<void> _verifyPhone() async {
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: '+213${_phoneController.text.trim()}',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.message}')));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isLoading = false;
        });
        _showOtpDialog();
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _showOtpDialog() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('أدخل كود التحقق'),
        content: TextField(controller: otpController, keyboardType: TextInputType.number),
        actions: [
          TextButton(
            onPressed: () async {
              PhoneAuthCredential credential = PhoneAuthProvider.credential(
                  verificationId: _verificationId!, smsCode: otpController.text);
              await _auth.signInWithCredential(credential);
              if (_auth.currentUser != null) {
                 await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).set({
                   'name': _nameController.text,
                   'phone': _auth.currentUser!.phoneNumber,
                   'isPaid': false,
                   'joinedAt': FieldValue.serverTimestamp(),
                 }, SetOptions(merge: true));
              }
              Navigator.pop(context);
            },
            child: const Text('تأكيد'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.health_and_safety, size: 80, color: Color(0xFF00BFA5)),
            const SizedBox(height: 20),
            const Text("Afya DZ", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
            const Text("سجل الدخول لبدء التشخيص", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف (بدون 0)', prefixText: '+213 ', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(
              onPressed: _verifyPhone,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              child: const Text("دخول"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- شاشة الدفع ---
class PaymentScreen extends StatelessWidget {
  final User user;
  const PaymentScreen({super.key, required this.user});
  final String slickPayLink = "https://slick-pay.com/invoice/payment/eyJpdiI6IlFVZzVxTEljNlk3SmRZd0xwc0h3dmc9PSIsInZhbHVlIjoiWHFDY3pBaFJWWGFXTFNkcUtCeWs0TG54S25Qa2tlM3pqRDFScWs3K0xKRT0iLCJtYWMiOiJlM2U4ZmVlNDgzYTIxYmY1NmQ3NDJmZTliOTljNjE4N2M2ZWQ0M2JhMjg3YmNiYzU1YjYxZTlmNTZjYTIyMzA3IiwidGFnIjoiIn0=/merchant";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تفعيل الحساب")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text("ادفع 500 دج لتفعيل الطبيب الصوتي", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.credit_card),
                label: const Text("دفع بالبطاقة (SlickPay)"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SlickPayWebView(url: slickPayLink))),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                color: Colors.grey[100],
                child: Column(children: const [
                  Text("أو الدفع اليدوي:", style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText("CCP: 0028939081 Clé 97"),
                  SelectableText("RIP: 00799999002893908197"),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SlickPayWebView extends StatelessWidget {
  final String url;
  const SlickPayWebView({super.key, required this.url});
  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse(url));
    return Scaffold(appBar: AppBar(title: const Text("الدفع الآمن")), body: WebViewWidget(controller: controller));
  }
}
