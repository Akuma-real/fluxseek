import '../site_customization.dart';

/// NodeSeek 站点自定义配置
final nodeseekCustomization = SiteCustomization(
  linkSecurityConfig: _nodeseekLinkSecurityConfig,
);

/// NodeSeek 链接安全配置
const _nodeseekLinkSecurityConfig = LinkSecurityConfig(
  enableExitConfirmation: true,
  internalDomains: [
    '*.nodeseek.com',
    'localhost',
    '*.local',
    '^127(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}',
    '^10(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}',
    '^169\\.254(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){2}',
    '^192\\.168(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){2}',
    '^172\\.(?:1[6-9]|2\\d|3[0-1])(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){2}',
  ],
  trustedDomains: ['github.com/NodeSeekDev/*'],
  riskyDomains: [
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'ow.ly',
    'buff.ly',
    'adf.ly',
    'short.link',
    '*.short.link',
    'tiny.cc',
    'is.gd',
    'j.mp',
    'lnkd.in',
    'qr.ae',
  ],
  dangerousDomains: ['**aff='],
);
