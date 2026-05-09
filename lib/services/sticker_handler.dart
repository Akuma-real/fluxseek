import '../utils/url_helper.dart';

/// NodeSeek 贴图（sticker）解析器
///
/// 对齐 docs/nodeseek-api.md §15½。NodeSeek 的 `:xhj003:` / `:ac01:` /
/// `:yct015:` / `:emoji00:` 等短码不是 Twitter emoji，而是自研贴图系统。
///
/// - 短码格式：`:{group}{number}:`，`group` 纯字母 + `number` 纯数字
/// - URL 模板：`/static/image/sticker/{group}/{filename}`
/// - 分组与 files 硬编码（NodeSeek 未提供列表 API）
/// - `emoji` 分组在网页端是视频（`.webm`/`.mov`），但有 `.png` 静态封面，
///   客户端这里统一走 PNG 渲染。
class StickerHandler {
  StickerHandler._();

  /// 短码正则：`(\D+)(\d+)`
  static final RegExp _shortcodePattern = RegExp(r'^(\D+)(\d+)$');

  /// 解析短码，返回 `(group, number)`，失败返回 null
  static ({String group, String number})? parseShortcode(String raw) {
    final match = _shortcodePattern.firstMatch(raw);
    if (match == null) return null;
    final group = match.group(1);
    final number = match.group(2);
    if (group == null || number == null) return null;
    if (!_stickerGroups.containsKey(group)) return null;
    return (group: group, number: number);
  }

  /// 根据短码生成完整 URL；分组不认识或编号不在 `files` 里返回 null
  static String? resolveUrl(String shortcode) {
    final parsed = parseShortcode(shortcode);
    if (parsed == null) return null;
    return _resolveUrlInternal(parsed.group, parsed.number);
  }

  /// 判断短码是否属于 NodeSeek 贴图
  static bool isSticker(String shortcode) {
    return resolveUrl(shortcode) != null;
  }

  /// 将一个 `{group}{number}` 短码解析成最终 URL。
  static String? _resolveUrlInternal(String group, String number) {
    final files = _stickerGroups[group];
    if (files == null) return null;

    // `emoji` 分组在 bundle 里 files 不带扩展名（视频），这里统一给它加 `.png`
    // 对应 NodeSeek 服务端每个编号都同时存在 `.png` 静态封面的事实。
    final isVideo = _videoGroups.contains(group);

    for (final file in files) {
      final fileBase = isVideo ? file : _stripExt(file);
      if (fileBase == number) {
        final fileName = isVideo ? '$file.png' : file;
        return UrlHelper.resolveUrlWithCdn(
          '/static/image/sticker/$group/$fileName',
        );
      }
    }
    return null;
  }

  static String _stripExt(String filename) {
    final dot = filename.indexOf('.');
    return dot < 0 ? filename : filename.substring(0, dot);
  }

  // ============================================================
  // 贴图分组映射（2026-05-09 抓自 assets/markdownEditor-*.js）
  // NodeSeek 发版时 files 可能变动，需跟随更新。
  // ============================================================

  /// 视频分组（文件名不带扩展名，URL 拼 `.png` 用静态封面）
  static const Set<String> _videoGroups = {'emoji'};

  static const Map<String, List<String>> _stickerGroups = {
    // AC娘（137 张，全 .png）
    'ac': [
      '01.png', '02.png', '03.png', '04.png', '05.png', '06.png', '07.png',
      '08.png', '09.png', '10.png', '11.png', '12.png', '13.png', '14.png',
      '15.png', '16.png', '17.png', '18.png', '19.png', '20.png', '21.png',
      '22.png', '23.png', '24.png', '25.png', '26.png', '27.png', '28.png',
      '29.png', '30.png', '31.png', '32.png', '33.png', '34.png', '35.png',
      '36.png', '37.png', '38.png', '39.png', '40.png', '41.png', '42.png',
      '43.png', '44.png', '45.png', '46.png', '47.png', '48.png', '49.png',
      '50.png', '51.png', '52.png', '53.png', '54.png',
      '1001.png', '1002.png', '1003.png', '1004.png', '1005.png', '1006.png',
      '1007.png', '1008.png', '1009.png', '1010.png', '1011.png', '1012.png',
      '1013.png', '1014.png', '1015.png', '1016.png', '1017.png', '1018.png',
      '1019.png', '1020.png', '1021.png', '1022.png', '1023.png', '1024.png',
      '1025.png', '1026.png', '1027.png', '1028.png', '1029.png', '1030.png',
      '1031.png', '1032.png', '1033.png', '1034.png', '1035.png', '1036.png',
      '1037.png', '1038.png', '1039.png', '1040.png',
      '2001.png', '2002.png', '2003.png', '2004.png', '2005.png', '2006.png',
      '2007.png', '2008.png', '2009.png', '2010.png', '2011.png', '2012.png',
      '2013.png', '2014.png', '2015.png', '2016.png', '2017.png', '2018.png',
      '2019.png', '2020.png', '2021.png', '2022.png', '2023.png', '2024.png',
      '2025.png', '2026.png', '2027.png', '2028.png', '2029.png', '2030.png',
      '2031.png', '2032.png', '2033.png', '2034.png', '2035.png', '2036.png',
      '2037.png', '2038.png', '2039.png', '2040.png', '2041.png', '2042.png',
      '2043.png', '2044.png', '2045.png', '2046.png', '2047.png', '2048.png',
      '2049.png', '2050.png', '2051.png', '2052.png', '2053.png', '2054.png',
      '2055.png',
    ],

    // 洋葱头（22 张，全 .gif）
    'yct': [
      '001.gif', '002.gif', '003.gif', '004.gif', '005.gif', '006.gif',
      '007.gif', '008.gif', '009.gif', '010.gif', '011.gif', '012.gif',
      '013.gif', '014.gif', '015.gif', '016.gif', '017.gif', '018.gif',
      '019.gif', '020.gif', '021.gif', '022.gif',
    ],

    // 小黄鸡（32 张，.png / .gif 混合）
    'xhj': [
      '001.png', '002.png', '003.png', '004.gif', '005.png', '006.png',
      '007.png', '008.gif', '009.gif', '010.gif', '011.png', '012.gif',
      '013.gif', '014.gif', '015.gif', '016.gif', '017.gif', '018.gif',
      '019.gif', '020.gif', '021.gif', '022.png', '023.gif', '024.png',
      '025.png', '026.gif', '027.gif', '028.gif', '029.gif', '030.gif',
      '031.png', '032.png',
    ],

    // Fluent（49 个，视频 + PNG 静态封面，客户端只用 PNG）
    'emoji': [
      '00', '01', '02', '03', '04', '05', '06', '07', '08', '09',
      '10', '11', '12', '13', '14', '15', '16', '17', '18', '19',
      '20', '21', '22', '23', '24', '25', '26', '27', '28', '29',
      '30', '31', '32', '33', '34', '35', '36', '37', '38', '39',
      '40', '41', '42', '43', '44', '45', '46', '47', '48',
    ],
  };

  /// 对外暴露分组中文名（供表情面板使用）
  static const Map<String, String> groupLabels = {
    'ac': 'AC娘',
    'yct': '洋葱头',
    'xhj': '小黄鸡',
    'emoji': 'Fluent',
  };

  /// 列出所有贴图分组，供表情面板等 UI 使用
  static Iterable<String> get allGroups => _stickerGroups.keys;

  /// 列出某个分组下所有贴图的短码（`{group}{number}`），按 bundle 原序。
  static List<String> shortcodesOf(String group) {
    final files = _stickerGroups[group];
    if (files == null) return const [];
    return files
        .map((f) => '$group${_videoGroups.contains(group) ? f : _stripExt(f)}')
        .toList(growable: false);
  }
}
