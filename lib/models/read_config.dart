class ReadConfig {
  int textSize;
  int bgColor;
  int textColor;
  String? bgImage;
  int pageAnim; // 0:覆盖 1:仿真 2:滑动 3:滚动 4:无动画 5:上下
  int textIndent;
  int lineSpacing;
  int paragraphSpacing;
  bool statusBarVisibility;
  bool titleVisibility;
  bool timeVisibility;
  bool batteryVisibility;
  bool pageNumberVisibility;
  String? fontFamily;
  int fontWeight;
  bool boldText;
  int textAlign; // 0:左对齐 1:居中 2:两端对齐
  int verticalLayout; // 0:横屏 1:竖屏
  bool invertPage;
  int clickAreaNext;
  int clickAreaPrev;
  bool volumeKeyPage;
  bool volumeKeyReverse;
  bool autoNextPage;
  int autoNextPageSpeed;
  bool keepScreenOn;
  bool showMenuOnTap;
  int paddingLeft;
  int paddingRight;
  int paddingTop;
  int paddingBottom;
  int headerHeight;
  int footerHeight;
  String? headerString;
  String? footerString;
  int headerSize;
  int footerSize;
  bool headerBold;
  bool footerBold;
  int headerColor;
  int footerColor;
  bool headerAlignCenter;
  bool footerAlignCenter;

  ReadConfig({
    this.textSize = 20,
    this.bgColor = 0xFFFFF8E1,
    this.textColor = 0xFF333333,
    this.bgImage,
    this.pageAnim = 0,
    this.textIndent = 2,
    this.lineSpacing = 2,
    this.paragraphSpacing = 1,
    this.statusBarVisibility = true,
    this.titleVisibility = true,
    this.timeVisibility = true,
    this.batteryVisibility = true,
    this.pageNumberVisibility = true,
    this.fontFamily,
    this.fontWeight = 400,
    this.boldText = false,
    this.textAlign = 2,
    this.verticalLayout = 0,
    this.invertPage = false,
    this.clickAreaNext = 1,
    this.clickAreaPrev = 1,
    this.volumeKeyPage = true,
    this.volumeKeyReverse = false,
    this.autoNextPage = false,
    this.autoNextPageSpeed = 10,
    this.keepScreenOn = true,
    this.showMenuOnTap = true,
    this.paddingLeft = 16,
    this.paddingRight = 16,
    this.paddingTop = 8,
    this.paddingBottom = 8,
    this.headerHeight = 24,
    this.footerHeight = 24,
    this.headerString,
    this.footerString,
    this.headerSize = 12,
    this.footerSize = 12,
    this.headerBold = false,
    this.footerBold = false,
    this.headerColor = 0xFF888888,
    this.footerColor = 0xFF888888,
    this.headerAlignCenter = false,
    this.footerAlignCenter = true,
  });

  static const List<Map<String, dynamic>> presets = [
    {'name': '护眼', 'bg': 0xFFCCE8CF, 'text': 0xFF333333},
    {'name': '羊皮纸', 'bg': 0xFFF1E9D2, 'text': 0xFF5B4636},
    {'name': '纯白', 'bg': 0xFFFFFFFF, 'text': 0xFF333333},
    {'name': '白绿', 'bg': 0xFFE0F0E0, 'text': 0xFF333333},
    {'name': '黑色', 'bg': 0xFF000000, 'text': 0xFFBBBBBB},
    {'name': '深灰', 'bg': 0xFF2B2B2B, 'text': 0xFFBBBBBB},
    {'name': '褐色', 'bg': 0xFF3B2F2F, 'text': 0xFFC9B8A8},
    {'name': '绿色', 'bg': 0xFF0B3D0B, 'text': 0xFF8FBC8F},
  ];

  Map<String, dynamic> toJson() => {
    'textSize': textSize,
    'bgColor': bgColor,
    'textColor': textColor,
    'bgImage': bgImage,
    'pageAnim': pageAnim,
    'textIndent': textIndent,
    'lineSpacing': lineSpacing,
    'paragraphSpacing': paragraphSpacing,
    'fontFamily': fontFamily,
    'boldText': boldText,
    'textAlign': textAlign,
    'verticalLayout': verticalLayout,
    'paddingLeft': paddingLeft,
    'paddingRight': paddingRight,
    'paddingTop': paddingTop,
    'paddingBottom': paddingBottom,
  };

  factory ReadConfig.fromJson(Map<String, dynamic> json) => ReadConfig(
    textSize: json['textSize'] ?? 20,
    bgColor: json['bgColor'] ?? 0xFFFFF8E1,
    textColor: json['textColor'] ?? 0xFF333333,
    bgImage: json['bgImage'],
    pageAnim: json['pageAnim'] ?? 0,
    textIndent: json['textIndent'] ?? 2,
    lineSpacing: json['lineSpacing'] ?? 2,
    paragraphSpacing: json['paragraphSpacing'] ?? 1,
    fontFamily: json['fontFamily'],
    boldText: json['boldText'] ?? false,
    textAlign: json['textAlign'] ?? 2,
    verticalLayout: json['verticalLayout'] ?? 0,
    paddingLeft: json['paddingLeft'] ?? 16,
    paddingRight: json['paddingRight'] ?? 16,
    paddingTop: json['paddingTop'] ?? 8,
    paddingBottom: json['paddingBottom'] ?? 8,
  );
}
