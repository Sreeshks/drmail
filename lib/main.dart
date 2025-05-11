import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Set default login time to 9:30 AM
    _loginTimeController.text = '9:30 AM';
    // Set default logout time to 5:30 PM
    _logoutTimeController.text = '5:30 PM';
    _loadReports();
    _loadEmailServiceSettings();
  }

  Future<void> _loadEmailServiceSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _serviceIdController.text =
        prefs.getString('serviceId') ?? 'service_po5m52c';
    _templateIdController.text =
        prefs.getString('templateId') ?? 'template_icnzmr9';
    _userIdController.text = prefs.getString('userId') ?? 'ys6bmZUnz4w5hWi1g';
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
        _logoutTimeController.text.isEmpty ||
        _serviceIdController.text.isEmpty ||
        _templateIdController.text.isEmpty ||
        _userIdController.text.isEmpty) {
      showToast('Please fill all fields');
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
              Text(
                'Email Service Settings',
                style: GoogleFonts.poppins(color: Colors.white),
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
                showToast('Settings saved');
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
                          decoration: const InputDecoration(
                            hintText:
                                'Enter your daily activities here...\nClick "Add Point" to add bullet points',
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(
                              Icons.edit_note,
                              color: Colors.amber,
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
