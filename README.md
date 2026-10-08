# APIMonitor

<p>
  <a href="https://pub.dev/packages/api_monitor"><img src="https://img.shields.io/pub/v/api_monitor.svg" alt="pub version"></a>
  <a href="https://pub.dev/packages/api_monitor"><img src="https://img.shields.io/pub/points/api_monitor" alt="pub points"></a>
  <a href="https://pub.dev/packages/api_monitor"><img src="https://img.shields.io/pub/likes/api_monitor" alt="pub likes"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/platform-flutter-02569B.svg" alt="platform: Flutter"></a>
</p>

An **in-app network inspector for Flutter**. Capture, inspect, search and share
every HTTP request your app makes — right on the device, no proxy and no desktop
tooling required.

One line of setup, a draggable floating bubble, shake-to-open, and a full
request/response browser with search, statistics and log sharing.

## Features

| Feature | Supported |
|---|---|
| One-line `start()` / `stop()` | ✅ |
| Captures **all** `dart:io` traffic (`package:http`, Dio, `Image.network`, any lib) | ✅ |
| Explicit Dio interceptor and `package:http` client | ✅ |
| Shake-to-open gesture | ✅ |
| Draggable floating debug bubble | ✅ |
| Request list with method, status, duration, size | ✅ |
| Detail view: headers, bodies, timing, error | ✅ |
| Pretty-printed JSON / XML / HTML, image previews | ✅ |
| Search (URL, method, status, body) | ✅ |
| Filter by response type | ✅ |
| Statistics (counts, average/slowest time, size, top hosts) | ✅ |
| Share as simple log / JSON / cURL | ✅ |
| Copy a request as cURL | ✅ |
| Ignore URLs | ✅ |
| Enable/disable & clear from the UI | ✅ |
| App info (version, build, platform) | ✅ |
| Light/dark theming | ✅ |

## Getting started

### 1. Add the dependency

From pub.dev (recommended once published):

```yaml
dependencies:
  api_monitor: ^0.1.0
```

Or from a local path while developing:

```yaml
dependencies:
  api_monitor:
    path: ../APIMonitor
```

Or straight from Git:

```yaml
dependencies:
  api_monitor:
    git:
      url: https://github.com/shamiulrain/APIMonitor.git
      ref: main
```

### 2. Start the monitor

```dart
import 'package:api_monitor/api_monitor.dart';

void main() {
  ApiMonitor.instance.start();
  runApp(const MyApp());
}
```

### 3. Install the overlay

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Installing the overlay here keeps it above every route.
      builder: (context, child) => ApiMonitorOverlay(child: child!),
      home: const HomePage(),
    );
  }
}
```

That's it. Make a request and shake the device (or tap the floating bubble) to
open the inspector.

## Usage

### Capturing requests

By default `start()` installs a process-wide `HttpOverrides` that records every
request made through `dart:io` — this covers `package:http`, Dio's default
adapter, `Image.network` and any other library built on `dart:io`.

If you prefer explicit integrations (or want richer bodies), add them:

```dart
// Dio
final dio = Dio();
dio.interceptors.add(ApiMonitor.instance.dioInterceptor);
// or: ApiMonitor.instance.attachDio(dio);

// package:http
final client = ApiMonitor.instance.createHttpClient();
```

These are de-duplicated automatically, so a request is never logged twice even
if both the global interceptor and an explicit integration are active. To use
explicit integrations only:

```dart
ApiMonitor.instance.start(globalCapture: false);
```

### Opening the inspector

```dart
ApiMonitor.instance.show();    // slide the overlay in
ApiMonitor.instance.hide();    // slide it out
ApiMonitor.instance.toggle();
```

`show()` / `hide()` work from anywhere once `ApiMonitorOverlay` is installed. You
can also call `ApiMonitor.instance.show(context: context)`.

### Ignoring URLs

```dart
ApiMonitor.instance.ignoreURL('https://analytics.example.com'); // whole host
ApiMonitor.instance.ignoreURL('https://api.example.com/health'); // one endpoint
```

### Configuration

```dart
ApiMonitor.instance.start(
  globalCapture: true,      // install the global HttpOverrides
  shakeToOpen: true,        // shake to open the inspector
  showFloatingButton: true, // show the draggable bubble
  logToConsole: true,       // also log captured calls via debugPrint
  theme: const ApiMonitorTheme.light(), // or .dark()
);

ApiMonitor.instance
  ..maxRecords = 250          // in-memory ring buffer size
  ..maxBodyLength = 20000     // text bodies are truncated to this length
  ..captureBodies = true;     // set false to store metadata only

// React to every capture:
ApiMonitor.instance.onRecord = (record) => debugPrint(record.url.toString());
```

Keep it out of release builds by wrapping the call in `kDebugMode`:

```dart
void main() {
  if (kDebugMode) ApiMonitor.instance.start();
  runApp(const MyApp());
}
```

> Note: `ApiMonitorOverlay` does not check `kDebugMode`, so also gate the
> `builder` (or pass `showFloatingButton: false`) if you want no UI in release.

### Stopping

```dart
ApiMonitor.instance.stop();             // restores HttpOverrides and clears data
ApiMonitor.instance.stop(clear: false); // keep captured data
```

## How it works

* **Global capture** wraps `HttpClient`, its requests and its responses to buffer
  bodies while staying fully transparent to callers.
* **Explicit integrations** feed the same `CapturePipeline`, which owns body
  handling, truncation and de-duplication.
* The **overlay** registers itself with `ApiMonitor` so `show()` / `hide()` need no
  `BuildContext`, and hosts a nested `Navigator` for the list → detail flow.

## Platform notes

* Global capture relies on `dart:io` `HttpOverrides`, so it works on **mobile and
  desktop** but **not on web** — on web, use the explicit Dio interceptor (or the
  `package:http` client) instead.
* Shake-to-open uses the accelerometer via `sensors_plus` and silently no-ops on
  platforms without one (desktop/web).
* Android release builds need the `INTERNET` permission in
  `android/app/src/main/AndroidManifest.xml` (Flutter only adds it to the debug
  and profile manifests by default).

## Example

See [`example/`](example) for a runnable demo that fires requests through Dio,
`package:http` and `Image.network`.

```bash
cd example
flutter run
```

## Contributing

Issues and pull requests are welcome at
[github.com/shamiulrain/APIMonitor](https://github.com/shamiulrain/APIMonitor).

## License

MIT.
