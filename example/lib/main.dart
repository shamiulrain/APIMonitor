import 'package:api_monitor/api_monitor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  ApiMonitor.instance.start(
    logToConsole: true,
    theme: const ApiMonitorTheme.light(),
  );
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APIMonitor demo',
      debugShowCheckedModeBanner: false,
      // Installing the overlay as `builder` keeps it above every route.
      builder: (context, child) => ApiMonitorOverlay(child: child!),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Dio _dio;
  late final http.Client _client;
  String _status = 'Ready — shake or tap the bubble to inspect.';

  @override
  void initState() {
    super.initState();
    // The global interceptor already catches these; attaching the Dio
    // interceptor gives richer bodies and is de-duplicated automatically.
    _dio = ApiMonitor.instance.attachDio(
      Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com')),
    );
    _client = ApiMonitor.instance.createHttpClient();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _status = '$label…');
    try {
      await action();
      if (mounted) setState(() => _status = '$label ✓');
    } catch (error) {
      if (mounted) setState(() => _status = '$label failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('APIMonitor demo'),
        actions: [
          IconButton(
            tooltip: 'Open inspector',
            icon: const Icon(Icons.wifi_tethering),
            onPressed: () => ApiMonitor.instance.show(context: context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_status, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          _Action(
            label: 'GET via Dio',
            onTap: () => _run('GET via Dio', () => _dio.get<dynamic>('/posts/1')),
          ),
          _Action(
            label: 'POST via Dio',
            onTap: () => _run(
              'POST via Dio',
              () => _dio.post<dynamic>(
                '/posts',
                data: {'title': 'hello', 'body': 'world', 'userId': 1},
              ),
            ),
          ),
          _Action(
            label: 'GET via package:http',
            onTap: () => _run(
              'GET via package:http',
              () => _client.get(
                Uri.parse('https://jsonplaceholder.typicode.com/todos/1'),
              ),
            ),
          ),
          _Action(
            label: 'Trigger a 404',
            onTap: () => _run(
              'Trigger a 404',
              () => _client.get(
                Uri.parse('https://jsonplaceholder.typicode.com/does-not-exist'),
              ),
            ),
          ),
          _Action(
            label: 'Load an image (Image.network)',
            onTap: () => _run(
              'Load an image',
              () => precacheImage(
                const NetworkImage('https://picsum.photos/seed/apimonitor/400'),
                context,
              ),
            ),
          ),
          _Action(
            label: 'Clear captured data',
            onTap: () async {
              ApiMonitor.instance.clear();
              if (mounted) setState(() => _status = 'Cleared');
            },
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: onTap,
          child: Text(label),
        ),
      ),
    );
  }
}
