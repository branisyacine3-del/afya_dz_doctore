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
import 'package:connectivity_plus/connectivity_plus.dart';

// ==========================================
// 1. إعدادات التطبيق (Main Setup)
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // تثبيت الوضع العمودي
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const AfyaDZApp());
}

class AfyaDZApp extends StatelessWidget {
  const AfyaDZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'عافية - Afya DZ',
      // إعدادات اللغة العربية الإجبارية
      locale: const Locale('ar', 'DZ'),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF00BFA5),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA5),
          primary: const Color(0xFF00BFA5),
          secondary: const Color(0xFF00897B),
          surface: Colors.white,
          error: const Color(0xFFE53935),
        ),
        fontFamily: 'Roboto', 
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF00BFA5), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BFA5),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 2. شاشة البداية (Splash Screen)
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
    _controller = AnimationController(duration: const Duration(milliseconds: 2500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    
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
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF00BFA5), Color(0xFF00897B), Color(0xFF00695C)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, 10))]),
                  child: ClipOval(
                    child: Image.asset('logo.png', height: 130, width: 130, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 100, color: Color(0xFF00BFA5))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text("عافية", style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text("رعايتك الصحية.. بلمسة ذكية", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 80),
            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. الشاشات التعريفية (Intro)
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
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5)),
      bodyTextStyle: TextStyle(fontSize: 18.0, color: Colors.black54, height: 1.6),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      rtl: true, // تفعيل الاتجاه العربي
      pages: [
        PageViewModel(
          title: "طبيبك الشخصي",
          body: "تطبيق عافية يوفر لك كشفاً طبياً ذكياً. يفهمك، يسألك، ثم يشخص حالتك بدقة.",
          image: _buildImage(Icons.medical_services_rounded),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "يفهم الدارجة",
          body: "تحدث بلهجتك الجزائرية بكل راحة. التطبيق مدرب ليفهم كلامنا ومصطلحاتنا.",
          image: _buildImage(Icons.record_voice_over_rounded),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "روشتة وتوجيه",
          body: "احصل على أسماء الأدوية، طريقة الاستعمال، ونصائح منزلية. وفي الخطر نوجهك للمستشفى.",
          image: _buildImage(Icons.receipt_long_rounded),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: const Text("تخطي", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
      next: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF00BFA5)), // سهم لليسار
      done: const Text("ابدأ", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
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
      width: 180, height: 180,
      decoration: BoxDecoration(color: const Color(0xFFE0F2F1), shape: BoxShape.circle),
      child: Icon(icon, size: 90, color: const Color(0xFF00BFA5)),
    );
  }
}

// ==========================================
// 4. بوابة الدخول (Auth Gate)
// ==========================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return UserDataLoader(user: snapshot.data!);
        }
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
        var userData = snapshot.data!.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? "المريض";
        return DoctorScreen(userName: userName);
      },
    );
  }
}

// ==========================================
// 5. شاشة التسجيل (Auth Screen)
// ==========================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
      } else {
        UserCredential uc = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _pass.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(uc.user!.uid).set({
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
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
              children: [
                Image.asset('logo.png', height: 90, errorBuilder: (c,e,s) => const Icon(Icons.health_and_safety, size: 90, color: Color(0xFF00BFA5))),
                const SizedBox(height: 20),
                Text(isLogin ? "مرحباً بعودتك" : "حساب جديد", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
                const SizedBox(height: 40),
                if (_error != null) Container(padding: const EdgeInsets.all(10), color: Colors.red[50], child: Text(_error!, style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 10),
                if (!isLogin) TextFormField(controller: _name, validator: (v)=>v!.isEmpty?"الاسم مطلوب":null, decoration: const InputDecoration(labelText: "الاسم", prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 15),
                TextFormField(controller: _email, validator: (v)=>!v!.contains("@")?"بريد خاطئ":null, decoration: const InputDecoration(labelText: "البريد الإلكتروني", prefixIcon: Icon(Icons.email))),
                const SizedBox(height: 15),
                TextFormField(controller: _pass, obscureText: true, validator: (v)=>v!.length<6?"كلمة المرور قصيرة":null, decoration: const InputDecoration(labelText: "كلمة المرور", prefixIcon: Icon(Icons.lock))),
                const SizedBox(height: 30),
                _isLoading ? const CircularProgressIndicator() : SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submit, child: Text(isLogin ? "دخول" : "تسجيل"))),
                TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? "ليس لديك حساب؟ سجل الآن" : "لديك حساب؟ ادخل هنا"))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 6. شاشة الطبيب الذكي (Engine) - قلب التطبيق
// ==========================================

class DoctorScreen extends StatefulWidget {
  final String userName;
  const DoctorScreen({super.key, required this.userName});
  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen> with WidgetsBindingObserver {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  
  bool _isListening = false;
  bool _isLoading = false;
  bool _isSpeechInitialized = false;
  
  // 🔴🔴 مفتاحك هنا 🔴🔴
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

  void _initSpeech() async {
    try {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _isSpeechInitialized = await _speech.initialize(
          onError: (e) => setState(() => _isListening = false),
          onStatus: (s) => print('Status: $s'),
        );
        setState(() {});
      }
    } catch (e) {
      print("Mic Error: $e");
    }
  }

  // رسالة ترحيبية ذكية
  void _addSystemMessage() {
    setState(() {
      _messages.add({
        "role": "assistant",
        "text": "أهلاً بك يا ${widget.userName} 🩺.\nأنا طبيبك المقيم. لكي أشخص حالتك بدقة، سأحتاج لطرح بعض الأسئلة أولاً.\n\nتفضل، اشرح لي مما تعاني؟"
      });
    });
  }

  void _addMessage(String role, String text) {
    setState(() { _messages.add({"role": role, "text": text}); });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _addSystemMessage();
    });
  }

  void _toggleListening() async {
    if (!_isSpeechInitialized) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        localeId: 'ar-DZ',
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10), // انتظار أطول
        partialResults: true,
        onResult: (val) {
          setState(() {
            _textController.text = val.recognizedWords;
            _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
          });
        },
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (_isListening) { _speech.stop(); setState(() => _isListening = false); }
    _textController.clear();
    _handleAIResponse(text);
  }

  // 🔥 الذكاء الاصطناعي (تم تعديل الدماغ ليكون طبيباً محققاً)
  Future<void> _handleAIResponse(String userMessage) async {
    _addMessage("user", userMessage);
    setState(() => _isLoading = true);

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) throw Exception("No Internet");

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
              // 👇👇👇 هنا يكمن سر الطبيب المحقق 👇👇👇
              'content': '''
                أنت الدكتور "عافية"، طبيب جزائري خبير ومحقق.
                اسم المريض: ${widget.userName}.

                🔴 قاعدتك الذهبية: لا تشخص فوراً! يجب أن تجمع المعلومات (Triage) أولاً.

                خطواتك مع المريض:
                1. **مرحلة التحقيق (الأهم):** - إذا قال المريض "رأسي يؤلمني" أو "أنا مريض"، لا تعطه دواء فوراً.
                   - اسأله: كم عمرك؟ منذ متى الألم؟ هل تعاني من ضغط أو سكري؟ هل أخذت دواء؟
                   - تصرف كطبيب في عيادة يسأل عن التاريخ المرضي (History Taking).
                
                2. **مرحلة الفحص:**
                   - اطلب منه القيام بفحص بسيط إذا لزم الأمر (مثلاً: "اضغط على يمين بطنك، هل يؤلمك؟").

                3. **مرحلة التشخيص والعلاج (فقط عندما تكتمل المعلومات):**
                   - عندما تجد أن لديك معلومات كافية، أعط التشخيص.
                   - اكتب الروشتة بشكل منظم جداً (استخدم Markdown).
                
                ⚠️ تنسيق الكتابة (مهم جداً لعدم خلط الكلام):
                - اكتب باللغة العربية الفصحى الطبية المفهومة للجزائريين.
                - عند كتابة اسم دواء بالفرنسية/الإنجليزية، ضعه في سطر جديد وحده لكي لا يختلط مع النص العربي.
                
                مثال للرد النهائي (الروشتة):
                ## 🩺 التشخيص:
                نزلة برد حادة (Grippe).

                ## 💊 الوصفة:
                * خافض حرارة ومسكن:
                **Paracetamol 1g**
                (حبة كل 8 ساعات)

                * فيتامين للمناعة:
                **Vitamin C 1000mg**
                (قرص فوار صباحاً)

                ## 💡 نصائح:
                - الراحة التامة وشرب السوائل.
              '''
            },
            ..._messages.map((m) => {'role': m['role'], 'content': m['text']}).toList(),
          ],
          'temperature': 0.3, // تقليل العشوائية ليكون دقيقاً
          'max_tokens': 1200,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final reply = data['choices'][0]['message']['content'];
        _addMessage("assistant", reply);
      } else {
        _addMessage("assistant", "⚠️ الخادم مشغول قليلاً، حاول مرة أخرى.");
      }
    } catch (e) {
      _addMessage("assistant", "⚠️ تأكد من اتصال الإنترنت.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text("عيادة عافية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
            Text(widget.userName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF00BFA5),
        elevation: 0,
        leading: IconButton(onPressed: _clearChat, icon: const Icon(Icons.delete_outline, color: Colors.white), tooltip: "كشف جديد"),
        actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout, color: Colors.white))],
      ),
      
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medical_information, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text("سجل المريض فارغ...", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                      ],
                    ),
                  )
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
          
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFA5))),
                  const SizedBox(width: 10),
                  Text("الدكتور يراجع حالتك...", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          // منطقة الإدخال (شات)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.redAccent : const Color(0xFF00BFA5),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_isListening) BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                        ],
                      ),
                      child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _isListening ? "جاري الاستماع..." : "اكتب أعراضك هنا...",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF00BFA5), size: 30),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF00BFA5) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
          boxShadow: [if (!isUser) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) 
                Row(children: const [
                  Icon(Icons.health_and_safety, size: 16, color: Color(0xFF00BFA5)),
                  SizedBox(width: 5),
                  Text("الطبيب", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                ]),
              if (!isUser) const SizedBox(height: 5),
              
              // ✅ إصلاح اتجاه النص ودعم الماركداون
              Directionality(
                textDirection: TextDirection.rtl, // إجبار النص العربي من اليمين
                child: MarkdownBody(
                  data: text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(fontSize: 16, height: 1.6, color: isUser ? Colors.white : Colors.black87, fontFamily: 'Roboto'),
                    strong: TextStyle(fontWeight: FontWeight.bold, color: isUser ? Colors.white : const Color(0xFF00897B)),
                    h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5), height: 2),
                    listBullet: TextStyle(color: isUser ? Colors.white : const Color(0xFF00BFA5)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
