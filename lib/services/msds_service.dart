import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/msds_model.dart';

class MsdsLookupException implements Exception {
  final String message;

  const MsdsLookupException(this.message);

  @override
  String toString() => message;
}

class MsdsService {
  final http.Client _client;

  MsdsService({http.Client? client}) : _client = client ?? http.Client();

  Future<MsdsModel> fetchByCas(String cas) async {
    final cleanCas = _normalizeCas(cas);
    if (cleanCas.isEmpty) {
      throw const MsdsLookupException('Enter a CAS number to search.');
    }

    final cid = await _fetchCid(cleanCas);
    final properties = await _fetchBasicProperties(cid);
    final recordPayload = await _tryFetchPugViewRecord(cid);
    final safetySummary = _extractSafetySummary(recordPayload);
    final recordTitle = _readRecordTitle(recordPayload);

    final resolvedName = recordTitle.isNotEmpty
        ? recordTitle
        : properties.iupacName.isNotEmpty
        ? properties.iupacName
        : 'Chemical information unavailable';

    return MsdsModel(
      cas: cleanCas,
      cid: cid,
      name: resolvedName,
      molecularFormula: properties.molecularFormula,
      molecularWeight: properties.molecularWeight,
      iupacName: properties.iupacName,
      signalWord: safetySummary.signalWord,
      ghsPictograms: safetySummary.ghsPictograms,
      hazardStatements: safetySummary.hazardStatements,
      precautionaryStatements: safetySummary.precautionaryStatements,
      firstAid: safetySummary.firstAid,
      handlingAndStorage: safetySummary.handlingAndStorage,
      pubChemUrl: 'https://pubchem.ncbi.nlm.nih.gov/compound/$cid',
    );
  }

  String _normalizeCas(String cas) {
    var value = cas.trim();
    value = value.replaceAll('"', '').replaceAll("'", '');

    if (value.endsWith('.0')) {
      value = value.substring(0, value.length - 2);
    }

    return value;
  }

  Future<String> _fetchCid(String cas) async {
    final payload = await _getJson(
      Uri.parse(
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$cas/cids/JSON',
      ),
      notFoundMessage: 'No PubChem result was found for CAS $cas.',
      failureMessage: 'Could not look up the CAS number in PubChem.',
    );

    final identifierList = _asMap(payload['IdentifierList']);
    final cids = identifierList?['CID'];
    if (cids is! List || cids.isEmpty) {
      throw MsdsLookupException('No PubChem CID was found for CAS $cas.');
    }

    return cids.first.toString().trim();
  }

  Future<_BasicCompoundProperties> _fetchBasicProperties(String cid) async {
    final payload = await _getJson(
      Uri.parse(
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/$cid/property/MolecularFormula,MolecularWeight,IUPACName/JSON',
      ),
      failureMessage: 'Could not fetch compound properties from PubChem.',
    );

    final propertyTable = _asMap(payload['PropertyTable']);
    final properties = propertyTable?['Properties'];
    if (properties is! List || properties.isEmpty) {
      throw const MsdsLookupException(
        'PubChem returned no compound properties for this chemical.',
      );
    }

    final first = _asMap(properties.first);
    if (first == null) {
      throw const MsdsLookupException(
        'PubChem returned compound properties in an unexpected format.',
      );
    }

    return _BasicCompoundProperties(
      molecularFormula: _readString(first['MolecularFormula']),
      molecularWeight: _formatMolecularWeight(first['MolecularWeight']),
      iupacName: _readString(first['IUPACName']),
    );
  }

  Future<Map<String, dynamic>?> _tryFetchPugViewRecord(String cid) async {
    try {
      return await _getJson(
        Uri.parse(
          'https://pubchem.ncbi.nlm.nih.gov/rest/pug_view/data/compound/$cid/JSON',
        ),
        failureMessage: 'Could not fetch detailed safety data from PubChem.',
      );
    } on MsdsLookupException {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    String? notFoundMessage,
    String? failureMessage,
  }) async {
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 404) {
        throw MsdsLookupException(
          notFoundMessage ?? 'No PubChem data was found for this lookup.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MsdsLookupException(
          failureMessage ??
              'PubChem request failed with status ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      throw const MsdsLookupException(
        'PubChem returned data in an unexpected format.',
      );
    } on TimeoutException {
      throw const MsdsLookupException(
        'PubChem took too long to respond. Please try again.',
      );
    } on FormatException {
      throw const MsdsLookupException(
        'PubChem returned unreadable data. Please try again later.',
      );
    } on MsdsLookupException {
      rethrow;
    } catch (_) {
      throw const MsdsLookupException(
        'Could not connect to PubChem right now. Please try again.',
      );
    }
  }

  _SafetySummary _extractSafetySummary(Map<String, dynamic>? payload) {
    final record = _asMap(payload?['Record']);
    final rootSections = record?['Section'];
    if (rootSections == null) {
      return const _SafetySummary();
    }

    final safetySections = _findSectionsByHeading(rootSections, const [
      'Safety and Hazards',
    ]);
    final searchRoot = safetySections.isNotEmpty
        ? safetySections
        : rootSections;
    final ghsSections = _findSectionsByHeading(searchRoot, const [
      'GHS Classification',
    ]);
    final signalSections = _findSectionsByHeading(
      ghsSections.isNotEmpty ? ghsSections : searchRoot,
      const ['Signal Word'],
    );
    final pictogramSections = _findSectionsByHeading(
      ghsSections.isNotEmpty ? ghsSections : searchRoot,
      const ['Pictogram'],
    );
    final hazardSections = _findSectionsByHeading(searchRoot, const [
      'Hazard Statements',
    ]);
    final precautionarySections = _findSectionsByHeading(searchRoot, const [
      'Precautionary Statement Codes',
    ]);
    final firstAidSections = _findSectionsByHeading(searchRoot, const [
      'First Aid Measures',
    ]);
    final handlingSections = _findSectionsByHeading(searchRoot, const [
      'Handling and Storage',
    ]);

    return _SafetySummary(
      signalWord: _extractSignalWord(signalSections, ghsSections),
      ghsPictograms: _extractPictogramCodes([
        ...ghsSections,
        ...pictogramSections,
      ]),
      hazardStatements: _extractStatementList(hazardSections, codePrefix: 'H'),
      precautionaryStatements: _extractStatementList(
        precautionarySections,
        codePrefix: 'P',
      ),
      firstAid: _joinSectionText(
        firstAidSections,
        ignoredHeadings: const ['First Aid Measures'],
      ),
      handlingAndStorage: _joinSectionText(
        handlingSections,
        ignoredHeadings: const ['Handling and Storage'],
      ),
    );
  }

  String _readRecordTitle(Map<String, dynamic>? payload) {
    final record = _asMap(payload?['Record']);
    return _readString(record?['RecordTitle']);
  }

  List<Map<String, dynamic>> _findSectionsByHeading(
    dynamic node,
    List<String> headings,
  ) {
    if (node == null) {
      return const [];
    }

    final normalizedHeadings = headings
        .map((heading) => _normalizeHeading(heading))
        .toList(growable: false);
    final matches = <Map<String, dynamic>>[];

    // PubChem PUG-View records are deeply nested "Section" trees whose
    // headings vary by compound, so we walk the structure recursively.
    void visit(dynamic value) {
      if (value is List) {
        for (final item in value) {
          visit(item);
        }
        return;
      }

      final map = _asMap(value);
      if (map == null) {
        return;
      }

      final heading = _normalizeHeading(_readString(map['TOCHeading']));
      if (heading.isNotEmpty &&
          normalizedHeadings.any((candidate) => heading.contains(candidate))) {
        matches.add(map);
      }

      for (final child in map.values) {
        if (child is List || child is Map) {
          visit(child);
        }
      }
    }

    visit(node);
    return matches;
  }

  String _extractSignalWord(
    List<Map<String, dynamic>> signalSections,
    List<Map<String, dynamic>> ghsSections,
  ) {
    final fragments = _extractTextFragments(
      signalSections.isNotEmpty ? signalSections : ghsSections,
    );

    for (final fragment in fragments) {
      final labeledMatch = RegExp(
        r'signal\s*word[:\s]+(danger|warning)',
        caseSensitive: false,
      ).firstMatch(fragment);
      if (labeledMatch != null) {
        return _capitalize(labeledMatch.group(1)!);
      }

      final bareMatch = RegExp(
        r'\b(danger|warning)\b',
        caseSensitive: false,
      ).firstMatch(fragment);
      if (bareMatch != null) {
        return _capitalize(bareMatch.group(1)!);
      }
    }

    return '';
  }

  List<String> _extractPictogramCodes(dynamic node) {
    final fragments = _extractTextFragments(
      node,
      includeSectionHeadings: true,
      includeUrls: true,
    );
    final codes = <String>{};

    final inlineCodePattern = RegExp(r'\bGHS0?[1-9]\b', caseSensitive: false);
    final urlCodePattern = RegExp(
      r'/images/ghs/(GHS\d{2})\.(?:gif|svg)',
      caseSensitive: false,
    );

    for (final fragment in fragments) {
      for (final match in inlineCodePattern.allMatches(fragment)) {
        final raw = match.group(0);
        if (raw != null) {
          codes.add(_normalizePictogramCode(raw));
        }
      }

      for (final match in urlCodePattern.allMatches(fragment)) {
        final raw = match.group(1);
        if (raw != null) {
          codes.add(raw.toUpperCase());
        }
      }
    }

    final ordered = codes.toList()..sort();
    return ordered;
  }

  List<String> _extractStatementList(
    dynamic node, {
    required String codePrefix,
  }) {
    final codePattern = RegExp(
      '\\b${RegExp.escape(codePrefix)}\\d{3}[A-Z0-9+]*\\b',
      caseSensitive: false,
    );
    final fragments = _extractTextFragments(node);
    final statements = <String>[];
    final seen = <String>{};

    for (final fragment in fragments) {
      final candidates = _splitByStatementCode(fragment, codePattern);
      for (final candidate in candidates) {
        final cleaned = _cleanStatement(candidate);
        if (cleaned.isEmpty) {
          continue;
        }

        final hasCode = codePattern.hasMatch(cleaned);
        if (!hasCode && cleaned.length < 12) {
          continue;
        }

        if (seen.add(cleaned)) {
          statements.add(cleaned);
        }
      }
    }

    return statements;
  }

  List<String> _splitByStatementCode(String text, RegExp codePattern) {
    final matches = codePattern.allMatches(text).toList();
    if (matches.length <= 1) {
      return [text];
    }

    final segments = <String>[];
    for (var index = 0; index < matches.length; index++) {
      final start = matches[index].start;
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : text.length;
      segments.add(text.substring(start, end).trim());
    }

    return segments;
  }

  String _joinSectionText(
    dynamic node, {
    required List<String> ignoredHeadings,
  }) {
    final ignored = ignoredHeadings
        .map((heading) => _normalizeHeading(heading))
        .toSet();
    final fragments = _extractTextFragments(node, includeSectionHeadings: true);
    final cleaned = <String>[];
    final seen = <String>{};

    for (final fragment in fragments) {
      final normalized = _normalizeHeading(fragment);
      if (normalized.isEmpty || ignored.contains(normalized)) {
        continue;
      }

      final value = _cleanStatement(fragment);
      if (value.isEmpty || !seen.add(value)) {
        continue;
      }

      cleaned.add(value);
    }

    if (cleaned.isEmpty) {
      return '';
    }

    return cleaned.take(10).join('\n');
  }

  List<String> _extractTextFragments(
    dynamic node, {
    bool includeSectionHeadings = false,
    bool includeUrls = false,
  }) {
    final fragments = <String>[];
    final seen = <String>{};

    void addText(String? value) {
      final normalized = _normalizeText(value);
      if (normalized.isEmpty) {
        return;
      }

      if (!includeUrls && normalized.startsWith('http')) {
        return;
      }

      if (seen.add(normalized)) {
        fragments.add(normalized);
      }
    }

    void visit(dynamic value, {String? key}) {
      if (value == null) {
        return;
      }

      if (value is String) {
        final lowerKey = key?.toLowerCase() ?? '';
        if (!includeUrls && lowerKey.contains('url')) {
          return;
        }

        addText(value);
        return;
      }

      if (value is num) {
        if ((key ?? '').toLowerCase() == 'number') {
          addText(value.toString());
        }
        return;
      }

      if (value is List) {
        for (final item in value) {
          visit(item);
        }
        return;
      }

      final map = _asMap(value);
      if (map == null) {
        return;
      }

      if (includeSectionHeadings) {
        addText(_readString(map['TOCHeading']));
      }

      final handledKeys = <String>{
        if (map.containsKey('Description')) 'Description',
        if (map.containsKey('String')) 'String',
        if (map.containsKey('Name')) 'Name',
        if (map.containsKey('StringWithMarkup')) 'StringWithMarkup',
        if (map.containsKey('Value')) 'Value',
        if (map.containsKey('Information')) 'Information',
        if (map.containsKey('Section')) 'Section',
        if (map.containsKey('Table')) 'Table',
        if (map.containsKey('Markup')) 'Markup',
      };

      for (final entryKey in handledKeys) {
        visit(map[entryKey], key: entryKey);
      }

      for (final entry in map.entries) {
        if (handledKeys.contains(entry.key)) {
          continue;
        }

        if (entry.key.toLowerCase().contains('url')) {
          if (includeUrls) {
            visit(entry.value, key: entry.key);
          }
          continue;
        }

        if (entry.value is List || entry.value is Map) {
          visit(entry.value, key: entry.key);
        }
      }
    }

    visit(node);
    return fragments;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  String _normalizeHeading(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeText(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanStatement(String value) {
    var cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^[,;:\-\u2022]+'), '').trim();
    return cleaned;
  }

  String _normalizePictogramCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return 'GHS${digits.padLeft(2, '0')}';
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }

    final lower = value.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  String _formatMolecularWeight(dynamic value) {
    final raw = _readString(value);
    final parsed = double.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    return parsed
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _BasicCompoundProperties {
  final String molecularFormula;
  final String molecularWeight;
  final String iupacName;

  const _BasicCompoundProperties({
    required this.molecularFormula,
    required this.molecularWeight,
    required this.iupacName,
  });
}

class _SafetySummary {
  final String signalWord;
  final List<String> ghsPictograms;
  final List<String> hazardStatements;
  final List<String> precautionaryStatements;
  final String firstAid;
  final String handlingAndStorage;

  const _SafetySummary({
    this.signalWord = '',
    this.ghsPictograms = const [],
    this.hazardStatements = const [],
    this.precautionaryStatements = const [],
    this.firstAid = '',
    this.handlingAndStorage = '',
  });
}
