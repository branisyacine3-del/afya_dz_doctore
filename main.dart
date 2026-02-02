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
      title: 'Afya DZ - طبيبك الذكي',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        fontFamily: 'Roboto', // يمكنك تغيير الخط لاحقاً
      ),
      home: const AuthGate(),
    );
  }
}

// بوابة التحقق: توجه المستخدم حسب حالته
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
        // المستخدم مسجل، نتحقق هل دفع الاشتراك أم لا
        return PaymentCheckGate(user: snapshot.data!);
      },
    );
  }
}

// التحقق من الدفع في قاعدة البيانات
class PaymentCheckGate extends StatelessWidget {
  final User user;
  const PaymentCheckGate({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // الرقم السحري للأدمن (أنت)
    if (user.phoneNumber == "+213697443312" || user.phoneNumber == "+2130697443312") {
       // تحديث صلاحيات الأدمن تلقائياً في الخلفية
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

        if (isPaid) {
          return const DoctorScreen(isAdmin: false);
        } else {
          return PaymentScreen(user: user);
        }
      },
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
      phoneNumber: '+213${_phoneController.text.trim()}', // إضافة كود الجزائر
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
              // حفظ الاسم في قاعدة البيانات
              if (_auth.currentUser != null) {
                 await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).set({
                   'name': _nameController.text,
                   'phone': _auth.currentUser!.phoneNumber,
                   'isPaid': false, // افتراضيا لم يدفع
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف (بدون 0)', prefixText: '+213 ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verifyPhone,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text("دخول"),
                  ),
          ],
        ),
      ),
    );
  }
}

// --- شاشة الدفع (Paywall) ---
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "لتفعيل الطبيب الصوتي، يجب دفع اشتراك رمزي: 500 دج",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // خيار 1: SlickPay
              ElevatedButton.icon(
                icon: const Icon(Icons.credit_card),
                label: const Text("دفع بالبطاقة الذهبية / CIB (فوري)"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SlickPayWebView(url: slickPayLink)));
                },
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // خيار 2: BaridiMob / CCP
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: const [
                    Text("أو الدفع اليدوي عبر بريدي موب:", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    SelectableText("RIP: 00799999002893908197", style: TextStyle(fontSize: 16)),
                    SelectableText("CCP: 0028939081 Clé 97"),
                    SizedBox(height: 10),
                    Text("بعد الدفع، يرجى الاتصال بالأدمن للتفعيل.", style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// متصفح الدفع الداخلي
class SlickPayWebView extends StatelessWidget {
  final String url;
  const SlickPayWebView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));

    return Scaffold(
      appBar: AppBar(title: const Text("الدفع الآمن")),
      body: WebViewWidget(controller: controller),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text("أكملت الدفع"),
        icon: const Icon(Icons.check),
        onPressed: () {
          // هنا يمكن إرسال طلب تفعيل للأدمن
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم إرسال طلب التفعيل. سيتم تفعيل حسابك قريباً.")),
          );
          Navigator.pop(context);
        },
      ),
    );
  }
}

// --- الشاشة الرئيسية (الطبيب الصوتي) ---
class DoctorScreen extends StatefulWidget {
  final bool isAdmin;
  const DoctorScreen({super.key, required this.isAdmin});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = "اضغط على الميكروفون وتكلم بالدارجة...";
  String _aiResponse = "";
  bool _isLoadingResponse = false;

  // مفتاح Gemini الخاص بك
  final String _apiKey = 'AIzaSyBhZPtxFDvuH1pAMuZjJlAyu1ZESjRC9r4';

  Future<void> _listen() async {
    // طلب الصلاحيات
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;

    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
          }),
          localeId: 'ar-DZ', // محاولة التقاط اللهجة
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_text.isNotEmpty && _text != "اضغط على الميكروفون وتكلم بالدارجة...") {
        _getMedicalAdvice(_text);
      }
    }
  }

  Future<void> _getMedicalAdvice(String userPrompt) async {
    setState(() => _isLoadingResponse = true);
    
    try {
      final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
      final content = [Content.text('''
        System Instruction:
        أنت طبيب ذكي جزائري ومساعد صحي في تطبيق "Afya DZ".
        لغتك: دارجة جزائرية مفهومة ومهذبة.
        دورك: طمأنة المريض، وتحليل الأعراض التي يذكرها، وإعطاء نصائح أولية.
        تحذير: إذا كانت الحالة خطيرة (قلب، تنفس، نزيف) اطلب منه الذهاب للاستعجالات فوراً.
        
        المريض يقول: "$userPrompt"
      ''')];
      
      final response = await model.generateContent(content);
      setState(() {
        _aiResponse = response.text ?? "لم أتمكن من الفهم، حاول مرة أخرى.";
      });
    } catch (e) {
      setState(() => _aiResponse = "حدث خطأ في الاتصال، تأكد من الإنترنت.");
    } finally {
      setState(() => _isLoadingResponse = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Afya DZ - الطبيب"),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                // هنا تفتح لوحة التحكم لتفعيل المستخدمين يدوياً إذا لم ينجح الدفع التلقائي
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("مرحباً بك يا دكتور (الأدمن)")));
              },
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // فقاعة المريض
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(15)),
                    child: Text(_text, style: const TextStyle(fontSize: 18), textAlign: TextAlign.right),
                  ),
                  const SizedBox(height: 20),
                  // فقاعة الطبيب الذكي
                  if (_isLoadingResponse)
                    const CircularProgressIndicator()
                  else if (_aiResponse.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.teal[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.teal)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.medical_services, color: Colors.teal), SizedBox(width: 10), Text("الطبيب:", style: TextStyle(fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 10),
                          Text(_aiResponse, style: const TextStyle(fontSize: 18, height: 1.5), textAlign: TextAlign.right, textDirection: TextDirection.rtl),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // زر الميكروفون الكبير
          Container(
            padding: const EdgeInsets.only(bottom: 30),
            child: FloatingActionButton.large(
              onPressed: _listen,
              backgroundColor: _isListening ? Colors.red : Colors.teal,
              child: Icon(_isListening ? Icons.mic_off : Icons.mic, size: 40, color: Colors.white),
            ),
          ),
          const Text("اضغط لتتحدث", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
