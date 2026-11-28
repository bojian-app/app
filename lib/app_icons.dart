import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

typedef AppIconData = List<List<dynamic>>;

/// Shared stroke-rounded Hugeicons vocabulary.
abstract final class AppIcons {
  // Two-tone entries of the bottom tab bar: a filled body marked with
  // `opacity` (HugeIcon's secondary layer, painted in its secondaryColor)
  // beneath the stroked outline of the matching Hugeicon.

  /// A house under overhanging eaves with an arched door.
  static final tabHome = [
    _tone(
      'M4 9.5L8.135 4.97C9.982 3.323 10.905 2.5 12 2.5C13.095 2.5 14.018 3.323 '
      '15.865 4.97L20 9.5V14.5C20 17.8 20 19.45 18.975 20.475C17.95 21.5 16.3 '
      '21.5 13 21.5H11C7.7 21.5 6.05 21.5 5.025 20.475C4 19.45 4 17.8 4 14.5Z',
    ),
    ...HugeIcons.strokeRoundedHome08.sublist(0, 2),
    _line(
      'M9.75 21.5V18C9.75 16.757 10.757 15.75 12 15.75C13.243 15.75 14.25 '
      '16.757 14.25 18V21.5',
    ),
  ];

  /// A pennant with a star.
  static final tabMembership = [
    _tone(
      'M4.5 3V14C4.5 16.33 4.931 17.09 6.928 18.289L9.942 20.097C10.945 20.699 '
      '11.446 21 12 21C12.554 21 13.055 20.699 14.058 20.097L17.073 18.289C19.069 '
      '17.09 19.5 16.33 19.5 14V3Z',
    ),
    ...HugeIcons.strokeRoundedHonourStar,
  ];

  /// A bell with a filled body.
  static final tabMessages = [
    _tone(
      'M19.2311 18H4.76887C3.79195 18 3 17.208 3 16.2311C3 15.762 3.18636 '
      '15.3121 3.51809 14.9803L4.12132 14.3771C4.68393 13.8145 5 13.0514 5 '
      '12.2558V9.5C5 5.63401 8.13401 2.5 12 2.5C15.866 2.5 19 5.634 19 9.5'
      'V12.2558C19 13.0514 19.3161 13.8145 19.8787 14.3771L20.4819 14.9803'
      'C20.8136 15.3121 21 15.762 21 16.2311C21 17.208 20.208 18 19.2311 18Z',
    ),
    ...HugeIcons.strokeRoundedNotification01,
  ];

  /// A head and shoulders, both filled.
  static final tabProfile = [
    _tone(
      'M4 21C4.284 17.306 7.3 14.219 11.001 14.038C11.313 14.023 11.645 14.01 12 '
      '14L12.995 14.066C16.729 14.315 19.713 17.269 20 21Z',
    ),
    [
      'circle',
      {'cx': '12', 'cy': '7', 'r': '4', 'fill': 'currentColor', 'opacity': '1'},
    ],
    ...HugeIcons.strokeRoundedUser,
  ];

  static List<dynamic> _tone(String d) => [
    'path',
    {'d': d, 'fill': 'currentColor', 'opacity': '1'},
  ];

  static List<dynamic> _line(String d) => [
    'path',
    {
      'd': d,
      'stroke': 'currentColor',
      'strokeWidth': '1.5',
      'strokeLinecap': 'round',
      'strokeLinejoin': 'round',
    },
  ];
  static const drag = HugeIcons.strokeRoundedDragDropVertical;
  static const switchResume = HugeIcons.strokeRoundedExchange01;
  static const more = HugeIcons.strokeRoundedMoreHorizontal;
  static const outline = HugeIcons.strokeRoundedLeftToRightListBullet;
  static const power = HugeIcons.strokeRoundedPower;
  static const phone = HugeIcons.strokeRoundedSmartPhone01;
  static const computer = HugeIcons.strokeRoundedComputer;
  static const export = HugeIcons.strokeRoundedFileExport;
  static const download = HugeIcons.strokeRoundedFileDownload;
  static const share = HugeIcons.strokeRoundedShare08;
  static const pdf = HugeIcons.strokeRoundedPdf02;
  static const word = HugeIcons.strokeRoundedDoc02;
  static const moveUp = HugeIcons.strokeRoundedArrowUp01;
  static const moveDown = HugeIcons.strokeRoundedArrowDown01;
  static const delete = HugeIcons.strokeRoundedDelete02;
  static const sort = HugeIcons.strokeRoundedSortByDown02;
  static const location = HugeIcons.strokeRoundedLocation01;
  static const industry = HugeIcons.strokeRoundedBuilding03;
  static const filter = HugeIcons.strokeRoundedFilterHorizontal;
  static const work = HugeIcons.strokeRoundedBriefcase01;
  static const education = HugeIcons.strokeRoundedMortarboard01;
  static const discover = HugeIcons.strokeRoundedCompass;
  static const resume = HugeIcons.strokeRoundedFile02;
  static const messages = HugeIcons.strokeRoundedMessage01;
  static const inbox = HugeIcons.strokeRoundedMail01;
  static const headset = HugeIcons.strokeRoundedHeadset;
  static const copy = HugeIcons.strokeRoundedCopy01;
  static const profile = HugeIcons.strokeRoundedUser;
  static const profileSelected = HugeIcons.strokeRoundedUser;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const zoomIn = HugeIcons.strokeRoundedZoomInArea;
  static const zoomOut = HugeIcons.strokeRoundedZoomOutArea;
  static const add = HugeIcons.strokeRoundedAdd01;
  static const addCircle = HugeIcons.strokeRoundedAddCircle;
  static const importResume = HugeIcons.strokeRoundedFileUpload;
  static const templates = HugeIcons.strokeRoundedGridView;
  static const portrait = HugeIcons.strokeRoundedUserSquare;
  static const camera = HugeIcons.strokeRoundedCamera01;
  static const back = HugeIcons.strokeRoundedArrowLeft01;
  static const forward = HugeIcons.strokeRoundedArrowRight01;
  static const arrowForward = HugeIcons.strokeRoundedArrowRight02;
  static const external = HugeIcons.strokeRoundedArrowUpRight01;
  static const like = HugeIcons.strokeRoundedFavourite;
  static const bookmark = HugeIcons.strokeRoundedStar;
  static final liked = _filled(like);
  static final bookmarked = _filled(bookmark);

  static AppIconData _filled(AppIconData outline) => [
    for (final element in outline)
      [
        element[0],
        {...element[1] as Map<String, dynamic>, 'fill': 'currentColor'},
      ],
  ];
  static const thumbUp = HugeIcons.strokeRoundedThumbsUp;
  static const thumbDown = HugeIcons.strokeRoundedThumbsDown;
  static const comment = HugeIcons.strokeRoundedBubbleChat;
  static const send = HugeIcons.strokeRoundedSent;
  static const clear = HugeIcons.strokeRoundedCancelCircle;
  static const confirm = HugeIcons.strokeRoundedTick02;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const readAll = HugeIcons.strokeRoundedTickDouble02;
  static const addPerson = HugeIcons.strokeRoundedUserAdd01;
  static const guidanceRecipients = HugeIcons.strokeRoundedUserSearch01;
  static const aiOptimize = HugeIcons.strokeRoundedAiMagic;
  static const monochrome = HugeIcons.strokeRoundedContrast;
  static const notification = HugeIcons.strokeRoundedNotification01;
  static const notificationUnread = HugeIcons.strokeRoundedNotification02;
  static const notificationSettings = HugeIcons.strokeRoundedNotificationSquare;
  static const wallet = HugeIcons.strokeRoundedTicket01;
  static const cart = HugeIcons.strokeRoundedShoppingCart01;
  static const settings = HugeIcons.strokeRoundedSettings01;
  static const bold = HugeIcons.strokeRoundedTextBold;
  static const italic = HugeIcons.strokeRoundedTextItalic;
  static const underline = HugeIcons.strokeRoundedTextUnderline;
  static const heading = HugeIcons.strokeRoundedHeading01;
  static const bullets = HugeIcons.strokeRoundedLeftToRightListBullet;
  static const numbering = HugeIcons.strokeRoundedLeftToRightListNumber;
  static const quote = HugeIcons.strokeRoundedQuoteUp;
  static const undo = HugeIcons.strokeRoundedUndo;
  static const redo = HugeIcons.strokeRoundedRedo;
  static const edit = HugeIcons.strokeRoundedPencilEdit02;
  static const accountSecurity = HugeIcons.strokeRoundedShieldKey;
  static const identityVerification = HugeIcons.strokeRoundedUserCheck01;
  static const privacyPolicy = HugeIcons.strokeRoundedLockKey;
  static const terms = HugeIcons.strokeRoundedAgreement01;
  static const permissions = HugeIcons.strokeRoundedKey01;
  static const imageCache = HugeIcons.strokeRoundedImage02;
  static const feedback = HugeIcons.strokeRoundedBubbleChatQuestion;
  static const about = HugeIcons.strokeRoundedInformationCircle;
  static const logout = HugeIcons.strokeRoundedLogout01;
  static const publicProfile = HugeIcons.strokeRoundedUserGroup;
  static const personalInfo = HugeIcons.strokeRoundedContact01;
  static const jobExpectation = HugeIcons.strokeRoundedTarget02;
  static const projects = HugeIcons.strokeRoundedTask01;
  static const skills = HugeIcons.strokeRoundedBulb;
  static const certificate = HugeIcons.strokeRoundedCertificate01;
  static const article = HugeIcons.strokeRoundedNote01;
  static const createArticle = HugeIcons.strokeRoundedPencilEdit02;
  static const addResume = HugeIcons.strokeRoundedPlusSignSquare;
  static const avatarUpload = HugeIcons.strokeRoundedImageUpload;
  static const wechat = HugeIcons.strokeRoundedWechat;
  static const moments = HugeIcons.strokeRoundedAperture;
  static const link = HugeIcons.strokeRoundedLink01;
  static const saveImage = HugeIcons.strokeRoundedDownload04;
  static const templateMarket = HugeIcons.strokeRoundedStore01;
  static const templatePreview = HugeIcons.strokeRoundedLayout01;
  static const error = HugeIcons.strokeRoundedAlertCircle;
  static const expand = HugeIcons.strokeRoundedArrowDown01;
  static const date = HugeIcons.strokeRoundedCalendar03;
  static const attachment = HugeIcons.strokeRoundedAttachment01;
  static const profileEdit = HugeIcons.strokeRoundedUserEdit01;
  static const userAccount = HugeIcons.strokeRoundedUserAccount;
  static const honourStar = HugeIcons.strokeRoundedHonourStar;
  static const folder = HugeIcons.strokeRoundedFolder01;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const hideKeyboard = HugeIcons.strokeRoundedKeyboard;
  static const menu = HugeIcons.strokeRoundedMenu01;
  static const scan = HugeIcons.strokeRoundedScan;
  static const done = HugeIcons.strokeRoundedCheckmarkCircle02;
  static const alert = HugeIcons.strokeRoundedAlert02;
  static const gift = HugeIcons.strokeRoundedGift;
  static const accountChanged = HugeIcons.strokeRoundedUserBlock01;
  static const coins = HugeIcons.strokeRoundedCoins01;
  static const membership = HugeIcons.strokeRoundedCrown;
}

/// Inherits icon size, color and disabled opacity from the surrounding controls.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.secondaryColor,
    this.semanticLabel,
  });
  final AppIconData icon;
  final double? size;
  final Color? color;

  /// Paints the layer of a two-tone icon that is marked with `opacity`.
  final Color? secondaryColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: semanticLabel == null,
    child: HugeIcon(
      icon: icon,
      size: size,
      color: color,
      secondaryColor: secondaryColor,
      strokeWidth: 1.8,
    ),
  );
}
