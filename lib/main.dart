import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // تأكد من إضافة هذه المكتبة في pubspec.yaml

// ==========================================
// 1. إعدادات التطبيق والثيمات (Theme Config)
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // تثبيت الوضع العمودي فقط
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // تلوين شريط الحالة
  SystemChrome.setSystemUIOverlayStyle(const SystemUIOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const AfyaDZApp());
}

class AfyaDZApp extends StatelessWidget {
  const AfyaDZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'عافية - Afya DZ',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00BFA5),
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA5),
          primary: const Color(0xFF00BFA5),
          secondary: const Color(0xFF00897B),
          surface: const Color(0xFFFFFFFF),
          error: const Color(0xFFE53935),
        ),
        fontFamily: 'Roboto', // يفضل استبداله بـ Cairo إذا أمكن
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF00BFA5), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BFA5),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 2. شاشة البداية المتطورة (Advanced Splash)
// ==========================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    
    _controller.forward();
    Timer(const Duration(seconds: 4), _checkSession);
  }

  void _checkSession() async {
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))]),
                    child: ClipOval(
                      child: Image.asset('logo.png', height: 120, width: 120, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 100, color: Color(0xFF00BFA5))),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text("عافية", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text("رعايتك الصحية.. بلمسة ذكية", style: TextStyle(fontSize: 16, color: Colors.white70)),
              ),
              const SizedBox(height: 60),
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. الشاشات التعريفية (Onboarding)
// ==========================================

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  void _onIntroEnd(context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenIntro', true);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  @override
  Widget build(BuildContext context) {
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700, color: Color(0xFF00BFA5)),
      bodyTextStyle: TextStyle(fontSize: 18.0, color: Colors.black54, height: 1.5),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      allowImplicitScrolling: true,
      autoScrollDuration: 3000,
      pages: [
        PageViewModel(
          title: "طبيبك الشخصي",
          body: "تطبيق عافية يوفر لك تشخيصاً طبياً دقيقاً باستخدام أحدث تقنيات الذكاء الاصطناعي.",
          image: _buildImage(Icons.medical_services_outlined),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "يفهم لغتك",
          body: "تحدث بالدارجة الجزائرية أو اكتب أعراضك، وسنقوم بتحليل حالتك فوراً.",
          image: _buildImage(Icons.mic_external_on_outlined),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "وصفات دقيقة",
          body: "احصل على أسماء الأدوية العلمية، الجرعات، والنصائح المنزلية في ثوانٍ.",
          image: _buildImage(Icons.receipt_long_outlined),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text("تخطي", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
      next: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF00BFA5)),
      done: const Text("ابدأ الآن", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        color: Color(0xFFBDBDBD),
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25.0))),
        activeColor: Color(0xFF00BFA5),
      ),
    );
  }

  Widget _buildImage(IconData icon) {
    return Container(
      width: 200, height: 200,
      decoration: BoxDecoration(color: const Color(0xFFE0F2F1), shape: BoxShape.circle),
      child: Icon(icon, size: 100, color: const Color(0xFF00BFA5)),
    );
  }
}

// ==========================================
// 4. نظام التوجيه (Auth Gate)
// ==========================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // حالة التحميل
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // إذا كان المستخدم مسجلاً
        if (snapshot.hasData) {
          return UserDataLoader(user: snapshot.data!);
        }
        // إذا لم يكن مسجلاً
        return const AuthScreen();
      },
    );
  }
}

class UserDataLoader extends StatelessWidget {
  final User user;
  const UserDataLoader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        // جلب البيانات أو استخدام قيم افتراضية
        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? "المريض";
        
        return DoctorScreen(userName: userName);
      },
    );
  }
}

// ==========================================
// 5. شاشة المصادقة الذكية (Login & Register)
// ==========================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // دالة التحقق من صحة البريد
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'البريد الإلكتروني مطلوب';
    if (!value.contains('@') || !value.contains('.')) return 'يرجى إدخال بريد صحيح';
    return null;
  }

  // دالة التحقق من كلمة المرور
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'كلمة المرور مطلوبة';
    if (value.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isLoading = true; _errorMessage = null; });
    
    try {
      if (isLogin) {
        // محاولة تسجيل الدخول
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // إنشاء حساب جديد
        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // حفظ الاسم في قاعدة البيانات
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        // ترجمة الأخطاء لرسائل ودودة ومفهومة
        if (e.code == 'user-not-found') {
          _errorMessage = 'هذا الحساب غير موجود. هل تود إنشاء حساب جديد؟';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'كلمة المرور غير صحيحة. حاول مرة أخرى.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'هذا البريد مسجل مسبقاً. حاول تسجيل الدخول.';
        } else if (e.code == 'network-request-failed') {
          _errorMessage = 'يرجى التحقق من اتصال الإنترنت.';
        } else {
          _errorMessage = 'حدث خطأ: ${e.message}';
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Hero(
                  tag: 'logo',
                  child: Image.asset('logo.png', height: 100, errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 80, color: Color(0xFF00BFA5))),
                ),
                const SizedBox(height: 30),
                Text(
                  isLogin ? "مرحباً بعودتك" : "انشاء حساب جديد",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5)),
                ),
                const SizedBox(height: 10),
                Text(
                  isLogin ? "أدخل بياناتك للمتابعة" : "انضم لمجتمع عافية وابدأ التشخيص",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 40),
                
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red[200]!)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                    ]),
                  ),

                if (!isLogin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: TextFormField(
                      controller: _nameController,
                      validator: (v) => v!.isEmpty ? 'الاسم مطلوب' : null,
                      decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
                    ),
                  ),

                TextFormField(
                  controller: _emailController,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  validator: _validatePassword,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 30),

                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text(isLogin ? "تسجيل الدخول" : "إنشاء حساب"),
                      ),
                
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isLogin ? "ليس لديك حساب؟" : "لديك حساب بالفعل؟"),
                    TextButton(
                      onPressed: () => setState(() { isLogin = !isLogin; _errorMessage = null; }),
                      child: Text(isLogin ? "سجل الآن" : "دخول", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 6. شاشة الطبيب الذكي (Core Engine)
// ==========================================

class DoctorScreen extends StatefulWidget {
  final String userName;
  const DoctorScreen({super.key, required this.userName});
  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> with WidgetsBindingObserver {
  // ---------------- المتغيرات ----------------
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  
  bool _isListening = false;
  bool _isLoading = false;
  bool _isSpeechInitialized = false;
  String _inputHint = "اكتب أعراضك أو اضغط للتحدث...";
  
  // 🔴🔴 مفتاح API (يجب حمايته في بيئة الإنتاج) 🔴🔴
  // استبدل هذا بالمفتاح الخاص بك
  final String _apiKey = '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'; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
    _addSystemMessage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  // تهيئة المايكروفون عند البدء
  void _initSpeech() async {
    try {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _isSpeechInitialized = await _speech.initialize(
          onError: (e) => print('Speech Error: $e'),
          onStatus: (s) => print('Speech Status: $s'),
        );
        setState(() {});
      }
    } catch (e) {
      print("خطأ في تهيئة الصوت: $e");
    }
  }

  // رسالة الترحيب
  void _addSystemMessage() {
    setState(() {
      _messages.add({
        "role": "assistant",
        "text": "أهلاً بك يا ${widget.userName} 👋.\nأنا طبيبك المقيم في تطبيق عافية.\n\nيمكنك التحدث معي بالدارجة أو العربية الفصحى. صف لي بماذا تشعر، وسأقوم بتحليل الأعراض وكتابة الوصفة المناسبة.\n\n*اضغط على المايكروفون للتحدث أو اكتب في الأسفل.*"
      });
    });
  }

  // إضافة رسالة للقائمة والنزول للأسفل
  void _addMessage(String role, String text) {
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

  // مسح المحادثة
  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تشخيص جديد"),
        content: const Text("هل تريد مسح المحادثة الحالية والبدء من جديد؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            setState(() {
              _messages.clear();
              _addSystemMessage();
            });
          }, child: const Text("نعم، امسح", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // ---------------- منطق الاستماع (Voice Logic) ----------------
  
  void _toggleListening() async {
    if (!_isSpeechInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("المايكروفون غير جاهز، تأكد من الصلاحيات")));
      return;
    }

    if (_isListening) {
      // إيقاف الاستماع
      await _speech.stop();
      setState(() {
        _isListening = false;
        _inputHint = "اكتب أعراضك أو اضغط للتحدث...";
      });
    } else {
      // بدء الاستماع
      setState(() {
        _isListening = true;
        _inputHint = "جاري الاستماع... (أنا منصت لك)";
      });
      
      await _speech.listen(
        localeId: 'ar-DZ', // تحديد اللهجة الجزائرية
        listenFor: const Duration(minutes: 5), // مدة طويلة جداً
        pauseFor: const Duration(minutes: 1), // عدم التوقف عند السكوت
        partialResults: true,
        cancelOnError: false,
        onResult: (val) {
          setState(() {
            _textController.text = val.recognizedWords;
            // تحريك المؤشر لنهاية النص
            _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
          });
        },
      );
    }
  }

  // ---------------- منطق الإرسال والذكاء الاصطناعي (AI Logic) ----------------

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }

    _textController.clear();
    _handleAIResponse(text);
  }

  Future<void> _handleAIResponse(String userMessage) async {
    _addMessage("user", userMessage);
    setState(() => _isLoading = true);

    try {
      // التحقق من الإنترنت قبل الإرسال
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception("لا يوجد اتصال بالإنترنت");
      }

      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile', // موديل قوي وسريع
          'messages': [
            {
              'role': 'system',
              'content': '''
                أنت طبيب استشاري خبير (Expert Medical Consultant) في تطبيق "عافية".
                المريض اسمه: ${widget.userName}.

                الهدف: تقديم تشخيص أولي دقيق، اقتراح أدوية OTC (بدون وصفة)، ونصائح منزلية.

                القواعد الصارمة:
                1. اللغة: افهم "الدارجة الجزائرية" جيداً، لكن الرد يكون باللغة العربية الفصحى الطبية الواضحة (مع أسماء الأدوية بالفرنسية/الإنجليزية).
                2. الأمان: إذا كانت الحالة خطيرة (مثل ألم صدر شديد، إغماء)، اطلب التوجه للمستشفى فوراً.
                3. التنسيق (Markdown): استخدم العناوين والنقاط لتكون الإجابة مقروءة.
                
                هيكل الإجابة المطلوب:
                ## 🩺 التشخيص المحتمل:
                [شرح مبسط للحالة]

                ## 💊 الخطة العلاجية:
                * **[اسم الدواء العلمي]** (بالفرنسية)
                  - الجرعة: [مثلاً: حبة كل 8 ساعات بعد الأكل]
                  - المدة: [مثلاً: لمدة 3 أيام]

                ## 🌿 نصائح منزلية:
                * [نصيحة 1]
                * [نصيحة 2]

                ## ⚠️ تنبيه:
                [متى يجب زيارة الطبيب]
              '''
            },
            // إرسال تاريخ المحادثة للسياق
            ..._messages.map((m) => {'role': m['role'], 'content': m['text']}).toList(),
          ],
          'temperature': 0.4, // توازن بين الدقة والإبداع
          'max_tokens': 1024,
        }),
      ).timeout(const Duration(seconds: 30)); // مهلة 30 ثانية

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];
        _addMessage("assistant", reply);
      } else {
        _addMessage("assistant", "⚠️ واجهت مشكلة في الاتصال بالخادم. رمز الخطأ: ${response.statusCode}");
      }
    } catch (e) {
      String errorMsg = "حدث خطأ غير متوقع.";
      if (e.toString().contains("لا يوجد اتصال")) {
        errorMsg = "⚠️ يبدو أنك غير متصل بالإنترنت. يرجى التحقق وإعادة المحاولة.";
      } else if (e is TimeoutException) {
        errorMsg = "⚠️ الخادم استغرق وقتاً طويلاً. حاول مرة أخرى.";
      }
      _addMessage("assistant", errorMsg);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ---------------- بناء الواجهة (UI Building) ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // الشريط العلوي المخصص
      appBar: AppBar(
        title: Column(
          children: [
            const Text("عافية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(widget.userName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: "مسح المحادثة",
          ),
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: "تسجيل خروج",
          ),
        ],
      ),
      
      body: Column(
        children: [
          // قائمة الرسائل
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text("ابدأ المحادثة الآن...", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return _buildMessageBubble(msg['text']!, isUser);
                    },
                  ),
          ),
          
          // مؤشر الكتابة
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              alignment: Alignment.centerLeft,
              child: const Row(children: [
                SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text("جاري تحليل الأعراض...", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),

          // منطقة الإدخال السفلية
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // زر المايكروفون
                  GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.redAccent : const Color(0xFF00BFA5),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_isListening)
                            BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  
                  // حقل الكتابة
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _inputHint,
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        // إيقاف المايك إذا بدأ المستخدم بالكتابة يدوياً
                        if (_isListening && val.isNotEmpty) {
                          setState(() => _isListening = false);
                          _speech.stop();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // زر الإرسال
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF00BFA5)),
                    iconSize: 28,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ودجت الرسالة (Bubble)
  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF00BFA5) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(18),
          ),
          boxShadow: [
            if (!isUser) BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: isUser
              ? Text(text, style: const TextStyle(color: Colors.white, fontSize: 16))
              : MarkdownBody(
                  data: text,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                    strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
                    h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5), height: 2),
                    listBullet: const TextStyle(color: Color(0xFF00BFA5)),
                  ),
                ),
        ),
      ),
    );
  }
}
