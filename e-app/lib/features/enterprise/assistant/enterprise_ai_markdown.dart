import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../theme/app_theme.dart';

class EnterpriseAiMarkdown extends StatelessWidget {
  const EnterpriseAiMarkdown({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium!;
    final heading = body.copyWith(
      color: AppColors.brand,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
    return MarkdownBody(
      data: content,
      selectable: true,
      fitContent: false,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body,
        h1: heading.copyWith(fontSize: 20),
        h2: heading.copyWith(fontSize: 18),
        h3: heading.copyWith(fontSize: 16),
        h4: heading.copyWith(fontSize: 14),
        h5: heading.copyWith(fontSize: 14),
        h6: heading.copyWith(fontSize: 14),
        strong: const TextStyle(fontWeight: FontWeight.w600),
        a: body.copyWith(
          color: AppColors.interactive,
          decoration: TextDecoration.underline,
        ),
        blockSpacing: 12,
        listIndent: 24,
        listBullet: body,
        blockquote: body.copyWith(color: AppColors.bodySoft),
        blockquotePadding: const EdgeInsets.all(12),
        blockquoteDecoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(left: BorderSide(color: AppColors.hairline, width: 3)),
        ),
        code: body.copyWith(
          fontFamily: 'monospace',
          backgroundColor: AppColors.background,
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.hairline),
        ),
        tableHead: body.copyWith(fontWeight: FontWeight.w600),
        tableBody: body,
        tableColumnWidth: const IntrinsicColumnWidth(),
        tableBorder: TableBorder.all(color: AppColors.hairline),
        tableCellsPadding: const EdgeInsets.all(8),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
      ),
      // Model-provided images stay textual, just like links, without fetching URLs.
      imageBuilder: (uri, title, alt) => SelectableText(
        alt?.isNotEmpty == true ? alt! : (title ?? '图片'),
        style: body.copyWith(color: AppColors.bodySoft),
      ),
    );
  }
}
