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
        primaryColor: const Color(0xFF2A5298),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2A5298),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            backgroundColor: const Color(0xFF2A5298),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
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
            borderSide: const BorderSide(color: Color(0xFF2A5298), width: 2),
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
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  final DateTime _now = DateTime.now();
  bool _isPremium = false;
  List<Report> _reports = [];
  int _currentIndex = 0;
  late TabController _tabController;
  bool _isLoading = true;
  int _reportCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Set default login time to 9:30 AM
    _loginTimeController.text = '9:30 AM';
    // Set default logout time to 5:30 PM
    _logoutTimeController.text = '5:30 PM';
    _loadReports();
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
        _isPremium = prefs.getBool('isPremium') ?? false;
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

  Future<void> upgradeToPremium() async {
    setState(() {
      _isPremium = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', true);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Premium Activated!',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('You now have access to:', style: GoogleFonts.poppins()),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: Color(0xFF2A5298),
                    ),
                    title: Text(
                      'Unlimited History',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF2A5298),
                    ),
                    title: Text(
                      'Enhanced Animations',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.analytics_outlined,
                      color: Color(0xFF2A5298),
                    ),
                    title: Text(
                      'Advanced Analytics',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),
              actions: [
                TextButton(
                  child: Text(
                    'Great!',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF2A5298),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            )
            .animate()
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 300.ms,
            )
            .fadeIn();
      },
    );
  }

  Future<void> sendEmail() async {
    if (_bodyController.text.isEmpty ||
        _loginTimeController.text.isEmpty ||
        _logoutTimeController.text.isEmpty) {
      showToast('Please fill all fields');
      return;
    }

    setState(() {
      _isSending = true;
    });

    const serviceId = 'service_po5m52c';
    const templateId = 'template_icnzmr9';
    const userId = 'ys6bmZUnz4w5hWi1g';

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
          if (!_isPremium && _reports.length > 5) {
            _reports = _reports.sublist(
              0,
              5,
            ); // Keep only 5 most recent for free users
          }
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Success'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your daily report has been sent successfully!'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Color(0xFF2A5298)),
                  const SizedBox(width: 8),
                  Text(
                    'Added to your report history',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.analytics, size: 16, color: Color(0xFF2A5298)),
                  const SizedBox(width: 8),
                  Text(
                    'Total reports sent: $_reportCount',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Delete Report'),
            ],
          ),
          content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.email_outlined, color: Color(0xFF2A5298))
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scaleXY(begin: 1, end: 1.1, duration: 2.seconds),
            const SizedBox(width: 10),
            Text(
              'DRmail',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2A5298),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          _isPremium
              ? Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade700, size: 16)
                          .animate(onPlay: (controller) => controller.repeat())
                          .rotate(duration: 3.seconds, begin: 0, end: 2),
                      const SizedBox(width: 4),
                      Text(
                        'PREMIUM',
                        style: GoogleFonts.poppins(
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : TextButton.icon(
                  onPressed: upgradeToPremium,
                  icon: Icon(Icons.star_border, color: Colors.amber.shade700)
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 1.5.seconds),
                  label: Text(
                    'Go Premium',
                    style: GoogleFonts.poppins(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF2A5298),
          labelColor: const Color(0xFF2A5298),
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: const Color(0xFF2A5298),
                              size: 24,
                            ).animate().fadeIn(duration: 300.ms),
                            const SizedBox(width: 10),
                            Text(
                                  'Daily Report',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
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
                            color: Colors.grey[600],
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
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _loginTimeController,
                                    decoration: const InputDecoration(
                                      hintText: '9:30 AM',
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final TimeOfDay? picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                          DateFormat('h:mm a').parse(_loginTimeController.text),
                                        ),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _loginTimeController.text = 
                                            DateFormat('h:mm a').format(
                                              DateTime(
                                                2022, 1, 1, 
                                                picked.hour, 
                                                picked.minute
                                              )
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
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _logoutTimeController,
                                    decoration: const InputDecoration(
                                      hintText: '5:30 PM',
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final TimeOfDay? picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.fromDateTime(
                                          DateFormat('h:mm a').parse(_logoutTimeController.text),
                                        ),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _logoutTimeController.text = 
                                            DateFormat('h:mm a').format(
                                              DateTime(
                                                2022, 1, 1, 
                                                picked.hour, 
                                                picked.minute
                                              )
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
                        Text(
                          'Daily Activities',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bodyController,
                          decoration: const InputDecoration(
                            hintText: 'Enter your daily activities here...',
                            prefixIcon: Icon(Icons.edit_note),
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
                            icon: _isSending 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
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
                          ),
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
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No reports yet',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey[600],
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
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      report.date,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20),
                                      onPressed: () => _showDeleteConfirmation(index),
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
                                      ),
                                    ),
                                    Text(report.loginTime),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Logout: ',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(report.logoutTime),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  report.body,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: (100 * index).ms);
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
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}