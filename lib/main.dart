import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BFA5)),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const SplashHandler(),
    );
  }
}

// --- فحص هل المستخدم جديد أم قديم ---
class SplashHandler extends StatefulWidget {
  const SplashHandler({super.key});
  @override
  State<SplashHandler> createState() => _SplashHandlerState();
}

class _SplashHandlerState extends State<SplashHandler> {
  @override
  void initState() {
    super.initState();
    _checkFirstSeen();
  }

  Future<void> _checkFirstSeen() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seen = (prefs.getBool('seenIntro') ?? false);
    
    if (seen) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const IntroScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// --- شاشات الترحيب (3 لوحات) ---
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  void _onIntroEnd(context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenIntro', true);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: "طبيبك الذكي في جيبك",
          body: "تشخيص فوري ودقيق لحالتك الصحية باستخدام أحدث تقنيات الذكاء الاصطناعي.",
          image: const Icon(Icons.health_and_safety, size: 100, color: Color(0xFF00BFA5)),
          decoration: const PageDecoration(pageColor: Colors.white),
        ),
        PageViewModel(
          title: "تحدث بصوتك",
          body: "لا داعي للكتابة! اشرح أعراضك بصوتك وبالدارجة الجزائرية وسيفهمك الطبيب.",
          image: const Icon(Icons.mic, size: 100, color: Color(0xFF00BFA5)),
          decoration: const PageDecoration(pageColor: Colors.white),
        ),
        PageViewModel(
          title: "خصوصية وأمان",
          body: "بياناتك مشفرة وآمنة. ابدأ رحلة العلاج الآن مع Afya DZ.",
          image: const Icon(Icons.security, size: 100, color: Color(0xFF00BFA5)),
          decoration: const PageDecoration(pageColor: Colors.white),
        ),
      ],
      onDone: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text("تخطي", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
      next: const Icon(Icons.arrow_forward, color: Color(0xFF00BFA5)),
      done: const Text("ابدأ", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
      dotsDecorator: const DotsDecorator(activeColor: Color(0xFF00BFA5)),
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
    if (user.phoneNumber == "+213697443312" || user.phoneNumber == "+2130697443312") {
      // هنا نمرر اسم افتراضي للأدمن
      return const DoctorScreen(isAdmin: true, userName: "Admin Yacine"); 
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        
        // جلب الاسم الحقيقي للمستخدم
        String userName = userData?['name'] ?? "المريض";

        if (userData?['isPaid'] ?? false) return DoctorScreen(isAdmin: false, userName: userName);
        return PaymentScreen(user: user);
      },
    );
  }
}

// --- شاشة تسجيل الدخول المحسنة ---
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(); 
  final _nameController = TextEditingController(); 
  final FirebaseAuth _auth = FirebaseAuth.instance; 
  bool _isLoading = false;

  Future<void> _verifyPhone() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ملء جميع الحقول")));
      return;
    }
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: '+213${_phoneController.text.trim()}',
      verificationCompleted: (c) async { await _auth.signInWithCredential(c); },
      verificationFailed: (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.message}')));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        // الانتقال لصفحة OTP الكاملة
        Navigator.push(context, MaterialPageRoute(builder: (_) => OTPScreen(
          verificationId: verificationId, 
          name: _nameController.text,
          phone: _phoneController.text
        )));
      },
      codeAutoRetrievalTimeout: (v) {},
    );
  }

  @override 
  Widget build(BuildContext context) { 
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/logo.png', height: 100, errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 100, color: Color(0xFF00BFA5))), 
              const SizedBox(height: 20),
              const Text("مرحباً بك في Afya DZ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
              const Text("سجل دخولك لبدء التشخيص", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController, 
                decoration: InputDecoration(
                  labelText: 'الاسم الكامل', 
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50]
                )
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController, 
                keyboardType: TextInputType.phone, 
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف (بدون 0)', 
                  prefixText: '+213 ',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50]
                )
              ),
              const SizedBox(height: 30),
              _isLoading ? const CircularProgressIndicator() : ElevatedButton(
                onPressed: _verifyPhone, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5), 
                  foregroundColor: Colors.white, 
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ), 
                child: const Text("إرسال رمز التحقق", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ),
      ),
    ); 
  }
}

// --- شاشة OTP الكاملة (الجديدة) ---
class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String name;
  final String phone;
  const OTPScreen({super.key, required this.verificationId, required this.name, required this.phone});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _start = 60;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (_start == 0) {
        setState(() { timer.cancel(); });
      } else {
        setState(() { _start--; });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submitCode() async {
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: widget.verificationId, smsCode: _otpController.text);
      await _auth.signInWithCredential(credential);
      if (_auth.currentUser != null) {
          // حفظ الاسم في قاعدة البيانات
          await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).set({
            'name': widget.name, 
            'phone': _auth.currentUser!.phoneNumber, 
            'isPaid': false,
            'joinedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          // الرجوع للشاشة الرئيسية (التي ستصبح شاشة الطبيب تلقائياً)
          Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الكود غير صحيح")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.black)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("أدخل رمز التحقق", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text("تم إرسال الرمز إلى الرقم +213${widget.phone}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: "______",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Center(child: Text(_start > 0 ? "إعادة الإرسال خلال $_start ثانية" : "يمكنك إعادة الإرسال الآن", style: const TextStyle(color: Color(0xFF00BFA5)))),
            const Spacer(),
            _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(
              onPressed: _submitCode,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5), 
                  foregroundColor: Colors.white, 
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: const Text("تأكيد الدخول", style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- شاشة الطبيب (تصميم Push-to-Talk + Personalization) ---
class DoctorScreen extends StatefulWidget {
  final bool isAdmin;
  final String userName; // اسم المريض لتخصيص الرد
  const DoctorScreen({super.key, required this.isAdmin, required this.userName});
  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _statusText = "اضغط مطولاً للتحدث";
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // 🔴🔴 مفتاحك هنا 🔴🔴
  final String _apiKey = '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';

  @override
  void initState() {
    super.initState();
    // رسالة ترحيبية بالاسم
    _addMessage("role", "assistant", "أهلاً بك يا ${widget.userName} 🩺\nأنا طبيبك الذكي، مما تشكو اليوم؟");
  }

  void _addMessage(String key, String role, String text) {
    setState(() { _messages.add({"role": role, "text": text}); });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // بدء الاستماع (عند الضغط)
  void _startListening() async {
    bool available = await _speech.initialize(
      onError: (val) => setState(() { _isListening = false; _statusText = "خطأ"; }),
    );
    if (available) {
      setState(() { _isListening = true; _statusText = "جاري الاستماع..."; });
      _speech.listen(
        onResult: (val) {
          // لا نفعل شيئاً هنا، ننتظر رفع الإصبع للإرسال
        },
        localeId: 'ar-DZ',
        pauseFor: const Duration(seconds: 10), // لا تتوقف تلقائياً
      );
    }
  }

  // إيقاف الاستماع والإرسال (عند رفع الإصبع)
  void _stopListening() async {
    setState(() { _isListening = false; _statusText = "اضغط مطولاً للتحدث"; });
    await _speech.stop();
    
    // الانتظار قليلاً للتأكد من التقاط آخر كلمة
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (_speech.lastRecognizedWords.isNotEmpty) {
      _handleUserMessage(_speech.lastRecognizedWords);
    }
  }

  Future<void> _handleUserMessage(String message) async {
    _addMessage("role", "user", message);
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile', 
          'messages': [
            {
              'role': 'system', 
              'content': 'أنت طبيب ذكي جزائري في تطبيق Afya DZ. اسم المريض هو "${widget.userName}". خاطبه باسمه دائماً. تكلم بالدارجة الجزائرية. حلل الأعراض باختصار وانصح المريض.'
            },
            {'role': 'user', 'content': message}
          ],
          'temperature': 0.6,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];
        _addMessage("role", "assistant", reply);
      } else {
        _addMessage("role", "assistant", "خطأ اتصال: ${response.statusCode}");
      }
    } catch (e) {
      _addMessage("role", "assistant", "خطأ تطبيق: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Afya DZ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        centerTitle: true, 
        backgroundColor: const Color(0xFF00BFA5),
        elevation: 0,
      ),
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
                    margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00BFA5) : Colors.grey[200], 
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                      ),
                    ),
                    child: Text(msg['text']!, style: TextStyle(fontSize: 16, color: isUser ? Colors.white : Colors.black87)),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) 
             const Padding(padding: EdgeInsets.all(8.0), child: Text("جاري الكتابة...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
          
          // منطقة المايكروفون الجديدة (بدون خلفية بيضاء كبيرة)
          Padding(
            padding: const EdgeInsets.only(bottom: 30, top: 10),
            child: Column(
              children: [
                GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopListening(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: _isListening ? 90 : 70,
                    width: _isListening ? 90 : 70,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : const Color(0xFF00BFA5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.red : const Color(0xFF00BFA5)).withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 35),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_statusText, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// شاشة الدفع (SlickPay)
class PaymentScreen extends StatelessWidget { final User user; const PaymentScreen({super.key, required this.user}); final String slickPayLink = "https://slick-pay.com/invoice/payment/eyJpdiI6IlFVZzVxTEljNlk3SmRZd0xwc0h3dmc9PSIsInZhbHVlIjoiWHFDY3pBaFJWWGFXTFNkcUtCeWs0TG54S25Qa2tlM3pqRDFScWs3K0xKRT0iLCJtYWMiOiJlM2U4ZmVlNDgzYTIxYmY1NmQ3NDJmZTliOTljNjE4N2M2ZWQ0M2JhMjg3YmNiYzU1YjYxZTlmNTZjYTIyMzA3IiwidGFnIjoiIn0=/merchant"; @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("تفعيل الحساب")), body: Center(child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SlickPayWebView(url: slickPayLink))), child: const Text("دفع الاشتراك")))); } }
class SlickPayWebView extends StatelessWidget { final String url; const SlickPayWebView({super.key, required this.url}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("الدفع")), body: WebViewWidget(controller: WebViewController()..loadRequest(Uri.parse(url)))); } }
 
