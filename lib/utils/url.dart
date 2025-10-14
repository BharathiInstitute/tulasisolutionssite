import 'package:url_launcher/url_launcher.dart';

/// Launches an external URL using the platform-appropriate mechanism.
/// Returns true if the launch was successful.
Future<bool> launchExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    return ok;
  } catch (_) {
    return false;
  }
}
