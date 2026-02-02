import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

// --- نقطة البداية الجديدة ---
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}

// --- شاشة الفحص والإقلاع (لحل مشكلة الشاشة البيضاء) ---
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  // متغير لتخزين رسالة الخطأ إن وجدت
  String? _errorMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      // محاولة الاتصال بفايربيز
      await Firebase.initializeApp();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // إذا حدث خطأ، سنعرضه على الشاشة بدلاً من التجميد
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      // شاشة الخطأ (بدل الشاشة البيضاء)
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  const Text("حدث خطأ أثناء التشغيل:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  const SizedBox(height: 30),
                  const Text("تأكد من ملف google-services.json واتصال الإنترنت"),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      // شاشة التحميل (جاري الاتصال...)
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("جاري تهيئة العيادة الذكية..."),
              ],
            ),
          ),
        ),
      );
    }

    // إذا نجح الاتصال، ننتقل للتطبيق الرئيسي
    return const AfyaDZApp();
  }
}

// --- التطبيق الرئيسي (كما كان سابقاً) ---
class AfyaDZApp extends StatelessWidget {
  const AfyaDZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Afya DZ - طبيبك الذكي',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
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
    if (user.phoneNumber == "+213697443312" || user.phoneNumber == "+2130697443312") {
       FirebaseFirestore.instance.collection('users').doc(user.uid).set({
         'phone': user.phoneNumber,
         'isPaid': true,
         'isAdmin': true,
       }, SetOptions(merge: true));
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

// --- باقي الشاشات (Login, Payment, Doctor) ---
// (تأكد من أنك نسخت باقي الكود السابق الخاص بالشاشات هنا، 
// أو إذا كنت تستخدم ملف واحد، انسخ كلاسات LoginScreen و PaymentScreen و DoctorScreen وضعها هنا في الأسفل)

// --- يتبع: شاشة تسجيل الدخول ---
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.health_and_safety, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            const Text("Afya DZ", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const Text("سجل الدخول لبدء التشخيص", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف (بدون 0)', prefixText: '+213 ', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _verifyPhone, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text("دخول")),
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
              ElevatedButton.icon(icon: const Icon(Icons.credit_card), label: const Text("دفع بالبطاقة (SlickPay)"), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SlickPayWebView(url: slickPayLink)))),
              const SizedBox(height: 20),
              const SelectableText("CCP: 0028939081 Clé 97"),
              const SelectableText("RIP: 00799999002893908197"),
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
    return Scaffold(appBar: AppBar(title: const Text("الدفع")), body: WebViewWidget(controller: controller));
  }
}

// --- شاشة الطبيب ---
class DoctorScreen extends StatefulWidget {
  final bool isAdmin;
  const DoctorScreen({super.key, required this.isAdmin});
  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = "اضغط وتكلم...";
  String _aiResponse = "";
  bool _isLoadingResponse = false;
  final String _apiKey = 'AIzaSyBhZPtxFDvuH1pAMuZjJlAyu1ZESjRC9r4';

  Future<void> _listen() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) => setState(() => _text = val.recognizedWords), localeId: 'ar-DZ');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_text.isNotEmpty) _getMedicalAdvice(_text);
    }
  }

  Future<void> _getMedicalAdvice(String prompt) async {
    setState(() => _isLoadingResponse = true);
    try {
      final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
      final response = await model.generateContent([Content.text('أنت طبيب جزائري. المريض يقول: $prompt')]);
      setState(() => _aiResponse = response.text ?? "لم أفهم");
    } catch (e) {
      setState(() => _aiResponse = "خطأ في الاتصال");
    } finally {
      setState(() => _isLoadingResponse = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("طبيبك الذكي")),
      body: Column(
        children: [
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [Text(_text, style: const TextStyle(fontSize: 18)), const SizedBox(height: 20), if (_isLoadingResponse) const CircularProgressIndicator() else Text(_aiResponse, style: const TextStyle(fontSize: 18, color: Colors.teal))]))),
          FloatingActionButton.large(onPressed: _listen, backgroundColor: _isListening ? Colors.red : Colors.teal, child: Icon(_isListening ? Icons.mic_off : Icons.mic)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
