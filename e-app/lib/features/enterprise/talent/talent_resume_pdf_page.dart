import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../api/talent_api.dart' as talent;
import '../../../../core/network/api_exception.dart';
import '../../../../theme/app_theme.dart';

/// 候选人原始简历 PDF 预览页（企业端）。
///
/// 参考 C-App `ResumePdfScreen` 实现：Bearer 鉴权下载字节后本地渲染，
/// 支持捏合缩放、翻页与重试；不向系统浏览器暴露私有文件地址，
/// 页面关闭时释放文档资源。
class TalentResumePdfPage extends StatefulWidget {
  const TalentResumePdfPage({
    super.key,
    required this.talentId,
    this.fileName,
    this.loader,
  });

  final int talentId;
  final String? fileName;

  /// 字节加载器（测试可注入）；缺省调用真实接口。
  final Future<Uint8List> Function()? loader;

  @override
  State<TalentResumePdfPage> createState() => _TalentResumePdfPageState();
}

class _TalentResumePdfPageState extends State<TalentResumePdfPage> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _pages = 0;

  @override
  void initState() {
    super.initState();
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
      final data = await (widget.loader ??
          () => talent.getTalentResumePdf(widget.talentId))();
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
            : 'PDF 无法打开，文件可能已损坏或加密';
      });
    }
  }

  @override
  void dispose() {
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
        appBar: AppBar(title: const Text('原始简历')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.fileName ?? '简历.pdf',
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
                              errorBuilder: (_, _) =>
                                  _failure('PDF 无法打开，请重新加载'),
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
                      child: Text(
                        '$_page / $_pages',
                        textAlign: TextAlign.center,
                      ),
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
