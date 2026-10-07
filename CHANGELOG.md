## 0.1.0

* Initial release — a Netfox-style in-app network inspector for Flutter.
* Global `HttpOverrides` capture for all `dart:io` traffic, plus explicit Dio
  interceptor and `package:http` client integrations with de-duplication.
* Overlay with a draggable debug bubble, shake-to-open gesture and a nested
  list → detail inspector.
* Request list with search, response-type filtering and aggregate statistics.
* Detail view with headers, pretty-printed bodies, image previews, error view
  and cURL export.
* Share as simple log / JSON / cURL, ignore URLs, enable/disable and clear.
* Light/dark theming.
