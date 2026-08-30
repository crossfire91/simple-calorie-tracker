import 'package:http/http.dart' as http;
import 'package:simple_calorie_tracker/update/update_config.dart';
import 'package:simple_calorie_tracker/update/update_release.dart';

/// Newest published release, or null if the catalog could not be read.
Future<UpdateRelease?> fetchNewestRelease() async {
  final manifest = await _fromManifest();
  if (manifest != null && manifest.hasApk) return manifest;
  return _fromGithub();
}

Future<UpdateRelease?> _fromManifest() async {
  final url = UpdateConfig.manifestUrl.trim();
  if (url.isEmpty) return null;
  final body = await _get(url);
  if (body == null) return null;
  return parseManifest(body);
}

Future<UpdateRelease?> _fromGithub() async {
  final repo = UpdateConfig.githubRepo.trim();
  if (repo.isEmpty || !repo.contains('/')) return null;
  final body = await _get(
    'https://api.github.com/repos/$repo/releases/latest',
    accept: 'application/vnd.github+json',
  );
  if (body == null) return null;
  return parseGithubRelease(body);
}

Future<String?> _get(String url, {String accept = 'application/json'}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return null;
  final response = await http
      .get(
        uri,
        headers: {
          'User-Agent': UpdateConfig.userAgent,
          'Accept': accept,
        },
      )
      .timeout(const Duration(seconds: 12));
  if (response.statusCode >= 400) return null;
  return response.body;
}
