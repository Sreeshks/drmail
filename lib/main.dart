import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const DRmailApp());
}

class DRmailApp extends StatelessWidget {
  const DRmailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DRmail',
      theme: ThemeData(
        primaryColor: Colors.amber,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black87,
        cardColor: const Color(0xFF1A1A1A),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF222222),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      home: const EmailScreen(),
    );
  }
}

// Report history model
class Report {
  final String date;
  final String loginTime;
  final String logoutTime;
  final String body;

  Report({
    required this.date,
    required this.loginTime,
    required this.logoutTime,
    required this.body,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'loginTime': loginTime,
      'logoutTime': logoutTime,
      'body': body,
    };
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      date: json['date'],
      loginTime: json['loginTime'],
      logoutTime: json['logoutTime'],
      body: json['body'],
    );
  }
}

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  _EmailScreenState createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _loginTimeController = TextEditingController();
  final TextEditingController _logoutTimeController = TextEditingController();
  final TextEditingController _serviceIdController = TextEditingController();
  final TextEditingController _templateIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  final DateTime _now = DateTime.now();
  List<Report> _reports = [];
  int _currentIndex = 0;
  late TabController _tabController;
  bool _isLoading = true;
  int _reportCount = 0;
  bool _showServiceSettings = false;
  bool _isImproving = false;
  late final GenerativeModel model;

  @override
  void initState() {
    super.initState();
    model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
    );
    _tabController = TabController(length: 2, vsync: this);
    // Set default login time to 9:30 AM
    _loginTimeController.text = '9:30 AM';
    // Set default logout time to 5:30 PM
    _logoutTimeController.text = '5:30 PM';
    _loadReports();
    _loadEmailServiceSettings();

    // Show AI feature message after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAIFeatureMessage();
    });
  }

  void _showAIFeatureMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Use AI to improve your report text! Click the sparkle icon ✨',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loadEmailServiceSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _serviceIdController.text = prefs.getString('serviceId') ?? '';
    _templateIdController.text = prefs.getString('templateId') ?? '';
    _userIdController.text = prefs.getString('userId') ?? '';

    if (_serviceIdController.text.trim().isEmpty ||
        _templateIdController.text.trim().isEmpty ||
        _userIdController.text.trim().isEmpty) {
      // Wait for the first frame to ensure context is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF222222),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'EmailJS Required',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ],
              ),
              content: Text(
                'Please add your EmailJS Service ID, Template ID, and User ID in the settings before using the app.',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              actions: [
                TextButton(
                  child: Text(
                    'Open Settings',
                    style: GoogleFonts.poppins(color: Colors.amber),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showServiceSettingsDialog();
                  },
                ),
              ],
            );
          },
        );
      });
    }
  }

  Future<void> _saveEmailServiceSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('serviceId', _serviceIdController.text);
    await prefs.setString('templateId', _templateIdController.text);
    await prefs.setString('userId', _userIdController.text);
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? reportsJson = prefs.getString('reports');
    _reportCount = prefs.getInt('reportCount') ?? 0;

    if (reportsJson != null) {
      List<dynamic> reportsData = jsonDecode(reportsJson);
      setState(() {
        _reports = reportsData.map((data) => Report.fromJson(data)).toList();
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveReports() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String reportsJson = jsonEncode(
      _reports.map((report) => report.toJson()).toList(),
    );
    await prefs.setString('reports', reportsJson);
  }

  Future<void> _incrementReportCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _reportCount++;
    await prefs.setInt('reportCount', _reportCount);
  }

  Future<void> sendEmail() async {
    if (_bodyController.text.isEmpty ||
        _loginTimeController.text.isEmpty ||
        _logoutTimeController.text.isEmpty) {
      showToast('Please fill all fields');
      return;
    }
    if (_serviceIdController.text.trim().isEmpty ||
        _templateIdController.text.trim().isEmpty ||
        _userIdController.text.trim().isEmpty) {
      showToast(
        'Please add your EmailJS Service ID, Template ID, and User ID in the settings before sending a report.',
      );
      _showServiceSettingsDialog();
      return;
    }

    setState(() {
      _isSending = true;
    });

    final serviceId = _serviceIdController.text;
    final templateId = _templateIdController.text;
    final userId = _userIdController.text;

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(_now);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': userId,
          'template_params': {
            'body': _bodyController.text,
            'login_time': _loginTimeController.text,
            'logout_time': _logoutTimeController.text,
            'date': formattedDate,
          },
        }),
      );

      if (response.statusCode == 200) {
        // Save email service settings
        await _saveEmailServiceSettings();

        // Increment report count
        await _incrementReportCount();

        // Save to history
        Report newReport = Report(
          date: formattedDate,
          loginTime: _loginTimeController.text,
          logoutTime: _logoutTimeController.text,
          body: _bodyController.text,
        );

        setState(() {
          _reports.insert(0, newReport); // Add as most recent
        });

        await _saveReports();

        showSuccessDialog();
        _bodyController.clear();
        // Keep login and logout times as is for the next report
      } else {
        showErrorDialog('Failed to send email. Please try again.');
      }
    } catch (error) {
      showErrorDialog(
        'Error connecting to server. Please check your connection.',
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _improveText() async {
    if (_bodyController.text.isEmpty) {
      showToast('Please enter some text first');
      return;
    }

    setState(() {
      _isImproving = true;
    });

    try {
      final prompt = '''
Please improve the following daily report text to make it more professional and well-written. 
Keep the bullet points format and maintain the same information, just improve the language:

${_bodyController.text}
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final improvedText = response.text;

      if (improvedText != null) {
        setState(() {
          _bodyController.text = improvedText;
        });
        showToast('Text improved successfully');
      } else {
        showToast('Failed to improve text');
      }
    } catch (e) {
      showToast('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isImproving = false;
      });
    }
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red[700],
      textColor: Colors.white,
    );
  }

  void showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[400], size: 28),
              const SizedBox(width: 8),
              Text('Success', style: GoogleFonts.poppins(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your daily report has been sent successfully!',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Added to your report history',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.analytics, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Total reports sent: $_reportCount',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: Colors.amber),
              ),
              onPressed: () {
                Navigator.of(context).pop();

                // Switch to history tab
                _tabController.animateTo(1);
              },
            ),
          ],
        ).animate().fadeIn().scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
        );
      },
    );
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 28),
              const SizedBox(width: 8),
              Text('Error', style: GoogleFonts.poppins(color: Colors.white)),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          actions: [
            TextButton(
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: Colors.amber),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red[400], size: 24),
              const SizedBox(width: 8),
              Text(
                'Delete Report',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this report? This action cannot be undone.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[300]),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
              child: Text('Delete', style: GoogleFonts.poppins()),
              onPressed: () {
                setState(() {
                  _reports.removeAt(index);
                });
                _saveReports();
                Navigator.of(context).pop();
                showToast('Report deleted');
              },
            ),
          ],
        );
      },
    );
  }

  void _showServiceSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.settings, color: Colors.amber),
              const SizedBox(width: 8),
              Text('EmailJs', style: GoogleFonts.poppins(color: Colors.white)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.amber),
                tooltip: 'How to use EmailJS',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HowToSetEmailJsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _serviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Service ID',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _templateIdController,
                decoration: const InputDecoration(
                  labelText: 'Template ID',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[300]),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Save',
                style: GoogleFonts.poppins(color: Colors.amber),
              ),
              onPressed: () async {
                await _saveEmailServiceSettings();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings saved'),
                    backgroundColor: Colors.amber,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Icon(Icons.email_outlined, color: Colors.amber)
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scaleXY(begin: 1, end: 1.2, duration: 1.5.seconds)
                .shimmer(duration: 1.seconds),
            const SizedBox(width: 10),
            Text(
              'DRmail',
              style: GoogleFonts.poppins(
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            color: const Color(0xFF222222),
            onSelected: (value) {
              if (value == 'how_to_use') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const HowToUseScreen(),
                  ),
                );
              } else if (value == 'how_to_set_emailjs') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const HowToSetEmailJsScreen(),
                  ),
                );
              } else if (value == 'contact_us') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ContactUsScreen(),
                  ),
                );
              } else if (value == 'templates') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TemplateScreen(),
                  ),
                );
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'how_to_use',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How to use DR MAIL',
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'how_to_set_emailjs',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How to set EmailJS',
                          style: GoogleFonts.poppins(),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'contact_us',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.contact_mail_outlined,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('Contact Us', style: GoogleFonts.poppins()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'templates',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('Email Templates', style: GoogleFonts.poppins()),
                      ],
                    ),
                  ),
                ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.amber),
            onPressed: _showServiceSettingsDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: const Icon(Icons.edit_note),
              text: 'New Report',
              iconMargin: const EdgeInsets.only(bottom: 4),
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: 'History',
              iconMargin: const EdgeInsets.only(bottom: 4),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // New Report Tab
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: const Color(0xFF1A1A1A),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: Colors.amber,
                              size: 24,
                            ).animate().fadeIn(duration: 300.ms).shimmer(),
                            const SizedBox(width: 10),
                            Text(
                                  'Daily Report',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideX(begin: 0.2, end: 0),
                          ],
                        ),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_now),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ).animate().fadeIn(duration: 500.ms),
                        const SizedBox(height: 20),

                        // Login & Logout Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Login Time',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _loginTimeController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: '9:30 AM',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      prefixIcon: Icon(
                                        Icons.access_time,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final TimeOfDay? picked =
                                          await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.fromDateTime(
                                              DateFormat('h:mm a').parse(
                                                _loginTimeController.text,
                                              ),
                                            ),
                                            builder: (
                                              BuildContext context,
                                              Widget? child,
                                            ) {
                                              return Theme(
                                                data: ThemeData.dark().copyWith(
                                                  colorScheme:
                                                      const ColorScheme.dark(
                                                        primary: Colors.amber,
                                                        onPrimary: Colors.black,
                                                        surface: Color(
                                                          0xFF1A1A1A,
                                                        ),
                                                        onSurface: Colors.white,
                                                      ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );
                                      if (picked != null) {
                                        setState(() {
                                          _loginTimeController.text =
                                              DateFormat('h:mm a').format(
                                                DateTime(
                                                  2022,
                                                  1,
                                                  1,
                                                  picked.hour,
                                                  picked.minute,
                                                ),
                                              );
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Logout Time',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _logoutTimeController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      hintText: '5:30 PM',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      prefixIcon: Icon(
                                        Icons.access_time,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final TimeOfDay? picked =
                                          await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.fromDateTime(
                                              DateFormat('h:mm a').parse(
                                                _logoutTimeController.text,
                                              ),
                                            ),
                                            builder: (
                                              BuildContext context,
                                              Widget? child,
                                            ) {
                                              return Theme(
                                                data: ThemeData.dark().copyWith(
                                                  colorScheme:
                                                      const ColorScheme.dark(
                                                        primary: Colors.amber,
                                                        onPrimary: Colors.black,
                                                        surface: Color(
                                                          0xFF1A1A1A,
                                                        ),
                                                        onSurface: Colors.white,
                                                      ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );
                                      if (picked != null) {
                                        setState(() {
                                          _logoutTimeController.text =
                                              DateFormat('h:mm a').format(
                                                DateTime(
                                                  2022,
                                                  1,
                                                  1,
                                                  picked.hour,
                                                  picked.minute,
                                                ),
                                              );
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Report Body
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daily Activities',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                final currentText = _bodyController.text;
                                final newPoint = '• ';
                                if (currentText.isEmpty) {
                                  _bodyController.text = newPoint;
                                } else {
                                  _bodyController.text =
                                      currentText + '\n' + newPoint;
                                }
                                // Move cursor to end of text
                                _bodyController
                                    .selection = TextSelection.fromPosition(
                                  TextPosition(
                                    offset: _bodyController.text.length,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.amber,
                              ),
                              label: Text(
                                'Add Point',
                                style: GoogleFonts.poppins(color: Colors.amber),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bodyController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Roboto',
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Enter your daily activities here...\nClick "Add Point" to add bullet points',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(
                              Icons.edit_note,
                              color: Colors.amber,
                            ),
                            suffixIcon: IconButton(
                              icon:
                                  _isImproving
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.amber,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.amber,
                                      ),
                              onPressed: _isImproving ? null : _improveText,
                              tooltip: 'Improve text using AI',
                            ),
                          ),
                          maxLines: 8,
                          textInputAction: TextInputAction.newline,
                        ),
                        const SizedBox(height: 24),

                        // Send Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                                onPressed: _isSending ? null : sendEmail,
                                icon:
                                    _isSending
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 3,
                                          ),
                                        )
                                        : const Icon(Icons.send),
                                label: Text(
                                  _isSending ? 'Sending...' : 'Send Report',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                              .animate()
                              .shimmer(delay: 2.seconds, duration: 1.seconds)
                              .then()
                              .shimmer(delay: 5.seconds, duration: 1.seconds),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            '© 2025 Developed by Sreesh K Suresh',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ).animate().fadeIn(duration: 1.seconds),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // History Tab
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
              : _reports.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 60,
                      color: Colors.grey[600],
                    ).animate().fadeIn().rotate(duration: 1.seconds),
                    const SizedBox(height: 16),
                    Text(
                      'No reports yet',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your sent reports will appear here',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reports.length,
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: const Color(0xFF1A1A1A),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    report.date,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: Colors.amber,
                                    ),
                                    onPressed:
                                        () => _showDeleteConfirmation(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'Login: ',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  Text(
                                    report.loginTime,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Logout: ',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  Text(
                                    report.logoutTime,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                report.body,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: (100 * index).ms)
                      .shimmer(delay: (100 * index).ms, duration: 600.ms);
                },
              ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _loginTimeController.dispose();
    _logoutTimeController.dispose();
    _serviceIdController.dispose();
    _templateIdController.dispose();
    _userIdController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

// How to Use Screen
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'How to use DR MAIL',
          style: GoogleFonts.poppins(color: Colors.amber),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      backgroundColor: Colors.black87,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'How to use DR MAIL',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 18),
          _step(
            '1. Open the app. You will see two tabs: New Report and History.',
          ),
          _step(
            '2. In the New Report tab, enter your daily activities. Use the "Add Point" button to add bullet points.',
          ),
          _step(
            '3. Set your Login and Logout times if needed by tapping the time fields.',
          ),
          _step(
            '4. Press the "Send Report" button to send your daily report via email.',
          ),
          _step(
            '5. After sending, your report is saved in the History tab for future reference.',
          ),
          _step('6. To view or delete past reports, go to the History tab.'),
          _step(
            '7. To configure email service settings, tap the settings icon (top right).',
          ),
          _step(
            '8. Your total sent reports count is shown in the success dialog after sending.',
          ),
          const SizedBox(height: 24),
          Text(
            'Tips:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          _step('- Use bullet points for clarity.'),
          _step('- You can edit your email service settings anytime.'),
          _step('- All data is stored locally and securely.'),
        ],
      ),
    );
  }

  Widget _step(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.amber, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

// How to Set EmailJS Screen
class HowToSetEmailJsScreen extends StatelessWidget {
  const HowToSetEmailJsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'How to set EmailJS',
          style: GoogleFonts.poppins(color: Colors.amber),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      backgroundColor: Colors.black87,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'How to set up EmailJS',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 18),
          _step(
            '1. Go to https://www.emailjs.com/ and sign up for a free account.',
          ),
          _step(
            '2. Add an email service (e.g., Gmail, Outlook) in the Email Services section.',
          ),
          _step(
            '3. Create a new email template. Add variables like {{body}}, {{login_time}}, {{logout_time}}, and {{date}}.',
          ),
          _step(
            '4. Copy your Service ID, Template ID, and User ID from the EmailJS dashboard.',
          ),
          _step('5. In the DR MAIL app, tap the settings icon (top right).'),
          _step(
            '6. Paste your Service ID, Template ID, and User ID into the respective fields.',
          ),
          _step('7. Save the settings. You are now ready to send reports!'),
          const SizedBox(height: 24),
          Text(
            'Tips:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          _step(
            '- Make sure your template variables match the app (body, login_time, logout_time, date).',
          ),
          _step(
            '- You can test your template in the EmailJS dashboard before using it in the app.',
          ),
        ],
      ),
    );
  }

  Widget _step(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.amber, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

// Contact Us Screen
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Contact Us',
          style: GoogleFonts.poppins(color: Colors.amber),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      backgroundColor: Colors.black87,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Us',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.amber),
              title: Text(
                'sreeshksureshh@gmail.com',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () => _launchUrl('mailto:sreeshksureshh@gmail.com'),
            ),
            ListTile(
              leading: const Icon(Icons.linked_camera, color: Colors.amber),
              title: Text(
                'LinkedIn',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              subtitle: Text(
                'linkedin.com/in/sreesh-k-suresh',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              onTap:
                  () => _launchUrl(
                    'https://www.linkedin.com/in/sreesh-k-suresh/',
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.amber),
              title: Text(
                'GitHub',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              subtitle: Text(
                'github.com/Sreeshks',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              onTap: () => _launchUrl('https://github.com/Sreeshks'),
            ),
          ],
        ),
      ),
    );
  }
}

// Template Screen
class TemplateScreen extends StatefulWidget {
  const TemplateScreen({super.key});

  @override
  _TemplateScreenState createState() => _TemplateScreenState();
}

class _TemplateScreenState extends State<TemplateScreen> {
  final List<Map<String, dynamic>> _templates = [
    {
      'name': 'Default Template',
      'description': 'Simple and clean template for daily reports',
      'templateId': 'template_default',
      'preview': 'assets/template_preview1.png',
      'htmlCode': '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Daily Report</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      color: #222;
      background: #f4f4f4;
      margin: 0;
      padding: 0;
    }
    .container {
      max-width: 600px;
      background: #fff;
      margin: 30px auto;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.07);
      padding: 32px 28px 18px 28px;
    }
    .header {
      border-bottom: 1.5px solid #e0e0e0;
      padding-bottom: 10px;
      margin-bottom: 18px;
    }
    .header h2 {
      margin: 0;
      font-size: 22px;
      color: #1a73e8;
      font-weight: 600;
    }
    .content p {
      margin: 10px 0 0 0;
      font-size: 15px;
    }
    .time-info {
      background: #f7fafc;
      border: 1px solid #e0e0e0;
      border-radius: 4px;
      padding: 10px 16px;
      margin: 18px 0 12px 0;
      font-size: 14px;
    }
    .activities {
      margin: 0 0 10px 0;
    }
    .activities ul {
      margin: 0 0 0 18px;
      padding: 0;
    }
    .activities li {
      margin-bottom: 6px;
      font-size: 15px;
    }
    .signature {
      margin-top: 24px;
      border-top: 1px solid #e0e0e0;
      padding-top: 12px;
      font-size: 14px;
      color: #555;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h2>Daily Report</h2>
    </div>
    <div class="content">
      <p>Dear Team,</p>
      <p>Please find my end-of-day report below:</p>
      <div class="time-info">
        <strong>Login Time:</strong> {{ login_time }}<br>
        <strong>Logout Time:</strong> {{ logout_time }}
      </div>
      <div class="activities">
        <strong>Daily Activities:</strong>
        <div style="white-space: pre-line; font-family: Arial, sans-serif; margin: 0 0 10px 0;">
  {{ body }}
</div>
      </div>
    </div>
    <div class="signature">
      Best regards,<br>
      <strong>Sreesh</strong>
    </div>
  </div>
</body>
</html>''',
    },
    {
      'name': 'Professional Template',
      'description': 'Formal template with company branding',
      'templateId': 'template_professional',
      'preview': 'assets/template_preview2.png',
      'htmlCode': '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Professional Daily Report</title>
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      color: #333;
      background: #f8f9fa;
      margin: 0;
      padding: 0;
    }
    .container {
      max-width: 650px;
      background: #fff;
      margin: 40px auto;
      border-radius: 12px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.08);
      padding: 40px 35px 25px 35px;
    }
    .header {
      text-align: center;
      border-bottom: 2px solid #f0f0f0;
      padding-bottom: 15px;
      margin-bottom: 25px;
    }
    .header h2 {
      margin: 0;
      font-size: 24px;
      color: #2c3e50;
      font-weight: 600;
    }
    .date {
      color: #666;
      font-size: 14px;
      margin-top: 5px;
    }
    .content {
      font-size: 15px;
      line-height: 1.6;
    }
    .time-info {
      background: #f8f9fa;
      border: 1px solid #e9ecef;
      border-radius: 8px;
      padding: 15px 20px;
      margin: 25px 0 20px 0;
      font-size: 14px;
    }
    .activities {
      margin: 20px 0;
    }
    .activities h3 {
      color: #2c3e50;
      font-size: 18px;
      margin-bottom: 15px;
    }
    .activities ul {
      margin: 0;
      padding-left: 20px;
    }
    .activities li {
      margin-bottom: 10px;
      font-size: 15px;
    }
    .signature {
      margin-top: 30px;
      border-top: 2px solid #f0f0f0;
      padding-top: 20px;
      font-size: 14px;
      color: #666;
    }
    .company-logo {
      text-align: center;
      margin-bottom: 20px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="company-logo">
        <!-- Add your company logo here -->
        <h1 style="color: #2c3e50; margin: 0;">COMPANY NAME</h1>
      </div>
      <h2>Daily Activity Report</h2>
      <div class="date">{{ date }}</div>
    </div>
    <div class="content">
      <p>Dear Team,</p>
      <p>Please find below my daily activity report:</p>
      <div class="time-info">
        <strong>Login Time:</strong> {{ login_time }}<br>
        <strong>Logout Time:</strong> {{ logout_time }}
      </div>
      <div class="activities">
        <h3>Activities Completed:</h3>
        <div style="white-space: pre-line; font-family: 'Segoe UI', sans-serif;">
          {{ body }}
        </div>
      </div>
    </div>
    <div class="signature">
      Best regards,<br>
      <strong>Sreesh</strong><br>
      <span style="color: #666; font-size: 13px;">Position Title</span>
    </div>
  </div>
</body>
</html>''',
    },
    {
      'name': 'Minimal Template',
      'description': 'Minimalist design with focus on content',
      'templateId': 'template_minimal',
      'preview': 'assets/template_preview3.png',
      'htmlCode': '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Minimal Daily Report</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      color: #2d3436;
      background: #ffffff;
      margin: 0;
      padding: 0;
      line-height: 1.6;
    }
    .container {
      max-width: 580px;
      background: #ffffff;
      margin: 40px auto;
      padding: 40px;
    }
    .header {
      margin-bottom: 30px;
    }
    .header h2 {
      margin: 0;
      font-size: 24px;
      font-weight: 600;
      color: #2d3436;
    }
    .date {
      color: #636e72;
      font-size: 14px;
      margin-top: 8px;
    }
    .content {
      font-size: 15px;
    }
    .time-info {
      background: #f5f6fa;
      padding: 15px;
      margin: 25px 0;
      font-size: 14px;
      border-left: 3px solid #0984e3;
    }
    .activities {
      margin: 25px 0;
    }
    .activities h3 {
      color: #2d3436;
      font-size: 16px;
      margin-bottom: 15px;
      font-weight: 600;
    }
    .signature {
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid #dfe6e9;
      font-size: 14px;
      color: #636e72;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h2>Daily Report</h2>
      <div class="date">{{ date }}</div>
    </div>
    <div class="content">
      <div class="time-info">
        <strong>Login:</strong> {{ login_time }}<br>
        <strong>Logout:</strong> {{ logout_time }}
      </div>
      <div class="activities">
        <h3>Activities</h3>
        <div style="white-space: pre-line;">
          {{ body }}
        </div>
      </div>
    </div>
    <div class="signature">
      Best regards,<br>
      <strong>Sreesh</strong>
    </div>
  </div>
</body>
</html>''',
    },
  ];

  String _selectedTemplateId = 'template_default';
  int _currentIndex = 0;

  // Add controllers for email service settings
  final TextEditingController _serviceIdController = TextEditingController();
  final TextEditingController _templateIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmailServiceSettings();
  }

  Future<void> _loadEmailServiceSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _serviceIdController.text = prefs.getString('serviceId') ?? '';
    _templateIdController.text = prefs.getString('templateId') ?? '';
    _userIdController.text = prefs.getString('userId') ?? '';
  }

  Future<void> _saveEmailServiceSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('serviceId', _serviceIdController.text);
    await prefs.setString('templateId', _templateIdController.text);
    await prefs.setString('userId', _userIdController.text);
  }

  void _showServiceSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.settings, color: Colors.amber),
              const SizedBox(width: 8),
              Text('EmailJs', style: GoogleFonts.poppins(color: Colors.white)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.amber),
                tooltip: 'How to use EmailJS',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HowToSetEmailJsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _serviceIdController,
                decoration: const InputDecoration(
                  labelText: 'Service ID',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _templateIdController,
                decoration: const InputDecoration(
                  labelText: 'Template ID',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[300]),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Save',
                style: GoogleFonts.poppins(color: Colors.amber),
              ),
              onPressed: () async {
                await _saveEmailServiceSettings();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings saved'),
                    backgroundColor: Colors.amber,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _serviceIdController.dispose();
    _templateIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Email Templates',
          style: GoogleFonts.poppins(color: Colors.amber),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.amber),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.amber),
            onPressed: _showAddTemplateDialog,
          ),
        ],
      ),
      backgroundColor: Colors.black87,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select a template for your daily reports',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[400]),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                final isSelected =
                    template['templateId'] == _selectedTemplateId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.amber : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  color: const Color(0xFF1A1A1A),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTemplateId = template['templateId'];
                      });
                      _showTemplateDetails(template);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color:
                                    isSelected
                                        ? Colors.amber
                                        : Colors.grey[400],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  template['name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.amber,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            template['description'],
                            style: GoogleFonts.poppins(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showTemplateDetails(template),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                label: Text(
                                  'Preview',
                                  style: GoogleFonts.poppins(
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed:
                                    () => _showHowToUseTemplate(template),
                                icon: const Icon(
                                  Icons.help_outline,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                label: Text(
                                  'How to Use',
                                  style: GoogleFonts.poppins(
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (100 * index).ms);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            switch (index) {
              case 0:
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const EmailScreen()),
                );
                break;
              case 1:
                // Already on templates screen
                break;
              case 2:
                _showServiceSettingsDialog();
                break;
            }
          },
          backgroundColor: Colors.black,
          selectedItemColor: Colors.amber,
          unselectedItemColor: Colors.grey[600],
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Templates',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateDetails(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.description_outlined, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                template['name'],
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Template ID:',
                  style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          template['templateId'],
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.amber),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: template['templateId']),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Template ID copied to clipboard'),
                              backgroundColor: Colors.amber,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Description:',
                  style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  template['description'],
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Variables:',
                  style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '{{body}} - Daily activities\n{{login_time}} - Login time\n{{logout_time}} - Logout time\n{{date}} - Current date',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                TemplatePreviewScreen(template: template),
                      ),
                    );
                  },
                  icon: const Icon(Icons.code),
                  label: Text('View HTML Code', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Close',
                style: GoogleFonts.poppins(color: Colors.amber),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showHowToUseTemplate(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.help_outline, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'How to Use ${template['name']}',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Copy the template ID:',
                style: GoogleFonts.poppins(
                  color: Colors.amber,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        template['templateId'],
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.amber),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: template['templateId']),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Template ID copied to clipboard'),
                            backgroundColor: Colors.amber,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '2. Go to EmailJS dashboard and create a new template',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '3. Paste the template ID in your EmailJS template settings',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '4. Make sure to include these variables in your template:',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '{{body}}\n{{login_time}}\n{{logout_time}}\n{{date}}',
                  style: GoogleFonts.poppins(color: Colors.amber),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'Close',
                style: GoogleFonts.poppins(color: Colors.amber),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddTemplateDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController nameController = TextEditingController();
        final TextEditingController descriptionController =
            TextEditingController();
        final TextEditingController templateIdController =
            TextEditingController();

        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Add New Template',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: templateIdController,
                decoration: const InputDecoration(
                  labelText: 'Template ID',
                  labelStyle: TextStyle(color: Colors.amber),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey[300]),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Add',
                style: GoogleFonts.poppins(color: Colors.amber),
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty &&
                    templateIdController.text.isNotEmpty) {
                  setState(() {
                    _templates.add({
                      'name': nameController.text,
                      'description': descriptionController.text,
                      'templateId': templateIdController.text,
                      'preview': 'assets/template_preview1.png',
                    });
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// Template Preview Screen
class TemplatePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> template;

  const TemplatePreviewScreen({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${template['name']} Preview',
          style: GoogleFonts.poppins(color: Colors.amber),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.amber),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.amber),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: template['htmlCode']));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('HTML code copied to clipboard'),
                  backgroundColor: Colors.amber,
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.black87,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1A1A1A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Template Details',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  template['description'],
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Template ID: ',
                      style: GoogleFonts.poppins(
                        color: Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        template['templateId'],
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        color: Colors.amber,
                        size: 20,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: template['templateId']),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Template ID copied to clipboard'),
                            backgroundColor: Colors.amber,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HTML Code',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        template['htmlCode'],
                        style: GoogleFonts.robotoMono(
                          color: Colors.grey[300],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
