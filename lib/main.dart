import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

/// ============================================================
/// METERING ZW CONFIGURATION
/// ============================================================

const String apiUrl = 'http://192.168.1.249:3000';

const String companyName = 'New Sahara Ventures';
const String siteName = 'Sabi 5.6MW Plant';
const String zimbabweTimezone = 'Africa/Harare';

const String zesaWhatsAppNumber = '263786339008';

const int inverterCount = 16;

/// Meter readings are taken hourly from 07:00 to 18:00.
const List<int> meteringHours = [
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
];

/// NCC reporting blocks.
const List<Map<String, int>> nccPeriods = [
  {
    'start': 7,
    'end': 10,
  },
  {
    'start': 11,
    'end': 14,
  },
  {
    'start': 15,
    'end': 18,
  },
];

/// ============================================================
/// MAIN
/// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  runApp(const MeteringZW());
}

/// ============================================================
/// APPLICATION
/// ============================================================

class MeteringZW extends StatelessWidget {
  const MeteringZW({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Metering ZW',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5CAD),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(),
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

/// ============================================================
/// UTILITIES
/// ============================================================

tz.Location zimbabweLocation() {
  try {
    return tz.getLocation(zimbabweTimezone);
  } catch (_) {
    return tz.UTC;
  }
}

DateTime zimNow() {
  return tz.TZDateTime.now(zimbabweLocation());
}

String formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String hourLabel(int hour) {
  return '${hour.toString().padLeft(2, '0')}:00';
}

double parseDouble(dynamic value) {
  return double.tryParse('$value') ?? 0;
}

double? parseNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  final text = '$value'.trim();

  if (text.isEmpty || text == 'null') {
    return null;
  }

  return double.tryParse(text);
}

String threeDecimals(dynamic value) {
  final number = double.tryParse(value.toString()) ?? 0;
  return number.toStringAsFixed(3);
}

void showSnack(
  BuildContext context,
  String message, {
  Color? color,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Convert cumulative meter difference from kWh to MWh.
double kwhDifferenceToMwh(
  double current,
  double previous,
) {
  return (current - previous) / 1000;
}

/// ============================================================
/// API SERVICE
/// ============================================================

class ApiService {
  static Map<String, String> headers(String? token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> login(
    String email,
    String password,
  ) {
    return http
        .post(
          Uri.parse('$apiUrl/api/auth/login'),
          headers: headers(null),
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> register(
    String name,
    String email,
    String password,
  ) {
    return http
        .post(
          Uri.parse('$apiUrl/api/auth/register'),
          headers: headers(null),
          body: jsonEncode({
            'full_name': name,
            'email': email,
            'password': password,
            'company': companyName,
            'site': siteName,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> getDashboard(
    String token,
  ) {
    return http
        .get(
          Uri.parse(
            '$apiUrl/api/dashboard'
            '?company=${Uri.encodeComponent(companyName)}'
            '&site=${Uri.encodeComponent(siteName)}',
          ),
          headers: headers(token),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> getMetering(
    String token,
    String date,
  ) {
    return http
        .get(
          Uri.parse(
            '$apiUrl/api/metering'
            '?site=${Uri.encodeComponent(siteName)}'
            '&date=$date',
          ),
          headers: headers(token),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> getPreviousReading(
    String token,
    String date,
    int hour,
  ) {
    return http
        .get(
          Uri.parse(
            '$apiUrl/api/metering/previous'
            '?site=${Uri.encodeComponent(siteName)}'
            '&date=$date'
            '&hour=$hour',
          ),
          headers: headers(token),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> saveMeterReading({
    required String token,
    required String date,
    required int hour,
    required double currentReading,
  }) {
    return http
        .post(
          Uri.parse('$apiUrl/api/metering'),
          headers: headers(token),
          body: jsonEncode({
            'company': companyName,
            'site': siteName,
            'date': date,
            'hour': hour,
            'current_reading': currentReading,
            'timezone': zimbabweTimezone,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> getInverters(
    String token,
    String date,
  ) {
    return http
        .get(
          Uri.parse(
            '$apiUrl/api/inverters'
            '?site=${Uri.encodeComponent(siteName)}'
            '&date=$date',
          ),
          headers: headers(token),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> saveInverterReadings({
    required String token,
    required String date,
    required List<Map<String, dynamic>> readings,
  }) {
    return http
        .post(
          Uri.parse('$apiUrl/api/inverters'),
          headers: headers(token),
          body: jsonEncode({
            'company': companyName,
            'site': siteName,
            'date': date,
            'timezone': zimbabweTimezone,
            'readings': readings,
          }),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> getReports({
    required String token,
    required String from,
    required String to,
  }) {
    return http
        .get(
          Uri.parse(
            '$apiUrl/api/reports'
            '?site=${Uri.encodeComponent(siteName)}'
            '&from=$from'
            '&to=$to',
          ),
          headers: headers(token),
        )
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> getAnalytics({
    required String token,
    required String from,
    required String to,
  }) {
    return http
        .get(
          Uri.parse(
            '$apiUrl/api/analytics'
            '?site=${Uri.encodeComponent(siteName)}'
            '&from=$from'
            '&to=$to',
          ),
          headers: headers(token),
        )
        .timeout(const Duration(seconds: 15));
  }
}

/// ============================================================
/// SAFE JSON
/// ============================================================

Map<String, dynamic> decodeObject(String body) {
  try {
    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  } catch (_) {
    return {};
  }
}

/// ============================================================
/// LOGIN
/// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showSnack(
        context,
        'Enter email and password.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await ApiService.login(
        email,
        password,
      );

      final data = decodeObject(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final token = '${data['token'] ?? ''}';

        if (token.isEmpty) {
          showSnack(
            context,
            'Login succeeded but no token was returned.',
            color: Colors.red,
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardShell(
              token: token,
              user: data['user'] is Map
                  ? Map<String, dynamic>.from(
                      data['user'],
                    )
                  : {},
            ),
          ),
        );
      } else {
        showSnack(
          context,
          data['message']?.toString() ??
              'Login failed.',
          color: Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        showSnack(
          context,
          'Unable to connect to the server.',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.electric_meter,
                    size: 85,
                    color: Color(0xFF0B5CAD),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Metering ZW',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    companyName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    siteName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 35),
                  TextField(
                    controller: emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(
                      labelText: 'Email',
                      prefixIcon:
                          Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                          const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility
                              : Icons
                                  .visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword =
                                !obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          loading ? null : login,
                      child: loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(),
                            )
                          : const Text('LOGIN'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const RegistrationPage(),
                              ),
                            );
                          },
                    child: const Text(
                      'Create Account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// REGISTRATION
/// ============================================================

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() =>
      _RegistrationPageState();
}

class _RegistrationPageState
    extends State<RegistrationPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController =
      TextEditingController();

  bool loading = false;

  Future<void> register() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showSnack(
        context,
        'Complete all fields.',
      );
      return;
    }

    if (passwordController.text.length < 6) {
      showSnack(
        context,
        'Password must be at least 6 characters.',
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response =
          await ApiService.register(
        nameController.text.trim(),
        emailController.text.trim(),
        passwordController.text,
      );

      final data = decodeObject(response.body);

      if (!mounted) return;

      if (response.statusCode == 201) {
        showSnack(
          context,
          'Account created successfully.',
          color: Colors.green,
        );

        Navigator.pop(context);
      } else {
        showSnack(
          context,
          data['message']?.toString() ??
              'Registration failed.',
          color: Colors.red,
        );
      }
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          'Unable to connect to the server.',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 550,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.person_add,
                  size: 70,
                  color: Color(0xFF0B5CAD),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon:
                        Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText: 'Email',
                    prefixIcon:
                        Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller:
                      passwordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(
                    labelText: 'Password',
                    prefixIcon:
                        Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 15),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.business,
                    ),
                    title:
                        const Text('Company'),
                    subtitle:
                        const Text(companyName),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on,
                    ),
                    title:
                        const Text('Site'),
                    subtitle:
                        const Text(siteName),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        loading ? null : register,
                    child: loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(),
                          )
                        : const Text(
                            'REGISTER',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// DASHBOARD SHELL
/// ============================================================

class DashboardShell extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const DashboardShell({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<DashboardShell> createState() =>
      _DashboardShellState();
}

class _DashboardShellState
    extends State<DashboardShell> {
  int selectedIndex = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();

    pages = [
      DashboardHome(
        token: widget.token,
      ),
      DailyMeteringPage(
        token: widget.token,
      ),
      InverterReadingsPage(
        token: widget.token,
      ),
      ReportsPage(
        token: widget.token,
      ),
      AnalyticsPage(
        token: widget.token,
      ),
    ];
  }

  void logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Dashboard',
      'Daily Metering',
      'Inverter Readings',
      'Reports',
      'Analytics',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  20,
                ),
                decoration:
                    const BoxDecoration(
                  color: Color(0xFF0B5CAD),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.electric_meter,
                      color: Colors.white,
                      size: 42,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Metering ZW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      companyName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      siteName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              _drawerItem(
                Icons.dashboard,
                'Dashboard',
                0,
              ),
              _drawerItem(
                Icons.speed,
                'Daily Metering',
                1,
              ),
              _drawerItem(
                Icons.solar_power,
                'Inverter Readings',
                2,
              ),
              const Divider(),
              _drawerItem(
                Icons.assessment,
                'Reports',
                3,
              ),
              _drawerItem(
                Icons.analytics,
                'Analytics',
                4,
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.logout),
                title:
                    const Text('Logout'),
                onTap: logout,
              ),
            ],
          ),
        ),
      ),
      body: pages[selectedIndex],
    );
  }

  Widget _drawerItem(
    IconData icon,
    String title,
    int index,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selectedIndex == index,
      onTap: () {
        setState(() {
          selectedIndex = index;
        });

        Navigator.pop(context);
      },
    );
  }
}

/// ============================================================
/// DASHBOARD HOME
/// ============================================================

class DashboardHome extends StatefulWidget {
  final String token;

  const DashboardHome({
    super.key,
    required this.token,
  });

  @override
  State<DashboardHome> createState() =>
      _DashboardHomeState();
}

class _DashboardHomeState
    extends State<DashboardHome> {
  bool loading = true;

  double todayGeneration = 0;
  double monthGeneration = 0;
  double averageGeneration = 0;
  double maximumGeneration = 0;
  double minimumGeneration = 0;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final response =
          await ApiService.getDashboard(
        widget.token,
      );

      if (response.statusCode == 200) {
        final data =
            decodeObject(response.body);

        if (!mounted) return;

        setState(() {
          todayGeneration =
              parseDouble(
            data['today_generation'],
          );

          monthGeneration =
              parseDouble(
            data['month_generation'],
          );

          averageGeneration =
              parseDouble(
            data['average_generation'],
          );

          maximumGeneration =
              parseDouble(
            data['maximum_generation'],
          );

          minimumGeneration =
              parseDouble(
            data['minimum_generation'],
          );

          loading = false;
        });
      } else {
        if (mounted) {
          setState(() => loading = false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = zimNow();

    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            siteName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Zimbabwe time: '
            '${formatDate(now)} ${formatTime(now)}',
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          if (loading)
            const Center(
              child:
                  CircularProgressIndicator(),
            )
          else ...[
            _statCard(
              'Today',
              '${todayGeneration.toStringAsFixed(3)} KWh',
              Icons.today,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _statCard(
              'This Month',
              '${monthGeneration.toStringAsFixed(3)} KWh',
              Icons.calendar_month,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _statCard(
              'Average Day',
              '${averageGeneration.toStringAsFixed(3)} KWh',
              Icons.show_chart,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _statCard(
              'Highest Day',
              '${maximumGeneration.toStringAsFixed(3)} Kwh',
              Icons.arrow_upward,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _statCard(
              'Lowest Day',
              '${minimumGeneration.toStringAsFixed(3)} Kwh',
              Icons.arrow_downward,
              Colors.red,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor:
              color.withOpacity(.12),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// DAILY METERING
/// ============================================================

class DailyMeteringPage extends StatefulWidget {
  final String token;

  const DailyMeteringPage({
    super.key,
    required this.token,
  });

  @override
  State<DailyMeteringPage> createState() =>
      _DailyMeteringPageState();
}

class _DailyMeteringPageState
    extends State<DailyMeteringPage> {
  final Map<int, TextEditingController>
      controllers = {};

  final Map<int, double?> previousReadings =
      {};

  final Map<int, double?> currentReadings =
      {};

  /// Generation is stored in MWh.
  final Map<int, double?> generation = {};

  bool loading = true;
  bool saving = false;

  DateTime selectedDate = zimNow();

  String selectedWeather = 'Sunny';

  String get dateString =>
      formatDate(selectedDate);

  @override
  void initState() {
    super.initState();

    for (final hour in meteringHours) {
      controllers[hour] =
          TextEditingController();
    }

    loadReadings();
  }

  /// ----------------------------------------------------------
  /// LOAD READINGS
  /// ----------------------------------------------------------

  Future<void> loadReadings() async {
    if (mounted) {
      setState(() => loading = true);
    }

    previousReadings.clear();
    currentReadings.clear();
    generation.clear();

    try {
      final response =
          await ApiService.getMetering(
        widget.token,
        dateString,
      );

      if (response.statusCode == 200) {
        final data =
            decodeObject(response.body);

        final rawReadings =
            data['readings'];

        if (rawReadings is List) {
          for (final raw in rawReadings) {
            if (raw is! Map) continue;

            final reading =
                Map<String, dynamic>.from(raw);

            final hour =
                int.tryParse(
              '${reading['hour']}',
            );

            if (hour == null ||
                !controllers
                    .containsKey(hour)) {
              continue;
            }

            final current =
                parseNullableDouble(
              reading['current_reading'],
            );

            final previous =
                parseNullableDouble(
              reading['previous_reading'],
            );

            if (current != null) {
              controllers[hour]!.text =
                  current.toString();
            }

            currentReadings[hour] =
                current;

            previousReadings[hour] =
                previous;

            if (current != null &&
                previous != null) {
              final value =
                  kwhDifferenceToMwh(
                current,
                previous,
              );

              generation[hour] =
                  value >= 0 ? value : 0;
            }
          }
        }
      }

      await loadPreviousReadings();
    } catch (_) {
      // The screen remains usable even if
      // the API has no data.
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  /// ----------------------------------------------------------
  /// AUTOMATIC PREVIOUS READINGS
  /// ----------------------------------------------------------

  Future<void> loadPreviousReadings() async {
    for (final hour in meteringHours) {
      if (currentReadings[hour] != null) {
        continue;
      }

      try {
        final response =
            await ApiService.getPreviousReading(
          widget.token,
          dateString,
          hour,
        );

        if (response.statusCode == 200) {
          final data =
              decodeObject(response.body);

          final previous =
              parseNullableDouble(
            data['previous_reading'],
          );

          previousReadings[hour] =
              previous;
        }
      } catch (_) {
        // Continue with other hours.
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// ----------------------------------------------------------
  /// SAVE METER READING
  /// ----------------------------------------------------------

  Future<void> saveHour(int hour) async {
    final controller =
        controllers[hour]!;

    final current =
        double.tryParse(
      controller.text.trim(),
    );

    if (current == null) {
      showSnack(
        context,
        'Enter a valid kWh reading for '
        '${hourLabel(hour)}.',
        color: Colors.red,
      );
      return;
    }

    if (current < 0) {
      showSnack(
        context,
        'Meter reading cannot be negative.',
        color: Colors.red,
      );
      return;
    }

    final previous =
        previousReadings[hour];

    if (previous != null &&
        current < previous) {
      showSnack(
        context,
        'Current reading cannot be lower '
        'than the previous reading.',
        color: Colors.red,
      );
      return;
    }

    setState(() => saving = true);

    try {
      final response =
          await ApiService.saveMeterReading(
        token: widget.token,
        date: dateString,
        hour: hour,
        currentReading: current,
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        currentReadings[hour] =
            current;

        if (previous != null) {
          final mwh =
              kwhDifferenceToMwh(
            current,
            previous,
          );

          generation[hour] =
              mwh >= 0 ? mwh : 0;
        }

        showSnack(
          context,
          '${hourLabel(hour)} reading saved.',
          color: Colors.green,
        );

        setState(() {});
      } else {
        final data =
            decodeObject(response.body);

        showSnack(
          context,
          data['message']?.toString() ??
              'Could not save reading.',
          color: Colors.red,
        );
      }
    } catch (_) {
      showSnack(
        context,
        'Server connection failed. '
        'Check that the API server is running '
        'and your phone can reach $apiUrl.',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  /// ----------------------------------------------------------
  /// TOTAL GENERATION
  /// ----------------------------------------------------------

  double get totalGeneration {
    return generation.values
        .whereType<double>()
        .fold(
          0,
          (sum, value) => sum + value,
        );
  }

  /// ----------------------------------------------------------
  /// DATE
  /// ----------------------------------------------------------

  Future<void> chooseDate() async {
    final picked =
        await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    selectedDate = tz.TZDateTime(
      zimbabweLocation(),
      picked.year,
      picked.month,
      picked.day,
    );

    for (final controller
        in controllers.values) {
      controller.clear();
    }

    previousReadings.clear();
    currentReadings.clear();
    generation.clear();

    await loadReadings();
  }

  /// ----------------------------------------------------------
  /// NCC HELPERS
  /// ----------------------------------------------------------

  bool nccPeriodReady(
    int startHour,
    int endHour,
  ) {
    for (
      int hour = startHour;
      hour <= endHour;
      hour++
    ) {
      if (generation[hour] == null) {
        return false;
      }
    }

    return true;
  }

  String nccGreeting(
    int startHour,
  ) {
    if (startHour <= 10) {
      return 'Good morning';
    }

    if (startHour <= 14) {
      return 'Good afternoon';
    }

    return 'Good afternoon';
  }

  String weatherDescription() {
    return '4 hours $selectedWeather';
  }

  /// ----------------------------------------------------------
  /// CREATE WHATSAPP NCC REPORT
  /// ----------------------------------------------------------

  String buildNccMessage({
    required int startHour,
    required int endHour,
  }) {
    double total = 0;

    final hourlyLines = <String>[];

    for (
      int hour = startHour;
      hour <= endHour;
      hour++
    ) {
      final value =
          generation[hour] ?? 0;

      total += value;

      hourlyLines.add(
        '${hourLabel(hour)} - '
        '${value.toStringAsFixed(3)} MWh',
      );
    }

    return [
      nccGreeting(startHour),
      '',
      dateString,
      '',
      'SABI GM Solar Project Production Report',
      '',
      '${hourLabel(startHour)} to '
          '${hourLabel(endHour)}',
      '',
      ...hourlyLines,
      '',
      'Total MWh: '
          '${total.toStringAsFixed(3)} MWh',
      '',
      'Weather: ${weatherDescription()}',
    ].join('\n');
  }

  /// ----------------------------------------------------------
  /// OPEN WHATSAPP
  /// ----------------------------------------------------------

  Future<void> sendNccWhatsApp({
    required int startHour,
    required int endHour,
  }) async {
    if (!nccPeriodReady(
      startHour,
      endHour,
    )) {
      showSnack(
        context,
        'Please save all readings from '
        '${hourLabel(startHour)} to '
        '${hourLabel(endHour)} first.',
        color: Colors.orange,
      );
      return;
    }

    final message = buildNccMessage(
      startHour: startHour,
      endHour: endHour,
    );

    final uri = Uri.parse(
      'https://wa.me/$zesaWhatsAppNumber'
      '?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched =
          await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        showSnack(
          context,
          'Could not open WhatsApp.',
          color: Colors.red,
        );
      }
    } catch (_) {
      if (mounted) {
        showSnack(
          context,
          'Unable to open WhatsApp.',
          color: Colors.red,
        );
      }
    }
  }

  /// ----------------------------------------------------------
  /// NCC CARD
  /// ----------------------------------------------------------

  Widget buildNccCard({
    required int startHour,
    required int endHour,
  }) {
    final ready = nccPeriodReady(
      startHour,
      endHour,
    );

    double total = 0;

    for (
      int hour = startHour;
      hour <= endHour;
      hour++
    ) {
      total += generation[hour] ?? 0;
    }

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      color: ready
          ? Colors.green.shade50
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.send,
                  color: ready
                      ? Colors.green
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NCC '
                    '${hourLabel(startHour)}–'
                    '${hourLabel(endHour)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ready
                  ? 'Production report ready'
                  : 'Save all four meter readings '
                    'to activate NCC.',
              style: TextStyle(
                color: ready
                    ? Colors.green.shade800
                    : Colors.grey.shade700,
              ),
            ),
            if (ready) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    for (
                      int hour = startHour;
                      hour <= endHour;
                      hour++
                    )
                      Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 3,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                hourLabel(hour),
                              ),
                            ),
                            Text(
                              '${(generation[hour] ?? 0).toStringAsFixed(2)} MWh',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${total.toStringAsFixed(2)} MWh',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child:
                    ElevatedButton.icon(
                  onPressed: () {
                    sendNccWhatsApp(
                      startHour: startHour,
                      endHour: endHour,
                    );
                  },
                  icon: const Icon(
                    Icons.message,
                  ),
                  label: const Text(
                    'NCC – OPEN WHATSAPP',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ----------------------------------------------------------
  /// BUILD
  /// ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadReadings,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Metering',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$siteName • $dateString',
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: chooseDate,
                icon: const Icon(
                  Icons.calendar_month,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding:
                  const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Meter readings are entered in kWh. '
                      'Generation is calculated as the '
                      'difference between current and '
                      'previous readings, then divided '
                      'by 1,000 to produce MWh.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding:
                  const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.schedule,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '07:00 automatically uses the '
                      'previous day 18:00 meter reading '
                      'as its previous reading.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(14),
              child: DropdownButtonFormField<
                  String>(
                value: selectedWeather,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Weather for NCC period',
                  prefixIcon:
                      Icon(Icons.cloud),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Sunny',
                    child: Text('Sunny'),
                  ),
                  DropdownMenuItem(
                    value: 'Cloudy',
                    child: Text('Cloudy'),
                  ),
                  DropdownMenuItem(
                    value: 'Raining',
                    child: Text('Raining'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedWeather =
                        value;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (loading)
            const Padding(
              padding:
                  EdgeInsets.all(30),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else
            ...meteringHours.map(
              (hour) => _hourCard(hour),
            ),

          const SizedBox(height: 8),

          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text(
                    'Total Recorded Generation',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${totalGeneration.toStringAsFixed(2)} MWh',
                    textAlign:
                        TextAlign.center,
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight:
                          FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'NCC Production Reports',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'NCC reports are prepared in four-hour '
            'blocks and opened in WhatsApp for review '
            'before sending.',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 12),

          for (final period in nccPeriods)
            buildNccCard(
              startHour: period['start']!,
              endHour: period['end']!,
            ),
        ],
      ),
    );
  }

  /// ----------------------------------------------------------
  /// HOURLY METER CARD
  /// ----------------------------------------------------------

  Widget _hourCard(int hour) {
    final previous =
        previousReadings[hour];

    final produced =
        generation[hour];

    final current =
        currentReadings[hour];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      const Color(
                    0xFF0B5CAD,
                  ).withOpacity(.10),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color:
                          Color(0xFF0B5CAD),
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${hourLabel(hour)} Meter Reading',
                    style:
                        const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final narrow =
                    constraints.maxWidth <
                        500;

                if (narrow) {
                  return Column(
                    children: [
                      _readingBox(
                        'Previous',
                        previous == null
                            ? hour == 7
                                ? 'Auto: prev day 18:00'
                                : 'Not available'
                            : '${previous.toStringAsFixed(2)} kWh',
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      _currentField(
                        hour,
                        current,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _readingBox(
                        'Previous',
                        previous == null
                            ? hour == 7
                                ? 'Auto: prev day 18:00'
                                : 'Not available'
                            : '${previous.toStringAsFixed(2)} kWh',
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: _currentField(
                        hour,
                        current,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: produced == null
                    ? Colors.grey.shade100
                    : Colors.green.shade50,
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      produced == null
                          ? 'Generation: —'
                          : 'Generation: '
                            '${produced.toStringAsFixed(2)} MWh',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        color: produced ==
                                null
                            ? Colors.grey
                            : Colors.green
                                .shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed:
                    saving
                        ? null
                        : () => saveHour(
                              hour,
                            ),
                icon: const Icon(
                  Icons.save,
                ),
                label: Text(
                  'SAVE ${hourLabel(hour)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentField(
    int hour,
    double? current,
  ) {
    return TextField(
      controller: controllers[hour],
      keyboardType:
          const TextInputType.numberWithOptions(
        decimal: true,
      ),
      decoration:
          const InputDecoration(
        labelText: 'Current meter reading',
        helperText: 'Enter kWh',
        suffixText: 'kWh',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _readingBox(
    String title,
    String value,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 72,
      ),
      width: double.infinity,
      padding:
          const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade400,
        ),
        borderRadius:
            BorderRadius.circular(6),
        color: Colors.grey.shade50,
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final controller
        in controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }
}

/// ============================================================
/// INVERTER READINGS
/// ============================================================

class InverterReadingsPage
    extends StatefulWidget {
  final String token;

  const InverterReadingsPage({
    super.key,
    required this.token,
  });

  @override
  State<InverterReadingsPage> createState() =>
      _InverterReadingsPageState();
}

class _InverterReadingsPageState
    extends State<InverterReadingsPage> {
  final List<TextEditingController>
      controllers = [];

  DateTime selectedDate = zimNow();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();

    for (
      int i = 0;
      i < inverterCount;
      i++
    ) {
      controllers.add(
        TextEditingController(),
      );
    }

    loadReadings();
  }

  String get dateString =>
      formatDate(selectedDate);

  Future<void> loadReadings() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final response =
          await ApiService.getInverters(
        widget.token,
        dateString,
      );

      if (response.statusCode == 200) {
        final data =
            decodeObject(response.body);

        final rawReadings =
            data['readings'];

        if (rawReadings is List) {
          for (final raw in rawReadings) {
            if (raw is! Map) continue;

            final reading =
                Map<String, dynamic>.from(
              raw,
            );

            final number =
                int.tryParse(
              '${reading['inverter_number']}',
            );

            if (number == null ||
                number < 1 ||
                number > inverterCount) {
              continue;
            }

            controllers[number - 1]
                    .text =
                '${reading['reading'] ?? ''}';
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveReadings() async {
    final readings =
        <Map<String, dynamic>>[];

    for (
      int i = 0;
      i < inverterCount;
      i++
    ) {
      final text =
          controllers[i].text.trim();

      final value =
          double.tryParse(text);

      if (value == null) {
        showSnack(
          context,
          'Enter a valid reading for '
          'Inverter ${i + 1}.',
          color: Colors.red,
        );
        return;
      }

      if (value < 0) {
        showSnack(
          context,
          'Inverter readings cannot be negative.',
          color: Colors.red,
        );
        return;
      }

      readings.add({
        'inverter_number': i + 1,
        'reading': value,
      });
    }

    setState(() => saving = true);

    try {
      final response =
          await ApiService
              .saveInverterReadings(
        token: widget.token,
        date: dateString,
        readings: readings,
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        showSnack(
          context,
          'All 16 inverter readings saved.',
          color: Colors.green,
        );
      } else {
        final data =
            decodeObject(response.body);

        showSnack(
          context,
          data['message']?.toString() ??
              'Could not save inverter readings.',
          color: Colors.red,
        );
      }
    } catch (_) {
      showSnack(
        context,
        'Server connection failed. '
        'Check that the API server is running '
        'and your phone can reach $apiUrl.',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> chooseDate() async {
    final picked =
        await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    selectedDate = tz.TZDateTime(
      zimbabweLocation(),
      picked.year,
      picked.month,
      picked.day,
    );

    await loadReadings();
  }

  @override
  void dispose() {
    for (final controller
        in controllers) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadReadings,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Inverter Readings',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: chooseDate,
                icon: const Icon(
                  Icons.calendar_month,
                ),
              ),
            ],
          ),

          Text(
            '16 inverters • End-of-day • '
            '$dateString',
          ),

          const SizedBox(height: 14),

          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter the end-of-day reading '
                      'for each of the 16 Sabi inverters.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (loading)
            const Center(
              child:
                  CircularProgressIndicator(),
            )
          else
            ...List.generate(
              inverterCount,
              (index) => Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.all(12),
                  child: TextField(
                    controller:
                        controllers[index],
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        InputDecoration(
                      labelText:
                          'Inverter ${index + 1}',
                      prefixIcon:
                          const Icon(
                        Icons.solar_power,
                      ),
                      suffixText: 'MWh',
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          SizedBox(
            height: 52,
            child:
                ElevatedButton.icon(
              onPressed:
                  saving
                      ? null
                      : saveReadings,
              icon: const Icon(
                Icons.save,
              ),
              label: saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(),
                    )
                  : const Text(
                      'SAVE ALL 16 INVERTERS',
                    ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// ============================================================
/// REPORTS
/// ============================================================

class ReportsPage extends StatefulWidget {
  final String token;

  const ReportsPage({
    super.key,
    required this.token,
  });

  @override
  State<ReportsPage> createState() =>
      _ReportsPageState();
}

class _ReportsPageState
    extends State<ReportsPage> {
  DateTime from =
      zimNow().subtract(
    const Duration(days: 30),
  );

  DateTime to = zimNow();

  bool loading = false;

  List<dynamic> days = [];

  double total = 0;
  double average = 0;
  double highest = 0;
  double lowest = 0;

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final response =
          await ApiService.getReports(
        token: widget.token,
        from: formatDate(from),
        to: formatDate(to),
      );

      if (response.statusCode == 200) {
        final data =
            decodeObject(response.body);

        if (!mounted) return;

        setState(() {
          days = data['days'] is List
              ? data['days']
              : [];

          total =
              parseDouble(data['total']);

          average =
              parseDouble(data['average']);

          highest =
              parseDouble(data['highest']);

          lowest =
              parseDouble(data['lowest']);
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadReport,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Generation Reports',
            style: TextStyle(
              fontSize: 27,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _summaryCard(
            'Total Generation',
            total,
            Colors.blue,
          ),
          const SizedBox(height: 10),
          _summaryCard(
            'Average Daily Generation',
            average,
            Colors.orange,
          ),
          const SizedBox(height: 10),
          _summaryCard(
            'Highest Generation',
            highest,
            Colors.green,
          ),
          const SizedBox(height: 10),
          _summaryCard(
            'Lowest Generation',
            lowest,
            Colors.red,
          ),
          const SizedBox(height: 20),
          const Text(
            'Daily Generation',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const Center(
              child:
                  CircularProgressIndicator(),
            ),
          if (!loading && days.isEmpty)
            const Card(
              child: Padding(
                padding:
                    EdgeInsets.all(20),
                child: Text(
                  'No generation records found.',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            ),
          ...days.map(
            (day) {
              if (day is! Map) {
                return const SizedBox.shrink();
              }

              final value =
                  parseDouble(
                day['generation'],
              );

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 8,
                ),
                child: ListTile(
                  leading:
                      const Icon(
                    Icons.calendar_today,
                  ),
                  title: Text(
                    '${day['date'] ?? ''}',
                  ),
                  trailing: Text(
                    '${value.toStringAsFixed(2)} MWh',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    String title,
    double value,
    Color color,
  ) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor:
              color.withOpacity(.12),
          child: Icon(
            Icons.bar_chart,
            color: color,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          '${value.toStringAsFixed(2)} MWh',
          style: const TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// ANALYTICS
/// ============================================================

class AnalyticsPage
    extends StatefulWidget {
  final String token;

  const AnalyticsPage({
    super.key,
    required this.token,
  });

  @override
  State<AnalyticsPage> createState() =>
      _AnalyticsPageState();
}

class _AnalyticsPageState
    extends State<AnalyticsPage> {
  bool loading = true;

  double average = 0;
  double highest = 0;
  double lowest = 0;
  double total = 0;

  String highestDay = '—';
  String lowestDay = '—';

  int highDays = 0;
  int lowDays = 0;

  @override
  void initState() {
    super.initState();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    final now = zimNow();

    final from = formatDate(
      now.subtract(
        const Duration(days: 30),
      ),
    );

    final to = formatDate(now);

    try {
      final response =
          await ApiService.getAnalytics(
        token: widget.token,
        from: from,
        to: to,
      );

      if (response.statusCode == 200) {
        final data =
            decodeObject(response.body);

        if (!mounted) return;

        setState(() {
          average =
              parseDouble(data['average']);

          highest =
              parseDouble(data['highest']);

          lowest =
              parseDouble(data['lowest']);

          total =
              parseDouble(data['total']);

          highestDay =
              '${data['highest_day'] ?? '—'}';

          lowestDay =
              '${data['lowest_day'] ?? '—'}';

          highDays =
              int.tryParse(
                    '${data['high_days'] ?? 0}',
                  ) ??
                  0;

          lowDays =
              int.tryParse(
                    '${data['low_days'] ?? 0}',
                  ) ??
                  0;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadAnalytics,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Power Generation Analytics',
            style: TextStyle(
              fontSize: 27,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Last 30 days',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          if (loading)
            const Center(
              child:
                  CircularProgressIndicator(),
            ),
          const SizedBox(height: 10),
          _analyticsCard(
            'Total Generation',
            '${total.toStringAsFixed(2)} MWh',
            Icons.bolt,
            Colors.blue,
          ),
          const SizedBox(height: 10),
          _analyticsCard(
            'Average Daily Generation',
            '${average.toStringAsFixed(2)} MWh',
            Icons.show_chart,
            Colors.orange,
          ),
          const SizedBox(height: 10),
          _analyticsCard(
            'Highest Generation',
            '${highest.toStringAsFixed(2)} MWh',
            Icons.trending_up,
            Colors.green,
          ),
          const SizedBox(height: 5),
          Card(
            child: ListTile(
              leading:
                  const Icon(
                Icons.arrow_upward,
                color: Colors.green,
              ),
              title: const Text(
                'Highest Generation Day',
              ),
              subtitle:
                  Text(highestDay),
            ),
          ),
          const SizedBox(height: 10),
          _analyticsCard(
            'Lowest Generation',
            '${lowest.toStringAsFixed(2)} MWh',
            Icons.trending_down,
            Colors.red,
          ),
          const SizedBox(height: 5),
          Card(
            child: ListTile(
              leading:
                  const Icon(
                Icons.arrow_downward,
                color: Colors.red,
              ),
              title: const Text(
                'Lowest Generation Day',
              ),
              subtitle:
                  Text(lowestDay),
            ),
          ),
          const SizedBox(height: 15),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(
                    Icons.arrow_upward,
                    color: Colors.green,
                  ),
                  title: const Text(
                    'High Generation Days',
                  ),
                  trailing: Text(
                    '$highDays days',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                ),
                ListTile(
                  leading:
                      const Icon(
                    Icons.arrow_downward,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Low Generation Days',
                  ),
                  trailing: Text(
                    '$lowDays days',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor:
              color.withOpacity(.12),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
