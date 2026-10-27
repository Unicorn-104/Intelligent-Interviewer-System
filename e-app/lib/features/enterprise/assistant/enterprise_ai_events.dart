import 'dart:async';
import 'dart:convert';

import 'enterprise_ai_data_source.dart';

/// A GET subscription, not a generation request. Closing never resubmits or stops the server run.
class EnterpriseAiConnection {
  const EnterpriseAiConnection(this.events, this.close);
  final Stream<EnterpriseAiRun> events;
  final void Function() close;
}

/// Handles fragmented UTF-8, CR/LF, comments and multiline SSE data with bounded frame sizes.
Stream<EnterpriseAiRun> decodeEnterpriseAiEvents(
  Stream<List<int>> bytes,
) async* {
  var lineLength = 0;
  final bounded = StreamTransformer<String, String>.fromHandlers(
    handleData: (chunk, sink) {
      for (final code in chunk.codeUnits) {
        lineLength = code == 10 || code == 13 ? 0 : lineLength + 1;
        if (lineLength > 100000) {
          sink.addError(const FormatException('AI流式数据过长'));
          return;
        }
      }
      sink.add(chunk);
    },
  );
  var event = 'message';
  var size = 0;
  var first = true;
  final data = <String>[];
  await for (var line
      in bytes
          .transform(utf8.decoder)
          .transform(bounded)
          .transform(const LineSplitter())) {
    if (first) {
      first = false;
      if (line.startsWith('\uFEFF')) line = line.substring(1);
    }
    if (line.isEmpty) {
      if (data.isNotEmpty && event == 'run') {
        final decoded = jsonDecode(data.join('\n'));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('AI流式数据格式不正确');
        }
        final run = EnterpriseAiRun.fromJson(decoded);
        if (run.content.length > 12000) {
          throw const FormatException('AI回答超过长度上限');
        }
        yield run;
      }
      data.clear();
      event = 'message';
      size = 0;
      continue;
    }
    if (line.startsWith(':')) continue;
    final separator = line.indexOf(':');
    final field = separator < 0 ? line : line.substring(0, separator);
    var value = separator < 0 ? '' : line.substring(separator + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    if (field == 'event') event = value;
    if (field == 'data') {
      size += value.length;
      if (size > 100000) throw const FormatException('AI流式数据过长');
      data.add(value);
    }
  }
  if (data.isNotEmpty) throw const FormatException('AI流式连接提前中断，请刷新恢复');
}
