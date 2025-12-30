import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/check_item.dart';
import 'auth_service.dart';

class TaskService {
  TaskService({http.Client? client, this.apiBase, AuthServiceBase? auth})
    : _client = client ?? http.Client(),
      _auth = auth ?? authService;

  final http.Client _client;
  final AuthServiceBase _auth;
  final String? apiBase;

  String get _base => apiBase ?? _auth.apiBase;

  Uri _uri(String path) => Uri.parse('$_base$path');

  String _normalizeUrl(String raw) {
    if (raw.startsWith('http')) return raw;
    return '$_base$raw';
  }

  Map<String, String> _headers({bool withJson = false}) {
    final headers = <String, String>{};
    if (withJson) {
      headers['Content-Type'] = 'application/json';
    }
    final token = _auth.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<List<TaskItem>> fetchInstallerInbox({String? status}) async {
    final uri = status != null && status.isNotEmpty
        ? _uri('/tasks/installer/inbox?status_filter=$status')
        : _uri('/tasks/installer/inbox');
    final headers = _headers();
    final token = _auth.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'access_token=$token';
    }
    final response = await _client.get(uri, headers: headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw AuthException(_auth.errorMessage(response));
  }

  Future<TaskItem> submitTask(String taskId, {String? comment}) async {
    final headers = _headers(withJson: true);
    final token = _auth.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'access_token=$token';
    }

    final response = await _client.post(
      _uri('/tasks/$taskId/submit'),
      headers: headers,
      body: jsonEncode({'submission_comment': comment}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TaskItem.fromJson(data);
    }

    throw AuthException(_auth.errorMessage(response));
  }

  Future<TaskItem> installerStart(String taskId) async {
    final headers = _headers(withJson: true);
    final token = _auth.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'access_token=$token';
    }

    final response = await _client.post(
      _uri('/task/$taskId/installer-start'),
      headers: headers,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TaskItem.fromJson(data);
    }

    throw AuthException(_auth.errorMessage(response));
  }

  Future<TaskItem> installerSubmit(String taskId, {String? comment}) async {
    final headers = _headers(withJson: true);
    final token = _auth.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'access_token=$token';
    }

    final response = await _client.post(
      _uri('/task/$taskId/installer-submit'),
      headers: headers,
      body: jsonEncode({'comment': comment}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TaskItem.fromJson(data);
    }

    throw AuthException(_auth.errorMessage(response));
  }

  Future<List<String>> uploadPhoto(
    String taskId,
    Uint8List bytes, {
    String? filename,
  }) async {
    final token = _auth.accessToken;
    final request = http.MultipartRequest(
      'POST',
      _uri('/tasks/$taskId/photos/upload'),
    );

    request.headers.addAll(_headers());
    if (token != null && token.isNotEmpty) {
      request.headers['Cookie'] = 'access_token=$token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        'files',
        bytes,
        filename: filename ?? 'photo.jpg',
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data is Map && data['urls'] is List) {
        return (data['urls'] as List).map((e) => e.toString()).toList();
      }
      return const [];
    }

    throw AuthException(_auth.errorMessage(response));
  }

  Future<List<String>> uploadDocument(
    String taskId,
    Uint8List bytes, {
    String? filename,
  }) async {
    final token = _auth.accessToken;
    final request = http.MultipartRequest(
      'POST',
      _uri('/tasks/$taskId/documents/upload'),
    );
    request.headers.addAll(_headers());
    if (token != null && token.isNotEmpty) {
      request.headers['Cookie'] = 'access_token=$token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'files',
        bytes,
        filename: filename ?? 'document.pdf',
        contentType: MediaType('application', 'pdf'),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data is Map && data['urls'] is List) {
        return (data['urls'] as List).map((e) => e.toString()).toList();
      }
      return const [];
    }

    throw AuthException(_auth.errorMessage(response));
  }

  Future<TaskDetail> fetchTaskDetail(String taskId) async {
    final headers = _headers();
    final token = _auth.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'access_token=$token';
    }
    final response = await _client.get(_uri('/tasks/$taskId'), headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final photos = <TaskPhoto>[];
      final docs = <TaskDocument>[];

      final rawPhotos = data['photos'];
      if (rawPhotos is List) {
        for (final e in rawPhotos) {
          final photo = TaskPhoto.fromJson(e as Map<String, dynamic>);
          photos.add(
            photo.url.isEmpty
                ? photo
                : TaskPhoto(id: photo.id, url: _normalizeUrl(photo.url)),
          );
        }
      }

      final rawDocs = data['documents'] ?? data['files'];
      if (rawDocs is List) {
        for (final e in rawDocs) {
          final doc = TaskDocument.fromJson(e as Map<String, dynamic>);
          docs.add(
            doc.url.isEmpty
                ? doc
                : TaskDocument(
                    id: doc.id,
                    url: _normalizeUrl(doc.url),
                    name: doc.name,
                  ),
          );
        }
      }

      String firstNonEmpty(List<dynamic> values) {
        for (final value in values) {
          if (value == null) continue;
          final str = value.toString();
          if (str.trim().isNotEmpty) return str;
        }
        return '';
      }

      final templateMap =
          data['template_example'] is Map<String, dynamic> ? data['template_example'] as Map<String, dynamic> : null;

      final templatePhotoRaw = firstNonEmpty([
        data['template_example_photo'],
        data['template_example_photo_url'],
        data['template_example_image'],
        templateMap != null ? templateMap['photo'] : null,
        templateMap != null ? templateMap['photo_url'] : null,
        templateMap != null ? templateMap['image'] : null,
      ]);

      final templateDocRaw = firstNonEmpty([
        data['template_document_url'],
        data['template_document'],
        data['template_example_document'],
        templateMap != null ? templateMap['document'] : null,
        templateMap != null ? templateMap['document_url'] : null,
        templateMap != null ? templateMap['pdf'] : null,
      ]);

      final templateExample = TaskTemplateExample(
        title: firstNonEmpty([
          data['template_example_title'],
          data['template_example_name'],
          templateMap != null ? templateMap['title'] : null,
          templateMap != null ? templateMap['name'] : null,
        ]),
        annotation: firstNonEmpty([
          data['template_example_annotation'],
          templateMap != null ? templateMap['annotation'] : null,
          templateMap != null ? templateMap['note'] : null,
        ]),
        photoUrl:
            templatePhotoRaw.isNotEmpty ? _normalizeUrl(templatePhotoRaw) : null,
        documentUrl:
            templateDocRaw.isNotEmpty ? _normalizeUrl(templateDocRaw) : null,
      );

      return TaskDetail(
        photos: photos,
        documents: docs,
        submissionComment: data['submission_comment'] as String? ??
            data['installer_comment'] as String?,
        qaComment: data['qa_comment'] as String?,
        status: data['status'] as String?,
        requiredPhotos: (data['required_photos'] as num?)?.toInt(),
        templateExample: templateExample,
        taskTypeName: data['task_type_name'] as String? ??
            data['task_type'] as String?,
      );
    }
    throw AuthException(_auth.errorMessage(response));
  }

  Future<List<TaskPhoto>> fetchPhotos(String taskId) async {
    final detail = await fetchTaskDetail(taskId);
    return detail.photos;
  }

  Future<void> deletePhoto(String taskId, String photoId) async {
    final headers = _headers();
    final token = _auth.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'access_token=$token';
    }
    final response = await _client.delete(
      _uri('/tasks/$taskId/photos/$photoId'),
      headers: headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw AuthException(_auth.errorMessage(response));
  }
}
