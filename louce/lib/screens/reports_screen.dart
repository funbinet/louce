import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/midnight_hacker.dart';
import '../providers/navigation_state.dart';
import '../models/report_model.dart';
import '../services/report_renderer.dart';
import '../services/report_storage.dart';
import '../components/output_viewer.dart';
import '../components/system_alert.dart';
import '../components/terminal_log.dart';
import '../components/green_button.dart';

/// Reports Screen — allows exploration, rendering, and deletion of saved outputs.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportFormat _viewFormat = ReportFormat.html;
  String _content = '';
  List<String> _logLines = [];
  bool _loading = false;
  bool _editing = false;
  final TextEditingController _editor = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    final baseDir = ref.read(navigationProvider).outputSaveLocation;
    final reports = await ReportStorage.listReports(baseDir);
    ref.read(navigationProvider.notifier).setReports(reports);
  }

  Future<void> _selectReport(ReportRecord report) async {
    ref.read(navigationProvider.notifier).selectReport(report);
    setState(() {
      _viewFormat = ReportFormat.html;
      _editing = false;
    });
    await _loadContent(report, ReportFormat.html);
  }

  Future<void> _loadContent(ReportRecord report, ReportFormat format) async {
    setState(() {
      _loading = true;
      _content = '';
      _viewFormat = format;
    });

    try {
      final content = await _ensureFormatAvailable(report, format);
      final logs = await _readLogLines(report.logPath);

      setState(() {
        _content = content ?? '';
        _logLines = logs;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String?> _ensureFormatAvailable(ReportRecord report, ReportFormat format) async {
    final baseDir = ref.read(navigationProvider).outputSaveLocation;

    if (format == ReportFormat.json || format == ReportFormat.txt || format == ReportFormat.csv || format == ReportFormat.cve) {
      final existing = await ReportStorage.readContent(report, format);
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }

      final payload = await _buildPayloadFromRecord(report);
      if (payload == null) return null;

      if (format == ReportFormat.json) {
        final content = ReportRenderer.renderJson(payload);
        final updated = await ReportStorage.saveJsonReport(
          payload: payload,
          record: report,
          baseDir: baseDir,
          content: content,
        );
        await _refreshReports(updated);
        return content;
      }

      if (format == ReportFormat.txt) {
        final content = ReportRenderer.renderTxt(payload);
        final updated = await ReportStorage.saveTxtReport(
          payload: payload,
          record: report,
          baseDir: baseDir,
          content: content,
        );
        await _refreshReports(updated);
        return content;
      }

      if (format == ReportFormat.csv) {
        final content = ReportRenderer.renderCsv(payload);
        final updated = await ReportStorage.saveCsvReport(
          payload: payload,
          record: report,
          baseDir: baseDir,
          content: content,
        );
        await _refreshReports(updated);
        return content;
      }

      if (format == ReportFormat.cve) {
        final content = ReportRenderer.renderCve(payload);
        final updated = await ReportStorage.saveCveReport(
          payload: payload,
          record: report,
          baseDir: baseDir,
          content: content,
        );
        await _refreshReports(updated);
        return content;
      }
    }

    return ReportStorage.readContent(report, format);
  }

  Future<void> _refreshReports(ReportRecord updated) async {
    final baseDir = ref.read(navigationProvider).outputSaveLocation;
    final reports = await ReportStorage.listReports(baseDir);
    ref.read(navigationProvider.notifier).setReports(reports);
    ref.read(navigationProvider.notifier).selectReport(updated);
  }

  Future<ReportPayload?> _buildPayloadFromRecord(ReportRecord record) async {
    if (record.rawPath == null) return null;
    final rawFile = File(record.rawPath!);
    if (!await rawFile.exists()) return null;

    final rawOutput = await rawFile.readAsString();
    final logs = await _readLogLines(record.logPath);

    return ReportPayload(
      id: record.id,
      actionId: record.actionId,
      actionName: record.actionName,
      moduleName: record.moduleName,
      phaseName: record.phaseName,
      status: record.status,
      systemVersion: ref.read(navigationProvider).systemVersion,
      timestamp: record.timestamp,
      inputs: record.inputs,
      logs: logs,
      rawOutput: rawOutput,
      findings: const [],
      supportsCsv: record.supportsCsv,
      supportsCve: record.supportsCve,
    );
  }

  Future<List<String>> _readLogLines(String? logPath) async {
    if (logPath == null || logPath.isEmpty) return [];
    final file = File(logPath);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return content.split('\n').where((line) => line.trim().isNotEmpty).toList();
  }

  Future<void> _deleteReport(ReportRecord report) async {
    await ReportStorage.deleteReport(report);
    ref.read(navigationProvider.notifier).deleteReport(report.id);
    setState(() {
      _content = '';
      _logLines = [];
      _editing = false;
    });
  }

  Future<void> _saveEdit(ReportRecord report) async {
    await ReportStorage.editContent(report, _viewFormat, _editor.text);
    setState(() {
      _content = _editor.text;
      _editing = false;
    });
  }

  Color _formatColor(ReportFormat format) {
    return _viewFormat == format ? MidnightHacker.positive : MidnightHacker.dimGreen;
  }

  Widget _buildCodePanel(String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: MidnightHacker.primary, width: 1),
        color: MidnightHacker.background,
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          content.isEmpty ? 'No content available.' : content,
          style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final reports = navState.reports;
    final selectedReport = navState.selectedReport;

    return Scaffold(
      backgroundColor: MidnightHacker.background,
      body: Row(
        children: [
          // Left Sidebar listing all historical reports
          Container(
            width: 300,
            decoration: const BoxDecoration(
              border: Border(right: MidnightHacker.greenBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: MidnightHacker.greenBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined, color: MidnightHacker.primary, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'SAVED REPORTS (${reports.length})',
                        style: MidnightHacker.monoSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Reports List
                Expanded(
                  child: reports.isEmpty
                      ? Center(
                          child: Text(
                            'NO REPORTS FOUND',
                            style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                          ),
                        )
                      : ListView.builder(
                          itemCount: reports.length,
                          itemBuilder: (context, index) {
                            final report = reports[index];
                            final active = selectedReport?.id == report.id;

                            return ListTile(
                              selected: active,
                              selectedTileColor: const Color(0xFF0D1117),
                              title: Text(
                                report.actionName,
                                style: MidnightHacker.monoSmall.copyWith(
                                  color: active ? MidnightHacker.positive : MidnightHacker.primary,
                                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                report.timestamp.toIso8601String(),
                                style: MidnightHacker.monoSmall.copyWith(fontSize: 10, color: MidnightHacker.dimGreen),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: MidnightHacker.negative, size: 18),
                                tooltip: 'Delete report',
                                onPressed: () async {
                                  await _deleteReport(report);
                                  SystemAlert.show(
                                    title: 'REPORT DELETED',
                                    message: 'The report has been permanently removed.',
                                    type: AlertType.negative,
                                    context: AlertContext.delete,
                                  );
                                },
                              ),
                              onTap: () {
                                _selectReport(report);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Central Report Viewer area
          Expanded(
            child: selectedReport == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assessment_outlined, color: MidnightHacker.dimGreen, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'SELECT A REPORT TO EXPLORE DETAILS',
                          style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report Header Info
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('RUN DATE: ${selectedReport.timestamp.toIso8601String()}', style: MidnightHacker.labelDim),
                                const SizedBox(height: 4),
                                Text(selectedReport.actionName, style: MidnightHacker.headingLarge.copyWith(fontSize: 28)),
                              ],
                            ),
                            const Spacer(),
                            GreenButton(
                              label: _editing ? 'CANCEL' : 'EDIT',
                              onPressed: () {
                                setState(() {
                                  _editing = !_editing;
                                  _editor.text = _content;
                                });
                              },
                              borderColor: MidnightHacker.dimGreen,
                              textColor: MidnightHacker.primary,
                            ),
                            const SizedBox(width: 12),
                            GreenButton(
                              label: 'REFRESH',
                              onPressed: () async {
                                await _loadReports();
                                await _loadContent(selectedReport, _viewFormat);
                              },
                              borderColor: MidnightHacker.dimGreen,
                              textColor: MidnightHacker.primary,
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // Format toggles
                        Row(
                          children: [
                            GreenButton(
                              label: 'HTML',
                              onPressed: () => _loadContent(selectedReport, ReportFormat.html),
                              borderColor: _formatColor(ReportFormat.html),
                              textColor: _formatColor(ReportFormat.html),
                            ),
                            const SizedBox(width: 8),
                            GreenButton(
                              label: 'JSON',
                              onPressed: () => _loadContent(selectedReport, ReportFormat.json),
                              borderColor: _formatColor(ReportFormat.json),
                              textColor: _formatColor(ReportFormat.json),
                            ),
                            const SizedBox(width: 8),
                            GreenButton(
                              label: 'TXT',
                              onPressed: () => _loadContent(selectedReport, ReportFormat.txt),
                              borderColor: _formatColor(ReportFormat.txt),
                              textColor: _formatColor(ReportFormat.txt),
                            ),
                            if (selectedReport.supportsCsv) ...[
                              const SizedBox(width: 8),
                              GreenButton(
                                label: 'CSV',
                                onPressed: () => _loadContent(selectedReport, ReportFormat.csv),
                                borderColor: _formatColor(ReportFormat.csv),
                                textColor: _formatColor(ReportFormat.csv),
                              ),
                            ],
                            if (selectedReport.supportsCve) ...[
                              const SizedBox(width: 8),
                              GreenButton(
                                label: 'CVE',
                                onPressed: () => _loadContent(selectedReport, ReportFormat.cve),
                                borderColor: _formatColor(ReportFormat.cve),
                                textColor: _formatColor(ReportFormat.cve),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Log console output
                        Text('EXECUTION LOGS', style: MidnightHacker.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 150,
                          child: TerminalLog(lines: _logLines),
                        ),
                        const SizedBox(height: 24),

                        // Rendered output
                        Text('REPORT OUTPUT', style: MidnightHacker.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_loading)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              border: Border.all(color: MidnightHacker.primary, width: 1),
                              color: MidnightHacker.background,
                            ),
                            child: Text('Loading report...', style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.dimGreen)),
                          )
                        else if (_editing)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: MidnightHacker.primary, width: 1),
                              color: MidnightHacker.background,
                            ),
                            child: TextField(
                              controller: _editor,
                              maxLines: null,
                              style: MidnightHacker.monoSmall.copyWith(color: MidnightHacker.primary),
                              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
                            ),
                          )
                        else
                          _viewFormat == ReportFormat.html
                              ? OutputViewer(htmlContent: _content, filePath: selectedReport.htmlPath)
                              : _buildCodePanel(_content),

                        if (_editing) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              GreenButton(
                                label: 'SAVE',
                                onPressed: () async {
                                  await _saveEdit(selectedReport);
                                },
                                borderColor: MidnightHacker.positive,
                                textColor: MidnightHacker.positive,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
