import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../theme/app_theme.dart';
import '../../auth/domain/auth_session.dart';
import '../data/resume_api.dart';
import '../domain/app_resume.dart';

class ResumePdfScreen extends StatefulWidget {
  const ResumePdfScreen({
    super.key,
    required this.session,
    required this.resume,
    this.api,
  });

  final AuthSession session;
  final AppResume resume;
  final ResumeApi? api;

  @override
  State<ResumePdfScreen> createState() => _ResumePdfScreenState();
}

class _ResumePdfScreenState extends State<ResumePdfScreen> {
  late final ApiClient _client;
  late final ResumeApi _api;
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _pages = 0;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _api = widget.api ?? ResumeApi(_client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _pages = 0;
      _page = 1;
    });
    try {
      final id = widget.resume.resumeId;
      if (id == null) {
        throw const ApiException('简历尚未保存，无法查看原始 PDF');
      }
      final data = await _api.pdf(widget.session.token, id);
      if (!mounted) return;
      final document = await PdfDocument.openData(data);
      if (!mounted) {
        await document.close();
        return;
      }
      _controller?.dispose();
      setState(() {
        _controller = PdfControllerPinch(document: Future.value(document));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException
            ? error.message
            : 'PDF 无法打开，文件可能已损坏或加密，请重新上传';
      });
    }
  }

  @override
  void dispose() {
    _client.close();
    _controller?.dispose();
    super.dispose();
  }

  Widget _failure(String message) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.picture_as_pdf_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('重新加载'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('原始 PDF')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.resume.fileName ?? '简历.pdf',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _failure(_error!)
                : PdfViewPinch(
                    key: ObjectKey(_controller),
                    controller: _controller!,
                    onDocumentLoaded: (document) {
                      if (mounted) {
                        setState(() => _pages = document.pagesCount);
                      }
                    },
                    onPageChanged: (page) {
                      if (mounted) setState(() => _page = page);
                    },
                    builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
                      options: const DefaultBuilderOptions(),
                      documentLoaderBuilder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                      pageLoaderBuilder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, _) => _failure('PDF 无法打开，请重新加载或重新上传'),
                    ),
                  ),
          ),
          if (_pages > 0 && !_loading && _error == null) ...[
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上一页',
                  onPressed: _page > 1
                      ? () => _controller!.jumpToPage(_page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                SizedBox(
                  width: 104,
                  child: Text('$_page / $_pages', textAlign: TextAlign.center),
                ),
                IconButton(
                  tooltip: '下一页',
                  onPressed: _page < _pages
                      ? () => _controller!.jumpToPage(_page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
