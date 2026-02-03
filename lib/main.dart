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
      title: 'عافية',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00BFA5),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BFA5)),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

// --- 1. شاشة البداية (Splash Screen) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), _navigateNext);
  }

  void _navigateNext() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seenIntro = (prefs.getBool('seenIntro') ?? false);
    
    if (mounted) {
      if (!seenIntro) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const IntroScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00BFA5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset('logo.png', height: 100, width: 100, fit: BoxFit.cover,
                  errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 80, color: Color(0xFF00BFA5)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("عافية", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            const Text("رعايتك الصحية.. بلمسة ذكية", style: TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// --- 2. الشاشات التعريفية (Intro) ---
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
          title: "طبيبك الخبير",
          body: "تشخيص دقيق وخبرة طبية عالية، معك في أي وقت.",
          image: Image.asset('logo.png', height: 120, errorBuilder: (c,e,s)=>const Icon(Icons.medical_services, size: 100, color: Color(0xFF00BFA5))),
          decoration: const PageDecoration(pageColor: Colors.white),
        ),
        PageViewModel(
          title: "تحدث بحرية",
          body: "اشرح أعراضك بصوتك، وسأفهمك بدقة وأعطيك العلاج المناسب.",
          image: const Icon(Icons.mic, size: 100, color: Color(0xFF00BFA5)),
          decoration: const PageDecoration(pageColor: Colors.white),
        ),
        PageViewModel(
          title: "مجاني وآمن",
          body: "سجل حسابك الآن وابدأ رحلة العلاج.",
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

// --- 3. بوابة التحقق ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const EmailAuthScreen();
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? "المريض";
        return DoctorScreen(userName: userName);
      },
    );
  }
}

// --- 4. شاشة التسجيل والدخول (الإيميل) ---
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});
  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  bool isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ملء جميع الحقول")));
      return;
    }
    if (!isLogin && _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى كتابة الاسم")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential;
      if (isLogin) {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'isPaid': false,
        });
      }
    } on FirebaseAuthException catch (e) {
      String message = "حدث خطأ";
      if (e.code == 'user-not-found') message = "لا يوجد حساب بهذا الإيميل";
      else if (e.code == 'wrong-password') message = "كلمة المرور خاطئة";
      else if (e.code == 'email-already-in-use') message = "الإيميل مسجل مسبقاً";
      else if (e.code == 'weak-password') message = "كلمة المرور ضعيفة";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Image.asset('logo.png', height: 100, errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 100, color: Color(0xFF00BFA5))),
            const SizedBox(height: 20),
            Text(isLogin ? "تسجيل الدخول" : "إنشاء حساب جديد", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
            const SizedBox(height: 40),
            if (!isLogin)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'الاسم الكامل', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: const Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 30),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(isLogin ? "دخول" : "تسجيل", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? "ليس لديك حساب؟ سجل الآن" : "لديك حساب؟ سجل الدخول", style: const TextStyle(color: Color(0xFF00BFA5))),
            )
          ],
        ),
      ),
    );
  }
}

// --- 5. شاشة الطبيب (النسخة النهائية المطورة) ---
class DoctorScreen extends StatefulWidget {
  final String userName; 
  const DoctorScreen({super.key, required this.userName});
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
  String _currentWords = ""; // لتخزين الكلام أثناء الضغط

  // 🔴🔴 ضع مفتاح Groq هنا 🔴🔴
  final String _apiKey = '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';

  @override
  void initState() {
    super.initState();
    _addMessage("role", "assistant", "أهلاً بك يا ${widget.userName} 👋\nأنا طبيبك الخبير. أشعرني بما يؤلمك، وسأقوم بتشخيص حالتك بدقة.");
  }

  void _addMessage(String key, String role, String text) {
    setState(() { _messages.add({"role": role, "text": text}); });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // دالة الاستماع المحسنة (لا تتوقف حتى ترفع إصبعك)
  void _startListening() async {
    bool available = await _speech.initialize(onError: (val) => setState(() { _isListening = false; }));
    if (available) {
      setState(() { _isListening = true; _statusText = "جاري الاستماع... (واصل الكلام)"; _currentWords = ""; });
      _speech.listen(
        localeId: 'ar-DZ', // يمكن تغييرها لـ ar-SA لو أردت فصحى أفضل في السماع
        pauseFor: const Duration(seconds: 30), // ✅ الانتظار طويلاً حتى لو سكت المريض
        onResult: (val) {
          setState(() {
            _currentWords = val.recognizedWords;
          });
        }
      );
    }
  }

  // دالة التوقف والإرسال (عند رفع الإصبع فقط)
  void _stopListening() async {
    setState(() { _isListening = false; _statusText = "اضغط مطولاً للتحدث"; });
    await _speech.stop();
    
    // إرسال ما تم التقاطه
    if (_currentWords.trim().isNotEmpty) {
      _handleUserMessage(_currentWords);
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
              'content': '''
                أنت طبيب خبير جداً (خبرة 100 سنة) في تطبيق "عافية". اسم المريض: "${widget.userName}".

                القواعد الصارمة (System Rules):
                1. 🛑 التخصص: إذا سأل المريض عن "سيارات"، "رياضة"، "سياسة"، أو أي شيء غير طبي، ارفض الإجابة بلطف وقل: "أنا طبيب فقط، اسألني عن صحتك".
                2. 🗣️ اللغة: تحدث باللغة العربية الفصحى (الواضحة والودودة) ليفهمك الجميع بدقة، وتجنب خلط اللهجات.
                3. 🩺 التشخيص العميق:
                   - إذا لم يذكر المريض عمره أو تاريخه المرضي، اسأله أولاً.
                   - حلل الأعراض بدقة طبية عالية.
                   - اعطِ نصائح منزلية (أعشاب، راحة، تغذية).
                   - اقترح أدوية متوفرة في الصيدلية (OTC) بالاسم العلمي، وحدد الجرعة (مثلاً: حبة كل 8 ساعات بعد الأكل).
                4. ⚠️ الأمان: دائماً ذكر المريض بزيارة المستشفى في الحالات الخطيرة.
                5. التنسيق: اجعل كلامك مرتباً في نقاط ومن اليمين لليسار.
              '''
            },
            {'role': 'user', 'content': message}
          ],
          'temperature': 0.5, // تقليل العشوائية ليكون دقيقاً كطبيب
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];
        _addMessage("role", "assistant", reply);
      } else {
        _addMessage("role", "assistant", "حدث خطأ في الاتصال، حاول مرة أخرى.");
      }
    } catch (e) {
      _addMessage("role", "assistant", "خطأ في التطبيق: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("عافية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        centerTitle: true, 
        backgroundColor: const Color(0xFF00BFA5),
        elevation: 0,
        actions: [
          IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout, color: Colors.white))
        ],
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
                    margin: const EdgeInsets.symmetric(vertical: 5), 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00BFA5) : Colors.white, 
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                      ),
                      boxShadow: [
                        if (!isUser) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        msg['text']!, 
                        style: TextStyle(fontSize: 16, color: isUser ? Colors.white : Colors.black87, height: 1.4),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: Text("الطبيب يكتب التشخيص...", style: TextStyle(color: Colors.grey))),
          
          Padding(
            padding: const EdgeInsets.only(bottom: 30, top: 10),
            child: Column(
              children: [
                GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopListening(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    // ✅ تم تكبير الزر هنا كما طلبت
                    height: _isListening ? 110 : 90, 
                    width: _isListening ? 110 : 90,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : const Color(0xFF00BFA5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: (_isListening ? Colors.red : const Color(0xFF00BFA5)).withOpacity(0.4), blurRadius: 15, spreadRadius: 2)
                      ],
                    ),
                    child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 45), // تكبير الأيقونة أيضاً
                  ),
                ),
                const SizedBox(height: 10),
                Text(_statusText, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class PaymentScreen extends StatelessWidget { final User user; const PaymentScreen({super.key, required this.user}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("تفعيل الحساب")), body: Center(child: Text("يرجى الدفع"))); } }
