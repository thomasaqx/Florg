import 'dart:convert';

import '../models/import_models.dart';
import './api_client.dart';

/// Talks to /imports. The upload never writes anything: the backend parses the
/// file, sends the rows back, and only the confirmed rows are saved.
class ImportRepository {
  ImportRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<SpreadsheetPreview> preview({
    required String filename,
    required List<int> bytes,
    String? accountId,
    ColumnMapping? mapping,
  }) async {
    final json = await _apiClient.postFile(
      '/imports/preview',
      filename: filename,
      bytes: bytes,
      fields: {
        if (accountId != null) 'account_id': accountId,
        if (mapping != null) 'mapping': jsonEncode(mapping.toJson()),
      },
    );
    return SpreadsheetPreview.fromJson(json as Map<String, dynamic>);
  }

  Future<ImportResult> commit({
    required String accountId,
    required String filename,
    required List<ImportRow> rows,
  }) async {
    final json = await _apiClient.post(
      '/imports/commit',
      body: {
        'account_id': accountId,
        'filename': filename,
        'rows': rows.map((row) => row.toJson()).toList(),
      },
    );
    return ImportResult.fromJson(json as Map<String, dynamic>);
  }

  Future<List<ImportBatch>> listBatches() async {
    final json = await _apiClient.get('/imports') as List<dynamic>;
    return json
        .map((item) => ImportBatch.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
