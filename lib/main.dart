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
import 'package:flutter_markdown/flutter_markdown.dart'; // مكتبة التنسيق

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA5),
          primary: const Color(0xFF00BFA5),
          secondary: const Color(0xFF00897B),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // خلفية رمادية فاتحة جداً مريحة للعين
        fontFamily: 'Roboto', // يفضل تغييرها لخط "Cairo" أو "Tajawal" مستقبلاً
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00BFA5),
          centerTitle: true,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ======================= 1. شاشة البداية (Splash) =======================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // أنيميشن ظهور الشعار
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Timer(const Duration(seconds: 4), _navigateNext);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]),
                child: ClipOval(
                  child: Image.asset('logo.png', height: 110, width: 110, fit: BoxFit.cover,
                      errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 90, color: Color(0xFF00BFA5))),
                ),
              ),
              const SizedBox(height: 25),
              const Text("عافية", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              const Text("رعايتك الصحية.. بلمسة ذكية", style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 60),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= 2. الشاشات التعريفية (Intro) =======================
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
      bodyTextStyle: TextStyle(fontSize: 18.0, color: Colors.black54),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      pages: [
        PageViewModel(
          title: "طبيبك الخبير",
          body: "احصل على استشارة طبية دقيقة وفورية من ذكاء اصطناعي مدرب طبياً.",
          image: Padding(padding: const EdgeInsets.only(top: 50), child: Image.asset('logo.png', height: 150, errorBuilder: (c,e,s)=>const Icon(Icons.medical_services, size: 120, color: Color(0xFF00BFA5)))),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "تحدث بحرية",
          body: "اضغط على المايكروفون واشرح أعراضك بالدارجة الجزائرية، وسنفهمك.",
          image: const Padding(padding: EdgeInsets.only(top: 50), child: Icon(Icons.mic_none_rounded, size: 150, color: Color(0xFF00BFA5))),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "خصوصية تامة",
          body: "بياناتك مشفرة ولا يطلع عليها أحد. سجل الآن وابدأ رحلة العافية.",
          image: const Padding(padding: EdgeInsets.only(top: 50), child: Icon(Icons.verified_user_rounded, size: 150, color: Color(0xFF00BFA5))),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text("تخطي", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
      next: const Icon(Icons.arrow_forward, color: Color(0xFF00BFA5)),
      done: const Text("ابدأ الآن", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        color: Color(0xFFBDBDBD),
        activeSize: Size(22.0, 10.0),
        activeColor: Color(0xFF00BFA5),
        activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25.0))),
      ),
    );
  }
}

// ======================= 3. بوابة الدخول (Auth Gate) =======================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const EmailAuthScreen();
        return UserDataLoader(user: snapshot.data!);
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
        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? "المريض";
        return DoctorScreen(userName: userName);
      },
    );
  }
}

// ======================= 4. شاشة التسجيل (Email Login) =======================
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
          email: _emailController.text.trim(), password: _passwordController.text.trim());
      } else {
        userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(), password: _passwordController.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'isPaid': false,
        });
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: ${e.message}"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('logo.png', height: 100, errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 100, color: Color(0xFF00BFA5))),
              const SizedBox(height: 20),
              Text(isLogin ? "مرحباً بعودتك" : "انشاء حساب جديد", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
              const SizedBox(height: 10),
              Text(isLogin ? "سجل الدخول للمتابعة" : "انضم لعائلة عافية الآن", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              if (!isLogin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(labelText: 'الاسم الكامل', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                ),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: const Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'كلمة المرور', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 30),
              _isLoading ? const CircularProgressIndicator() : SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFA5), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
                  child: Text(isLogin ? "دخول آمن" : "تسجيل مجاني", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? "ليس لديك حساب؟ سجل الآن" : "لديك حساب؟ سجل الدخول", style: const TextStyle(color: Color(0xFF00BFA5), fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= 5. شاشة الطبيب (القلب النابض للتطبيق) =======================
class DoctorScreen extends StatefulWidget {
  final String userName;
  const DoctorScreen({super.key, required this.userName});
  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _statusText = "اضغط مطولاً للتحدث";
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _currentWords = "";

  // 🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴
  // 🔴 ضع مفتاح Groq الجديد والخاص بك هنا 🔴
  final String _apiKey = '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'; // استبدل هذا بمفتاحك
  // 🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴🔴

  @override
  void initState() {
    super.initState();
    _addMessage("assistant", "أهلاً بك يا ${widget.userName} 🩺.\nأنا طبيبك الذكي. اشرح لي أعراضك، وسأقوم بتحليل حالتك.");
  }

  void _addMessage(String role, String text) {
    setState(() { _messages.add({"role": role, "text": text}); });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ميزة 2: مسح المحادثة
  void _clearChat() {
    setState(() {
      _messages.clear();
      _addMessage("assistant", "أهلاً بك مجدداً يا ${widget.userName}. كيف يمكنني مساعدتك الآن؟");
    });
  }

  // ميزة الصوت المستمر
  void _startListening() async {
    bool available = await _speech.initialize(onError: (val) => setState(() { _isListening = false; _statusText = "خطأ في المايك"; }));
    if (available) {
      setState(() { _isListening = true; _statusText = "أنا أسمعك... (تكلم براحتك)"; _currentWords = ""; });
      _speech.listen(
        localeId: 'ar-DZ',
        pauseFor: const Duration(minutes: 2), // لن يتوقف أبداً حتى لو سكت المريض
        listenFor: const Duration(minutes: 2),
        partialResults: true,
        onResult: (val) {
          setState(() => _currentWords = val.recognizedWords);
        }
      );
    }
  }

  void _stopListening() async {
    setState(() { _isListening = false; _statusText = "اضغط مطولاً للتحدث"; });
    await _speech.stop();
    if (_currentWords.trim().length > 2) {
      _handleUserMessage(_currentWords);
    }
  }

  Future<void> _handleUserMessage(String message) async {
    _addMessage("user", message);
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
              // الشخصية الطبية الصارمة
              'content': '''
                أنت دكتور استشاري خبير جداً في تطبيق "عافية". المريض اسمه "${widget.userName}".
                
                القواعد الصارمة:
                1. إذا كان النص غير مفهوم (خربشة)، قل: "عذراً، لم أفهم الصوت جيداً. أعد الوصف."
                2. تحدث بالعربية الفصحى البسيطة والطبية فقط (تجنب اللهجات الصعبة).
                3. اسأل المريض عن عمره وأمراضه المزمنة إذا لم يذكرها.
                4. نسق الإجابة باستخدام Markdown بشكل جميل:
                   - استخدم الخط العريض (**الدواء**) للأدوية.
                   - استخدم القوائم (-) للنصائح.
                   - ضع العناوين الرئيسية (التشخيص، العلاج).
                5. كن مختصراً ومباشراً.
              '''
            },
            ..._messages.map((m) => {'role': m['role'], 'content': m['text']}).toList(), // إرسال سياق المحادثة
          ],
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];
        _addMessage("assistant", reply);
      } else {
        _addMessage("assistant", "حدث خطأ في الاتصال، يرجى المحاولة لاحقاً.");
      }
    } catch (e) {
      _addMessage("assistant", "عذراً، حدث خطأ تقني.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // الشريط العلوي مع الأزرار الجديدة
      appBar: AppBar(
        title: const Text("عافية", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: IconButton(onPressed: _clearChat, icon: const Icon(Icons.delete_sweep_rounded), tooltip: "مسح المحادثة"),
        actions: [
          IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout_rounded), tooltip: "خروج"),
        ],
      ),
      body: Column(
        children: [
          // قائمة الرسائل
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00BFA5) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                      ]
                    ),
                    // ميزة 1: استخدام Markdown
                    child: MarkdownBody(
                      data: msg['text']!,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 16, color: isUser ? Colors.white : Colors.black87, height: 1.5),
                        strong: TextStyle(fontWeight: FontWeight.bold, color: isUser ? Colors.white : const Color(0xFF00BFA5)),
                        listBullet: TextStyle(color: isUser ? Colors.white : const Color(0xFF00BFA5)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // ميزة 4: أنيميشن الكتابة
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Row(children: [
                const Text("الطبيب يكتب ", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                _buildTypingDot(0), _buildTypingDot(1), _buildTypingDot(2),
              ]),
            ),

          // منطقة التحكم السفلية
          Container(
            padding: const EdgeInsets.only(bottom: 30, top: 15),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
            ),
            child: Column(
              children: [
                // ميزة 5: زر المايك التفاعلي
                GestureDetector(
                  onLongPressStart: (_) => _startListening(),
                  onLongPressEnd: (_) => _stopListening(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    height: _isListening ? 90 : 75, // يكبر عند الضغط
                    width: _isListening ? 90 : 75,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : const Color(0xFF00BFA5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: (_isListening ? Colors.red : const Color(0xFF00BFA5)).withOpacity(0.4), blurRadius: _isListening ? 25 : 15, spreadRadius: _isListening ? 5 : 2)
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: _isListening ? 45 : 35,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusText,
                  style: TextStyle(color: _isListening ? Colors.red : Colors.grey[600], fontWeight: FontWeight.bold),
                ),
                // ميزة 3: شريط إخلاء المسؤولية
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "تنبيه: هذا التطبيق يقدم نصائح أولية فقط. في الحالات الطارئة توجه للمستشفى فوراً.",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ودجت للنقاط المتحركة (Loading Dots)
  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          height: 6, width: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF00BFA5).withOpacity((value + index / 3) % 1),
            shape: BoxShape.circle,
          ),
        );
      }, 
      onEnd: () {},
    );
  }
}
