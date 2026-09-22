import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_gan.dart';
import 'app_localizations_hsn.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_wuu.dart';
import 'app_localizations_yue.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('gan'),
    Locale('hsn'),
    Locale('ja'),
    Locale('pt'),
    Locale('ru'),
    Locale('wuu'),
    Locale('yue'),
    Locale('zh'),
    Locale('zh', 'HK'),
    Locale('zh', 'TW'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'hefei')
  ];

  /// 应用名称
  ///
  /// In zh, this message translates to:
  /// **'自在东湖'**
  String get appTitle;

  /// 设置页面标题
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// Agent 设置项
  ///
  /// In zh, this message translates to:
  /// **'Agent 设置'**
  String get agentSettings;

  /// 外观设置项
  ///
  /// In zh, this message translates to:
  /// **'外观设置'**
  String get appearanceSettings;

  /// 通知设置项
  ///
  /// In zh, this message translates to:
  /// **'通知设置'**
  String get notificationSettings;

  /// 语言设置项
  ///
  /// In zh, this message translates to:
  /// **'语言设置'**
  String get language;

  /// 跟随系统选项
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// 简体中文选项
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// 英文选项
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// 繁体中文（中国香港）选项
  ///
  /// In zh, this message translates to:
  /// **'繁体中文（中国香港）'**
  String get traditionalChineseHK;

  /// 繁体中文选项
  ///
  /// In zh, this message translates to:
  /// **'繁体中文'**
  String get traditionalChineseTW;

  /// 日语选项
  ///
  /// In zh, this message translates to:
  /// **'日语'**
  String get japanese;

  /// 西班牙语选项
  ///
  /// In zh, this message translates to:
  /// **'西班牙语'**
  String get spanish;

  /// 法语选项
  ///
  /// In zh, this message translates to:
  /// **'法语'**
  String get french;

  /// 葡萄牙语选项
  ///
  /// In zh, this message translates to:
  /// **'葡萄牙语'**
  String get portuguese;

  /// 俄语选项
  ///
  /// In zh, this message translates to:
  /// **'俄语'**
  String get russian;

  /// 粤语（广州话）选项
  ///
  /// In zh, this message translates to:
  /// **'粤语（广州话）'**
  String get cantonese;

  /// 吴语（苏州话）选项
  ///
  /// In zh, this message translates to:
  /// **'吴语（苏州话）'**
  String get wuSuzhou;

  /// 湘语（长沙话）选项
  ///
  /// In zh, this message translates to:
  /// **'湘语（长沙话）'**
  String get xiangChangsha;

  /// 江淮官话（合肥话）选项
  ///
  /// In zh, this message translates to:
  /// **'江淮官话（合肥话）'**
  String get jianghuaiHefei;

  /// 赣语（南昌话）选项
  ///
  /// In zh, this message translates to:
  /// **'赣语（南昌话）'**
  String get ganNanchang;

  /// 主页底栏首页标签
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// 主页底栏课表标签
  ///
  /// In zh, this message translates to:
  /// **'课表'**
  String get tabTimetable;

  /// 主页底栏作业标签
  ///
  /// In zh, this message translates to:
  /// **'作业'**
  String get tabHomework;

  /// 主页底栏通知标签
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get tabNotice;

  /// 主页底栏功能标签
  ///
  /// In zh, this message translates to:
  /// **'功能'**
  String get tabFunctions;

  /// 通用取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// 通用确定按钮
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// 登录中提示
  ///
  /// In zh, this message translates to:
  /// **'正在登录，请稍候...'**
  String get loggingInWait;

  /// No description provided for @profile.
  ///
  /// In zh, this message translates to:
  /// **'个人中心'**
  String get profile;

  /// No description provided for @helpFeedback.
  ///
  /// In zh, this message translates to:
  /// **'帮助与反馈'**
  String get helpFeedback;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @notLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get notLoggedIn;

  /// No description provided for @clickToLogin.
  ///
  /// In zh, this message translates to:
  /// **'点击登录以访问更多功能'**
  String get clickToLogin;

  /// No description provided for @defaultStudentName.
  ///
  /// In zh, this message translates to:
  /// **'湖南农大学子'**
  String get defaultStudentName;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退出'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'退出登录后将清除您的本地凭证并断开数据连接。'**
  String get logoutConfirmContent;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @openSourceLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源声明'**
  String get openSourceLicenses;

  /// No description provided for @sendEmail.
  ///
  /// In zh, this message translates to:
  /// **'发送邮件'**
  String get sendEmail;

  /// No description provided for @developer.
  ///
  /// In zh, this message translates to:
  /// **'开发者'**
  String get developer;

  /// No description provided for @loginTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请登录以继续。'**
  String get loginSubtitle;

  /// No description provided for @studentId.
  ///
  /// In zh, this message translates to:
  /// **'学号'**
  String get studentId;

  /// No description provided for @studentIdHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入学号'**
  String get studentIdHint;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get passwordHint;

  /// No description provided for @loginButton.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginButton;

  /// No description provided for @funcSunshine.
  ///
  /// In zh, this message translates to:
  /// **'阳光服务'**
  String get funcSunshine;

  /// No description provided for @funcQuestionnaire.
  ///
  /// In zh, this message translates to:
  /// **'学工问卷'**
  String get funcQuestionnaire;

  /// No description provided for @funcLeave.
  ///
  /// In zh, this message translates to:
  /// **'请假申请'**
  String get funcLeave;

  /// No description provided for @funcPaymentCode.
  ///
  /// In zh, this message translates to:
  /// **'付款码'**
  String get funcPaymentCode;

  /// No description provided for @funcRecharge.
  ///
  /// In zh, this message translates to:
  /// **'校园卡充值'**
  String get funcRecharge;

  /// No description provided for @funcLibrary.
  ///
  /// In zh, this message translates to:
  /// **'图书馆'**
  String get funcLibrary;

  /// No description provided for @funcEmptyClassroom.
  ///
  /// In zh, this message translates to:
  /// **'空教室'**
  String get funcEmptyClassroom;

  /// No description provided for @funcXgxt.
  ///
  /// In zh, this message translates to:
  /// **'学工系统'**
  String get funcXgxt;

  /// No description provided for @funcRepairs.
  ///
  /// In zh, this message translates to:
  /// **'报修平台'**
  String get funcRepairs;

  /// No description provided for @funcGym.
  ///
  /// In zh, this message translates to:
  /// **'场馆预约'**
  String get funcGym;

  /// No description provided for @funcTeachingEval.
  ///
  /// In zh, this message translates to:
  /// **'教评系统'**
  String get funcTeachingEval;

  /// No description provided for @funcScore.
  ///
  /// In zh, this message translates to:
  /// **'成绩查询'**
  String get funcScore;

  /// No description provided for @funcVpn.
  ///
  /// In zh, this message translates to:
  /// **'VPN转换'**
  String get funcVpn;

  /// No description provided for @funcCampusCard.
  ///
  /// In zh, this message translates to:
  /// **'校园卡'**
  String get funcCampusCard;

  /// No description provided for @funcEleRecharge.
  ///
  /// In zh, this message translates to:
  /// **'电费充值'**
  String get funcEleRecharge;

  /// No description provided for @funcBus.
  ///
  /// In zh, this message translates to:
  /// **'长沙实时公交'**
  String get funcBus;

  /// No description provided for @funcCsBus.
  ///
  /// In zh, this message translates to:
  /// **'长沙实时公交'**
  String get funcCsBus;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @homeButtonsSetting.
  ///
  /// In zh, this message translates to:
  /// **'首页按钮排序与隐藏'**
  String get homeButtonsSetting;

  /// No description provided for @homeButtonsTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页按钮设置'**
  String get homeButtonsTitle;

  /// No description provided for @functionsButtonsSetting.
  ///
  /// In zh, this message translates to:
  /// **'功能页按钮排序与隐藏'**
  String get functionsButtonsSetting;

  /// No description provided for @functionsButtonsTitle.
  ///
  /// In zh, this message translates to:
  /// **'功能页按钮设置'**
  String get functionsButtonsTitle;

  /// No description provided for @visibleFunctions.
  ///
  /// In zh, this message translates to:
  /// **'显示中的功能'**
  String get visibleFunctions;

  /// No description provided for @hiddenFunctions.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏的功能 (拖动到此隐藏)'**
  String get hiddenFunctions;

  /// No description provided for @dragToReorderTip.
  ///
  /// In zh, this message translates to:
  /// **'长按拖动图标，移入不同区域可显示或隐藏功能'**
  String get dragToReorderTip;

  /// No description provided for @loginRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要登录以查看内容'**
  String get loginRequiredTitle;

  /// No description provided for @loginRequiredMessage.
  ///
  /// In zh, this message translates to:
  /// **'登录后即可查看您的课表、作业和成绩信息'**
  String get loginRequiredMessage;

  /// No description provided for @noticeTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知公告'**
  String get noticeTitle;

  /// No description provided for @noticeLoginTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要登录以接收通知'**
  String get noticeLoginTitle;

  /// No description provided for @noticeLoginMessage.
  ///
  /// In zh, this message translates to:
  /// **'登录后即可向您推送学校的最新通知公告'**
  String get noticeLoginMessage;

  /// No description provided for @loadingNotices.
  ///
  /// In zh, this message translates to:
  /// **'正在加载通知...'**
  String get loadingNotices;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @noNotices.
  ///
  /// In zh, this message translates to:
  /// **'暂无通知'**
  String get noNotices;

  /// No description provided for @noNoticesSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'有新消息时会在这里显示'**
  String get noNoticesSubtitle;

  /// No description provided for @loadingMore.
  ///
  /// In zh, this message translates to:
  /// **'正在加载更多...'**
  String get loadingMore;

  /// No description provided for @noMoreNotices.
  ///
  /// In zh, this message translates to:
  /// **'没有更多通知了'**
  String get noMoreNotices;

  /// No description provided for @homeworkLoginTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要登录以同步作业'**
  String get homeworkLoginTitle;

  /// No description provided for @homeworkLoginMessage.
  ///
  /// In zh, this message translates to:
  /// **'登录后即可从超星平台实时同步您的课程作业，您也可以直接点击右下角手动添加'**
  String get homeworkLoginMessage;

  /// No description provided for @homeworkTabArchived.
  ///
  /// In zh, this message translates to:
  /// **'存档'**
  String get homeworkTabArchived;

  /// No description provided for @homeworkTabCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get homeworkTabCompleted;

  /// No description provided for @homeworkTabPending.
  ///
  /// In zh, this message translates to:
  /// **'未完成'**
  String get homeworkTabPending;

  /// No description provided for @homeworkEmptyArchived.
  ///
  /// In zh, this message translates to:
  /// **'存档里空空如也'**
  String get homeworkEmptyArchived;

  /// No description provided for @homeworkEmptyCompleted.
  ///
  /// In zh, this message translates to:
  /// **'还没完成过作业哦'**
  String get homeworkEmptyCompleted;

  /// No description provided for @homeworkEmptyPending.
  ///
  /// In zh, this message translates to:
  /// **'暂时没有待办作业'**
  String get homeworkEmptyPending;

  /// No description provided for @homeworkLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'作业加载失败: {error}'**
  String homeworkLoadFailed(String error);

  /// No description provided for @scoreQuery.
  ///
  /// In zh, this message translates to:
  /// **'成绩查询'**
  String get scoreQuery;

  /// No description provided for @currentSemester.
  ///
  /// In zh, this message translates to:
  /// **'当前学期'**
  String get currentSemester;

  /// No description provided for @noScoreData.
  ///
  /// In zh, this message translates to:
  /// **'本学期暂无成绩数据'**
  String get noScoreData;

  /// No description provided for @scoreCredit.
  ///
  /// In zh, this message translates to:
  /// **'学分: {credit}'**
  String scoreCredit(String credit);

  /// No description provided for @normalExam.
  ///
  /// In zh, this message translates to:
  /// **'正常考试'**
  String get normalExam;

  /// No description provided for @gradeExcellent.
  ///
  /// In zh, this message translates to:
  /// **'优秀'**
  String get gradeExcellent;

  /// No description provided for @gradeFailed.
  ///
  /// In zh, this message translates to:
  /// **'不及格'**
  String get gradeFailed;

  /// No description provided for @courseReminder.
  ///
  /// In zh, this message translates to:
  /// **'上课提醒'**
  String get courseReminder;

  /// No description provided for @courseReminderTime.
  ///
  /// In zh, this message translates to:
  /// **'上课提醒时间'**
  String get courseReminderTime;

  /// No description provided for @homeworkReminder.
  ///
  /// In zh, this message translates to:
  /// **'作业截止提醒'**
  String get homeworkReminder;

  /// No description provided for @homeworkReminderTime.
  ///
  /// In zh, this message translates to:
  /// **'作业提醒时间'**
  String get homeworkReminderTime;

  /// No description provided for @libraryReminder.
  ///
  /// In zh, this message translates to:
  /// **'图书馆预约提醒'**
  String get libraryReminder;

  /// No description provided for @libraryReminderTime.
  ///
  /// In zh, this message translates to:
  /// **'图书馆预约提醒时间'**
  String get libraryReminderTime;

  /// No description provided for @notifDurationNone.
  ///
  /// In zh, this message translates to:
  /// **'不通知'**
  String get notifDurationNone;

  /// No description provided for @notifMinutesBefore.
  ///
  /// In zh, this message translates to:
  /// **'{minutes}分钟前'**
  String notifMinutesBefore(int minutes);

  /// No description provided for @notifHoursBefore.
  ///
  /// In zh, this message translates to:
  /// **'{hours}小时前'**
  String notifHoursBefore(String hours);

  /// No description provided for @setSuccessfully.
  ///
  /// In zh, this message translates to:
  /// **'已设置为: {label}'**
  String setSuccessfully(String label);

  /// No description provided for @setNotificationFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置通知失败: {error}'**
  String setNotificationFailed(String error);

  /// No description provided for @liveUpdatesNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'当前设备不支持 Live Updates（需 Android 16+）'**
  String get liveUpdatesNotSupported;

  /// No description provided for @needNotificationPermission.
  ///
  /// In zh, this message translates to:
  /// **'需先允许通知权限'**
  String get needNotificationPermission;

  /// No description provided for @liveActivity.
  ///
  /// In zh, this message translates to:
  /// **'实时活动'**
  String get liveActivity;

  /// No description provided for @liveActivitySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用 Live Updates API 提醒'**
  String get liveActivitySubtitle;

  /// No description provided for @liveActivityEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启实时活动'**
  String get liveActivityEnabled;

  /// No description provided for @liveActivityDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭实时活动'**
  String get liveActivityDisabled;

  /// No description provided for @liveActivityEnabledFlymeDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启实时活动，实况通知已关闭'**
  String get liveActivityEnabledFlymeDisabled;

  /// No description provided for @flymeLive.
  ///
  /// In zh, this message translates to:
  /// **'实况通知'**
  String get flymeLive;

  /// No description provided for @flymeLiveSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用 Flyme 实况通知 API'**
  String get flymeLiveSubtitle;

  /// No description provided for @flymeLiveEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启实况通知'**
  String get flymeLiveEnabled;

  /// No description provided for @flymeLiveDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭实况通知'**
  String get flymeLiveDisabled;

  /// No description provided for @flymeLiveEnabledActivityDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启实况通知，实时活动已关闭'**
  String get flymeLiveEnabledActivityDisabled;

  /// No description provided for @openSystemSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'打不开系统设置，请手动去设置 > 通知里查看'**
  String get openSystemSettingsFailed;

  /// No description provided for @doubleTapToRetract.
  ///
  /// In zh, this message translates to:
  /// **'双击撤回'**
  String get doubleTapToRetract;

  /// No description provided for @systemNotificationDisabled.
  ///
  /// In zh, this message translates to:
  /// **'系统通知未开启'**
  String get systemNotificationDisabled;

  /// No description provided for @testRetracted.
  ///
  /// In zh, this message translates to:
  /// **'测试已撤回'**
  String get testRetracted;

  /// No description provided for @testSent.
  ///
  /// In zh, this message translates to:
  /// **'测试已发送'**
  String get testSent;

  /// No description provided for @sendFailedCheckPermission.
  ///
  /// In zh, this message translates to:
  /// **'发送失败：请检查通知权限'**
  String get sendFailedCheckPermission;

  /// No description provided for @aiSettingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'✅ Agent 配置已保存'**
  String get aiSettingsSaved;

  /// No description provided for @aiSettingsResetDefaults.
  ///
  /// In zh, this message translates to:
  /// **'已恢复默认配置（硅基流动 + Qwen/Qwen3.5-4B）'**
  String get aiSettingsResetDefaults;

  /// No description provided for @aiApiUrl.
  ///
  /// In zh, this message translates to:
  /// **'API 接口地址 (Base URL)'**
  String get aiApiUrl;

  /// No description provided for @aiApiUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'默认 https://api.siliconflow.cn/v1'**
  String get aiApiUrlHint;

  /// No description provided for @aiModelName.
  ///
  /// In zh, this message translates to:
  /// **'模型名称 (Model Name)'**
  String get aiModelName;

  /// No description provided for @aiModelNameHint.
  ///
  /// In zh, this message translates to:
  /// **'默认 Qwen/Qwen3.5-4B'**
  String get aiModelNameHint;

  /// No description provided for @aiApiKeyCustom.
  ///
  /// In zh, this message translates to:
  /// **'API Key (已使用自定义)'**
  String get aiApiKeyCustom;

  /// No description provided for @aiApiKeyDefault.
  ///
  /// In zh, this message translates to:
  /// **'API Key (使用默认)'**
  String get aiApiKeyDefault;

  /// No description provided for @aiApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'留空使用默认 Key，或填入您的 Key (sk-...)'**
  String get aiApiKeyHint;

  /// No description provided for @paste.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get paste;

  /// No description provided for @saveSettings.
  ///
  /// In zh, this message translates to:
  /// **'保存配置'**
  String get saveSettings;

  /// No description provided for @resetDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认配置'**
  String get resetDefaults;

  /// No description provided for @ossDescription.
  ///
  /// In zh, this message translates to:
  /// **'自在东湖 是基于开源社区的各种优秀组件构建而成的。我们尊重并感谢每一位开发者的贡献。'**
  String get ossDescription;

  /// No description provided for @needLocationForBus.
  ///
  /// In zh, this message translates to:
  /// **'需要定位权限以显示附近的实时公交'**
  String get needLocationForBus;

  /// No description provided for @libraryReservation.
  ///
  /// In zh, this message translates to:
  /// **'图书馆预约'**
  String get libraryReservation;

  /// No description provided for @signIn.
  ///
  /// In zh, this message translates to:
  /// **'签到'**
  String get signIn;

  /// No description provided for @signBack.
  ///
  /// In zh, this message translates to:
  /// **'退座'**
  String get signBack;

  /// No description provided for @signInSuccess.
  ///
  /// In zh, this message translates to:
  /// **'签到成功！祝您学习愉快。'**
  String get signInSuccess;

  /// No description provided for @signInFailed.
  ///
  /// In zh, this message translates to:
  /// **'签到失败: {error}'**
  String signInFailed(String error);

  /// No description provided for @signBackConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退座？'**
  String get signBackConfirmTitle;

  /// No description provided for @signBackConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'确定结束在【{room}】的 {seat} 号座位使用吗？'**
  String signBackConfirmContent(String room, String seat);

  /// No description provided for @thinkAgain.
  ///
  /// In zh, this message translates to:
  /// **'我再想想'**
  String get thinkAgain;

  /// No description provided for @confirmSignBack.
  ///
  /// In zh, this message translates to:
  /// **'确认退座'**
  String get confirmSignBack;

  /// No description provided for @signBackSuccess.
  ///
  /// In zh, this message translates to:
  /// **'退座成功'**
  String get signBackSuccess;

  /// No description provided for @signBackFailed.
  ///
  /// In zh, this message translates to:
  /// **'退座失败: {error}'**
  String signBackFailed(String error);

  /// No description provided for @cancelReserveConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认取消预约？'**
  String get cancelReserveConfirmTitle;

  /// No description provided for @cancelReserveConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'确定取消在【{room}】的 {seat} 号座位预约吗？'**
  String cancelReserveConfirmContent(String room, String seat);

  /// No description provided for @confirmCancel.
  ///
  /// In zh, this message translates to:
  /// **'确认取消'**
  String get confirmCancel;

  /// No description provided for @reserveCancelledSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已成功取消该预约'**
  String get reserveCancelledSuccess;

  /// No description provided for @cancelFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消失败: {error}'**
  String cancelFailed(String error);

  /// No description provided for @tomorrowTimetable.
  ///
  /// In zh, this message translates to:
  /// **'明日课表'**
  String get tomorrowTimetable;

  /// No description provided for @todayTimetable.
  ///
  /// In zh, this message translates to:
  /// **'今日课表'**
  String get todayTimetable;

  /// No description provided for @timetableLoginRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要登录以查看课表'**
  String get timetableLoginRequiredTitle;

  /// No description provided for @timetableLoginRequiredMessage.
  ///
  /// In zh, this message translates to:
  /// **'登录后即可同步并查看您的个人课表信息'**
  String get timetableLoginRequiredMessage;

  /// No description provided for @viewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get viewAll;

  /// No description provided for @noCoursesTomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天没有待上的课程'**
  String get noCoursesTomorrow;

  /// No description provided for @noCoursesToday.
  ///
  /// In zh, this message translates to:
  /// **'今天没有待上的课程'**
  String get noCoursesToday;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In zh, this message translates to:
  /// **'位置服务未开启'**
  String get locationServiceDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'定位权限被拒绝'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionPermanentlyDenied.
  ///
  /// In zh, this message translates to:
  /// **'定位权限被永久拒绝，请在设置中开启'**
  String get locationPermissionPermanentlyDenied;

  /// No description provided for @getLocationFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取位置失败: {error}'**
  String getLocationFailed(String error);

  /// No description provided for @newChat.
  ///
  /// In zh, this message translates to:
  /// **'新对话'**
  String get newChat;

  /// No description provided for @requestException.
  ///
  /// In zh, this message translates to:
  /// **'请求异常'**
  String get requestException;

  /// No description provided for @checkAgentSettings.
  ///
  /// In zh, this message translates to:
  /// **'检查 Agent 设置'**
  String get checkAgentSettings;

  /// No description provided for @checkAgentSettingsArrow.
  ///
  /// In zh, this message translates to:
  /// **'检查 Agent 设置 >'**
  String get checkAgentSettingsArrow;

  /// No description provided for @quickPromptsTitle.
  ///
  /// In zh, this message translates to:
  /// **'快捷提问'**
  String get quickPromptsTitle;

  /// No description provided for @promptTodayCourses.
  ///
  /// In zh, this message translates to:
  /// **'今天有什么课？'**
  String get promptTodayCourses;

  /// No description provided for @promptPendingHomework.
  ///
  /// In zh, this message translates to:
  /// **'有哪些未完成的作业？'**
  String get promptPendingHomework;

  /// No description provided for @promptReserveLibrary.
  ///
  /// In zh, this message translates to:
  /// **'预约图书馆座位'**
  String get promptReserveLibrary;

  /// No description provided for @promptSubmitSunshine.
  ///
  /// In zh, this message translates to:
  /// **'快速提交阳光服务'**
  String get promptSubmitSunshine;

  /// No description provided for @promptCampusCardBalance.
  ///
  /// In zh, this message translates to:
  /// **'查询校园卡余额'**
  String get promptCampusCardBalance;

  /// No description provided for @promptDormElectricity.
  ///
  /// In zh, this message translates to:
  /// **'宿舍还有多少电？'**
  String get promptDormElectricity;

  /// No description provided for @promptEmptyClassrooms.
  ///
  /// In zh, this message translates to:
  /// **'查询现在的空教室'**
  String get promptEmptyClassrooms;

  /// No description provided for @promptImportantNotices.
  ///
  /// In zh, this message translates to:
  /// **'最近有什么重要通知？'**
  String get promptImportantNotices;

  /// No description provided for @copiedAnswer.
  ///
  /// In zh, this message translates to:
  /// **'已复制回答内容'**
  String get copiedAnswer;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @aiThinking.
  ///
  /// In zh, this message translates to:
  /// **'正在思考中...'**
  String get aiThinking;

  /// No description provided for @noticeDetail.
  ///
  /// In zh, this message translates to:
  /// **'通知详情'**
  String get noticeDetail;

  /// No description provided for @noticeNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到详情数据'**
  String get noticeNotFound;

  /// No description provided for @noTitle.
  ///
  /// In zh, this message translates to:
  /// **'无标题'**
  String get noTitle;

  /// No description provided for @senderSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get senderSystem;

  /// No description provided for @versionUpdate.
  ///
  /// In zh, this message translates to:
  /// **'版本更新'**
  String get versionUpdate;

  /// No description provided for @foundNewVersion.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 v{version}'**
  String foundNewVersion(String version);

  /// No description provided for @releaseNotes.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get releaseNotes;

  /// No description provided for @updateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In zh, this message translates to:
  /// **'以后再说'**
  String get later;

  /// No description provided for @timetableRefreshed.
  ///
  /// In zh, this message translates to:
  /// **'课表已刷新'**
  String get timetableRefreshed;

  /// No description provided for @timetableRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'刷新失败: {error}'**
  String timetableRefreshFailed(String error);

  /// No description provided for @noTimetableToShare.
  ///
  /// In zh, this message translates to:
  /// **'没有可分享的课表'**
  String get noTimetableToShare;

  /// No description provided for @timetableFileNotFound.
  ///
  /// In zh, this message translates to:
  /// **'课表文件不存在'**
  String get timetableFileNotFound;

  /// No description provided for @shareTimetableText.
  ///
  /// In zh, this message translates to:
  /// **'我的湖南农业大学课表'**
  String get shareTimetableText;

  /// No description provided for @shareFailed.
  ///
  /// In zh, this message translates to:
  /// **'分享失败: {error}'**
  String shareFailed(String error);

  /// No description provided for @tabAgenda.
  ///
  /// In zh, this message translates to:
  /// **'日程'**
  String get tabAgenda;

  /// No description provided for @tabWeek.
  ///
  /// In zh, this message translates to:
  /// **'周'**
  String get tabWeek;

  /// No description provided for @adjustTimetable.
  ///
  /// In zh, this message translates to:
  /// **'调整课表'**
  String get adjustTimetable;

  /// No description provided for @backToToday.
  ///
  /// In zh, this message translates to:
  /// **'回到今天'**
  String get backToToday;

  /// No description provided for @refreshTimetable.
  ///
  /// In zh, this message translates to:
  /// **'刷新课表'**
  String get refreshTimetable;

  /// No description provided for @shareTimetable.
  ///
  /// In zh, this message translates to:
  /// **'分享课表'**
  String get shareTimetable;

  /// No description provided for @noCoursesThisSemester.
  ///
  /// In zh, this message translates to:
  /// **'本学期暂无课程及作业安排'**
  String get noCoursesThisSemester;

  /// No description provided for @timetableInfoIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'课表信息不完整'**
  String get timetableInfoIncomplete;

  /// No description provided for @pleaseReDownloadTimetable.
  ///
  /// In zh, this message translates to:
  /// **'请重新下载课表'**
  String get pleaseReDownloadTimetable;

  /// No description provided for @deadlinePrefix.
  ///
  /// In zh, this message translates to:
  /// **'截止时间'**
  String get deadlinePrefix;

  /// No description provided for @noDeadline.
  ///
  /// In zh, this message translates to:
  /// **'无截止时间'**
  String get noDeadline;

  /// No description provided for @weekdayMon.
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get weekdaySun;

  /// No description provided for @month1.
  ///
  /// In zh, this message translates to:
  /// **'一月'**
  String get month1;

  /// No description provided for @month2.
  ///
  /// In zh, this message translates to:
  /// **'二月'**
  String get month2;

  /// No description provided for @month3.
  ///
  /// In zh, this message translates to:
  /// **'三月'**
  String get month3;

  /// No description provided for @month4.
  ///
  /// In zh, this message translates to:
  /// **'四月'**
  String get month4;

  /// No description provided for @month5.
  ///
  /// In zh, this message translates to:
  /// **'五月'**
  String get month5;

  /// No description provided for @month6.
  ///
  /// In zh, this message translates to:
  /// **'六月'**
  String get month6;

  /// No description provided for @month7.
  ///
  /// In zh, this message translates to:
  /// **'七月'**
  String get month7;

  /// No description provided for @month8.
  ///
  /// In zh, this message translates to:
  /// **'八月'**
  String get month8;

  /// No description provided for @month9.
  ///
  /// In zh, this message translates to:
  /// **'九月'**
  String get month9;

  /// No description provided for @month10.
  ///
  /// In zh, this message translates to:
  /// **'十月'**
  String get month10;

  /// No description provided for @month11.
  ///
  /// In zh, this message translates to:
  /// **'十一月'**
  String get month11;

  /// No description provided for @month12.
  ///
  /// In zh, this message translates to:
  /// **'十二月'**
  String get month12;

  /// No description provided for @fetchTimetable.
  ///
  /// In zh, this message translates to:
  /// **'获取课表'**
  String get fetchTimetable;

  /// No description provided for @syncTimetablePrompt.
  ///
  /// In zh, this message translates to:
  /// **'检测到您已成功登录，是否现在同步您的课程安排并导入日历？'**
  String get syncTimetablePrompt;

  /// No description provided for @skip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get skip;

  /// No description provided for @syncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// No description provided for @academicSemester.
  ///
  /// In zh, this message translates to:
  /// **'学年学期'**
  String get academicSemester;

  /// No description provided for @firstWeekMonday.
  ///
  /// In zh, this message translates to:
  /// **'第一周周一'**
  String get firstWeekMonday;

  /// No description provided for @selectDateHint.
  ///
  /// In zh, this message translates to:
  /// **'请选择日期'**
  String get selectDateHint;

  /// No description provided for @importButton.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importButton;

  /// No description provided for @selectFirstWeekMondayHelp.
  ///
  /// In zh, this message translates to:
  /// **'选择本学期第一周的周一'**
  String get selectFirstWeekMondayHelp;

  /// No description provided for @timetableImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'🎉 课表导入成功！'**
  String get timetableImportSuccess;

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败: {error}'**
  String importFailed(String error);

  /// No description provided for @timetableSyncing.
  ///
  /// In zh, this message translates to:
  /// **'课表正在同步中'**
  String get timetableSyncing;

  /// No description provided for @timetableSyncingDesc.
  ///
  /// In zh, this message translates to:
  /// **'系统正在为您全自动拉取教务课表\n请稍等片刻...'**
  String get timetableSyncingDesc;

  /// No description provided for @noTimetableFound.
  ///
  /// In zh, this message translates to:
  /// **'未获取到课表'**
  String get noTimetableFound;

  /// No description provided for @weekNumber.
  ///
  /// In zh, this message translates to:
  /// **'第{week}周'**
  String weekNumber(int week);

  /// No description provided for @teacher.
  ///
  /// In zh, this message translates to:
  /// **'教师'**
  String get teacher;

  /// No description provided for @classroom.
  ///
  /// In zh, this message translates to:
  /// **'教室'**
  String get classroom;

  /// No description provided for @weeksLabel.
  ///
  /// In zh, this message translates to:
  /// **'周次'**
  String get weeksLabel;

  /// No description provided for @periodsLabel.
  ///
  /// In zh, this message translates to:
  /// **'节次'**
  String get periodsLabel;

  /// No description provided for @timeLabel.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get timeLabel;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @reschedule.
  ///
  /// In zh, this message translates to:
  /// **'调课'**
  String get reschedule;

  /// No description provided for @suspension.
  ///
  /// In zh, this message translates to:
  /// **'停课'**
  String get suspension;

  /// No description provided for @addCourse.
  ///
  /// In zh, this message translates to:
  /// **'加课'**
  String get addCourse;

  /// No description provided for @myAdjustments.
  ///
  /// In zh, this message translates to:
  /// **'我的调整'**
  String get myAdjustments;

  /// No description provided for @rescheduleSingleClass.
  ///
  /// In zh, this message translates to:
  /// **'调一节'**
  String get rescheduleSingleClass;

  /// No description provided for @rescheduleWholeDay.
  ///
  /// In zh, this message translates to:
  /// **'调一天'**
  String get rescheduleWholeDay;

  /// No description provided for @noCoursesSyncFirst.
  ///
  /// In zh, this message translates to:
  /// **'暂无课程，请先同步课表'**
  String get noCoursesSyncFirst;

  /// No description provided for @courseLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程'**
  String get courseLabel;

  /// No description provided for @classTimeSlot.
  ///
  /// In zh, this message translates to:
  /// **'上课时段'**
  String get classTimeSlot;

  /// No description provided for @originalWeek.
  ///
  /// In zh, this message translates to:
  /// **'原周次'**
  String get originalWeek;

  /// No description provided for @currentWeekSuffix.
  ///
  /// In zh, this message translates to:
  /// **' (本周)'**
  String get currentWeekSuffix;

  /// No description provided for @noClassInWeek.
  ///
  /// In zh, this message translates to:
  /// **'第{week}周没有这节课'**
  String noClassInWeek(int week);

  /// No description provided for @rescheduleTo.
  ///
  /// In zh, this message translates to:
  /// **'调到'**
  String get rescheduleTo;

  /// No description provided for @rescheduleAway.
  ///
  /// In zh, this message translates to:
  /// **'调走'**
  String get rescheduleAway;

  /// No description provided for @targetWeek.
  ///
  /// In zh, this message translates to:
  /// **'目标周次'**
  String get targetWeek;

  /// No description provided for @targetWeekday.
  ///
  /// In zh, this message translates to:
  /// **'目标星期'**
  String get targetWeekday;

  /// No description provided for @newWeek.
  ///
  /// In zh, this message translates to:
  /// **'新周次'**
  String get newWeek;

  /// No description provided for @newWeekday.
  ///
  /// In zh, this message translates to:
  /// **'新星期'**
  String get newWeekday;

  /// No description provided for @newPeriod.
  ///
  /// In zh, this message translates to:
  /// **'新节次'**
  String get newPeriod;

  /// No description provided for @originalWeekday.
  ///
  /// In zh, this message translates to:
  /// **'原星期'**
  String get originalWeekday;

  /// No description provided for @noCoursesOnDay.
  ///
  /// In zh, this message translates to:
  /// **'当天没有课'**
  String get noCoursesOnDay;

  /// No description provided for @noCoursesOnDayCannotReschedule.
  ///
  /// In zh, this message translates to:
  /// **'当天没有课，无法调休'**
  String get noCoursesOnDayCannotReschedule;

  /// No description provided for @rescheduleMethod.
  ///
  /// In zh, this message translates to:
  /// **'调课方式'**
  String get rescheduleMethod;

  /// No description provided for @rescheduleCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get rescheduleCopy;

  /// No description provided for @rescheduleShift.
  ///
  /// In zh, this message translates to:
  /// **'平移'**
  String get rescheduleShift;

  /// No description provided for @rescheduleSwap.
  ///
  /// In zh, this message translates to:
  /// **'对调'**
  String get rescheduleSwap;

  /// No description provided for @rescheduleCopyDesc.
  ///
  /// In zh, this message translates to:
  /// **'原日期的课保留，目标日原本的课会被覆盖'**
  String get rescheduleCopyDesc;

  /// No description provided for @rescheduleSwapDesc.
  ///
  /// In zh, this message translates to:
  /// **'两天的课程互相交换'**
  String get rescheduleSwapDesc;

  /// No description provided for @rescheduleShiftDesc.
  ///
  /// In zh, this message translates to:
  /// **'只把课挪过去，原日期的课不保留，目标日原本的课会被覆盖'**
  String get rescheduleShiftDesc;

  /// No description provided for @selectCourseFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先选择课程'**
  String get selectCourseFirst;

  /// No description provided for @confirmReschedule.
  ///
  /// In zh, this message translates to:
  /// **'确认调课'**
  String get confirmReschedule;

  /// No description provided for @rescheduleWarnNoCourse.
  ///
  /// In zh, this message translates to:
  /// **'第{week}周没有《{course}》，继续吗？'**
  String rescheduleWarnNoCourse(int week, String course);

  /// No description provided for @goBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get goBack;

  /// No description provided for @continueAction.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueAction;

  /// No description provided for @rescheduleSaved.
  ///
  /// In zh, this message translates to:
  /// **'调课已保存'**
  String get rescheduleSaved;

  /// No description provided for @rescheduleDaySaved.
  ///
  /// In zh, this message translates to:
  /// **'调休已保存'**
  String get rescheduleDaySaved;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @allCourses.
  ///
  /// In zh, this message translates to:
  /// **'全部课程'**
  String get allCourses;

  /// No description provided for @specifyPeriods.
  ///
  /// In zh, this message translates to:
  /// **'指定节次'**
  String get specifyPeriods;

  /// No description provided for @startWeek.
  ///
  /// In zh, this message translates to:
  /// **'起始周'**
  String get startWeek;

  /// No description provided for @endWeek.
  ///
  /// In zh, this message translates to:
  /// **'结束周'**
  String get endWeek;

  /// No description provided for @weekday.
  ///
  /// In zh, this message translates to:
  /// **'星期'**
  String get weekday;

  /// No description provided for @startPeriod.
  ///
  /// In zh, this message translates to:
  /// **'开始节次'**
  String get startPeriod;

  /// No description provided for @endPeriod.
  ///
  /// In zh, this message translates to:
  /// **'结束节次'**
  String get endPeriod;

  /// No description provided for @suspensionSaved.
  ///
  /// In zh, this message translates to:
  /// **'停课已保存'**
  String get suspensionSaved;

  /// No description provided for @addCourseTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加课程'**
  String get addCourseTitle;

  /// No description provided for @courseNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'课程名称'**
  String get courseNameLabel;

  /// No description provided for @teacherOptional.
  ///
  /// In zh, this message translates to:
  /// **'授课教师 (选填)'**
  String get teacherOptional;

  /// No description provided for @classroomOptional.
  ///
  /// In zh, this message translates to:
  /// **'教室 (选填)'**
  String get classroomOptional;

  /// No description provided for @pleaseEnterCourseName.
  ///
  /// In zh, this message translates to:
  /// **'请填写课程名称'**
  String get pleaseEnterCourseName;

  /// No description provided for @addedToTimetable.
  ///
  /// In zh, this message translates to:
  /// **'已添加到课表'**
  String get addedToTimetable;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @noAdjustmentsYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有任何调整'**
  String get noAdjustmentsYet;

  /// No description provided for @ruleTypeRescheduleDay.
  ///
  /// In zh, this message translates to:
  /// **'调休'**
  String get ruleTypeRescheduleDay;

  /// No description provided for @ruleTypeSuspension.
  ///
  /// In zh, this message translates to:
  /// **'停课'**
  String get ruleTypeSuspension;

  /// No description provided for @ruleTypeAddCourse.
  ///
  /// In zh, this message translates to:
  /// **'加课'**
  String get ruleTypeAddCourse;

  /// No description provided for @ruleDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get ruleDeleted;

  /// No description provided for @clearAllAdjustmentsConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空全部调整？'**
  String get clearAllAdjustmentsConfirmTitle;

  /// No description provided for @clearAllAdjustmentsConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'清空后课表恢复为教务原样。'**
  String get clearAllAdjustmentsConfirmContent;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @cleared.
  ///
  /// In zh, this message translates to:
  /// **'已清空'**
  String get cleared;

  /// No description provided for @clearAll.
  ///
  /// In zh, this message translates to:
  /// **'清空全部'**
  String get clearAll;

  /// No description provided for @keepOriginalPeriod.
  ///
  /// In zh, this message translates to:
  /// **'保持原节次'**
  String get keepOriginalPeriod;

  /// No description provided for @periodNumbered.
  ///
  /// In zh, this message translates to:
  /// **'第{period}节'**
  String periodNumbered(int period);

  /// No description provided for @periodTimeRange.
  ///
  /// In zh, this message translates to:
  /// **'第{start}-{end}节 {time}'**
  String periodTimeRange(int start, int end, String time);

  /// No description provided for @periodsRange.
  ///
  /// In zh, this message translates to:
  /// **'第{start}-{end}节'**
  String periodsRange(int start, int end);

  /// No description provided for @weekNumbered.
  ///
  /// In zh, this message translates to:
  /// **'第{week}周'**
  String weekNumbered(int week);

  /// No description provided for @courseSummaryText.
  ///
  /// In zh, this message translates to:
  /// **'第{sourceWeek}周《{course}》：{sourceDay}{sourceStart}-{sourceEnd}节 → 第{targetWeek}周{targetDay}{targetStart}-{targetEnd}节'**
  String courseSummaryText(
      int sourceWeek,
      String course,
      String sourceDay,
      int sourceStart,
      int sourceEnd,
      int targetWeek,
      String targetDay,
      int targetStart,
      int targetEnd);

  /// No description provided for @usualTimeFormat.
  ///
  /// In zh, this message translates to:
  /// **'平时：每周{day} 第{start}-{end}节 ({weeks})'**
  String usualTimeFormat(String day, int start, int end, String weeks);

  /// No description provided for @originalSlotFormat.
  ///
  /// In zh, this message translates to:
  /// **'周{day} 第{periods}节 ({weeks})'**
  String originalSlotFormat(String day, String periods, String weeks);

  /// No description provided for @originalPeriodSummary.
  ///
  /// In zh, this message translates to:
  /// **'原{day} 第{start}-{end}节'**
  String originalPeriodSummary(String day, int start, int end);

  /// No description provided for @noDeadlineHomework.
  ///
  /// In zh, this message translates to:
  /// **'无截止时间作业'**
  String get noDeadlineHomework;

  /// No description provided for @homeworkLoggingInWait.
  ///
  /// In zh, this message translates to:
  /// **'⏳ 正在登录中，请稍后...'**
  String get homeworkLoggingInWait;

  /// No description provided for @homeworkDetail.
  ///
  /// In zh, this message translates to:
  /// **'作业详情'**
  String get homeworkDetail;

  /// No description provided for @completeInChaoXing.
  ///
  /// In zh, this message translates to:
  /// **'在学习通里完成'**
  String get completeInChaoXing;

  /// No description provided for @manualAdd.
  ///
  /// In zh, this message translates to:
  /// **'手动添加'**
  String get manualAdd;

  /// No description provided for @movedToArchive.
  ///
  /// In zh, this message translates to:
  /// **'已移至存档'**
  String get movedToArchive;

  /// No description provided for @movedOutOfArchive.
  ///
  /// In zh, this message translates to:
  /// **'已移出存档'**
  String get movedOutOfArchive;

  /// No description provided for @homeworkDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除作业'**
  String get homeworkDeleted;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// No description provided for @homeworkTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'准备做什么？'**
  String get homeworkTitleHint;

  /// No description provided for @courseName.
  ///
  /// In zh, this message translates to:
  /// **'课程名称'**
  String get courseName;

  /// No description provided for @inputCourseHint.
  ///
  /// In zh, this message translates to:
  /// **'输入所属课程'**
  String get inputCourseHint;

  /// No description provided for @remark.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get remark;

  /// No description provided for @addRemarkHint.
  ///
  /// In zh, this message translates to:
  /// **'添加备注信息'**
  String get addRemarkHint;

  /// No description provided for @funcEvaluation.
  ///
  /// In zh, this message translates to:
  /// **'教评系统'**
  String get funcEvaluation;

  /// No description provided for @defaultHitokoto.
  ///
  /// In zh, this message translates to:
  /// **'自在东湖在湖东！'**
  String get defaultHitokoto;

  /// No description provided for @loggingInPleaseWait.
  ///
  /// In zh, this message translates to:
  /// **'正在登录，请稍候...'**
  String get loggingInPleaseWait;

  /// No description provided for @whatsNewHint.
  ///
  /// In zh, this message translates to:
  /// **'有什么新鲜事？'**
  String get whatsNewHint;

  /// No description provided for @enableClassReminderHere.
  ///
  /// In zh, this message translates to:
  /// **'在这里开启上课提醒'**
  String get enableClassReminderHere;

  /// No description provided for @systemNotice.
  ///
  /// In zh, this message translates to:
  /// **'系统通知'**
  String get systemNotice;

  /// No description provided for @noticeTagNotice.
  ///
  /// In zh, this message translates to:
  /// **'通'**
  String get noticeTagNotice;

  /// No description provided for @scoreGradeExcellent.
  ///
  /// In zh, this message translates to:
  /// **'优秀'**
  String get scoreGradeExcellent;

  /// No description provided for @scoreGradeFail.
  ///
  /// In zh, this message translates to:
  /// **'不及格'**
  String get scoreGradeFail;

  /// No description provided for @feedbackEmailSubject.
  ///
  /// In zh, this message translates to:
  /// **'自在东湖 App 反馈'**
  String get feedbackEmailSubject;

  /// No description provided for @bill.
  ///
  /// In zh, this message translates to:
  /// **'账单'**
  String get bill;

  /// No description provided for @pleaseSelectStartDate.
  ///
  /// In zh, this message translates to:
  /// **'请选择起始日期'**
  String get pleaseSelectStartDate;

  /// No description provided for @pleaseSelectEndDate.
  ///
  /// In zh, this message translates to:
  /// **'请选择截止日期'**
  String get pleaseSelectEndDate;

  /// No description provided for @endDateMustBeAfterStartDate.
  ///
  /// In zh, this message translates to:
  /// **'截止时间大于起始时间'**
  String get endDateMustBeAfterStartDate;

  /// No description provided for @endDateCannotBeInFuture.
  ///
  /// In zh, this message translates to:
  /// **'截止时间大于当前时间'**
  String get endDateCannotBeInFuture;

  /// No description provided for @dateRangeMaxOneMonth.
  ///
  /// In zh, this message translates to:
  /// **'日期区间最大为一个月!'**
  String get dateRangeMaxOneMonth;

  /// No description provided for @startDate.
  ///
  /// In zh, this message translates to:
  /// **'起始日期'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In zh, this message translates to:
  /// **'截止日期'**
  String get endDate;

  /// No description provided for @pleaseSelect.
  ///
  /// In zh, this message translates to:
  /// **'请选择'**
  String get pleaseSelect;

  /// No description provided for @type.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get type;

  /// No description provided for @transactionConsume.
  ///
  /// In zh, this message translates to:
  /// **'消费'**
  String get transactionConsume;

  /// No description provided for @transactionRecharge.
  ///
  /// In zh, this message translates to:
  /// **'充值'**
  String get transactionRecharge;

  /// No description provided for @transactionSubsidy.
  ///
  /// In zh, this message translates to:
  /// **'补助'**
  String get transactionSubsidy;

  /// No description provided for @transactionTransfer.
  ///
  /// In zh, this message translates to:
  /// **'转账'**
  String get transactionTransfer;

  /// No description provided for @noTransactions.
  ///
  /// In zh, this message translates to:
  /// **'暂无账单'**
  String get noTransactions;

  /// No description provided for @pleaseEnterValidAmountRange.
  ///
  /// In zh, this message translates to:
  /// **'请输入1-1000之间的整数金额'**
  String get pleaseEnterValidAmountRange;

  /// No description provided for @campusCardRecharge.
  ///
  /// In zh, this message translates to:
  /// **'校园卡充值'**
  String get campusCardRecharge;

  /// No description provided for @refreshBalance.
  ///
  /// In zh, this message translates to:
  /// **'刷新余额'**
  String get refreshBalance;

  /// No description provided for @cardNumberPrefix.
  ///
  /// In zh, this message translates to:
  /// **'卡号: {number}'**
  String cardNumberPrefix(String number);

  /// No description provided for @currentBalanceYuan.
  ///
  /// In zh, this message translates to:
  /// **'当前余额 (元)'**
  String get currentBalanceYuan;

  /// No description provided for @selectRechargeAmount.
  ///
  /// In zh, this message translates to:
  /// **'选择充值金额'**
  String get selectRechargeAmount;

  /// No description provided for @amountYuan.
  ///
  /// In zh, this message translates to:
  /// **'{amount}元'**
  String amountYuan(String amount);

  /// No description provided for @customAmount.
  ///
  /// In zh, this message translates to:
  /// **'其他金额'**
  String get customAmount;

  /// No description provided for @wechatPay.
  ///
  /// In zh, this message translates to:
  /// **'微信支付'**
  String get wechatPay;

  /// No description provided for @alipay.
  ///
  /// In zh, this message translates to:
  /// **'支付宝'**
  String get alipay;

  /// No description provided for @paymentProcessingWechatHint.
  ///
  /// In zh, this message translates to:
  /// **'支付处理中，请在微信中完成支付后稍候查询'**
  String get paymentProcessingWechatHint;

  /// No description provided for @paymentProcessingAlipayHint.
  ///
  /// In zh, this message translates to:
  /// **'暂未查询到到账，请在支付宝中完成支付后稍候重试'**
  String get paymentProcessingAlipayHint;

  /// No description provided for @rechargeCardSuccessElectricityFailed.
  ///
  /// In zh, this message translates to:
  /// **'校园卡充值成功，电费充值失败'**
  String get rechargeCardSuccessElectricityFailed;

  /// No description provided for @paymentSuccess.
  ///
  /// In zh, this message translates to:
  /// **'支付成功'**
  String get paymentSuccess;

  /// No description provided for @recharging.
  ///
  /// In zh, this message translates to:
  /// **'正在充值...'**
  String get recharging;

  /// No description provided for @paying.
  ///
  /// In zh, this message translates to:
  /// **'正在支付...'**
  String get paying;

  /// No description provided for @paymentConfirmationMethod.
  ///
  /// In zh, this message translates to:
  /// **'支付确认 ({method})'**
  String paymentConfirmationMethod(String method);

  /// No description provided for @paymentFailedWithReason.
  ///
  /// In zh, this message translates to:
  /// **'支付失败: {reason}'**
  String paymentFailedWithReason(String reason);

  /// No description provided for @pleaseWaitDoNotClose.
  ///
  /// In zh, this message translates to:
  /// **'请稍候，请勿关闭页面'**
  String get pleaseWaitDoNotClose;

  /// No description provided for @completePaymentInWechat.
  ///
  /// In zh, this message translates to:
  /// **'请在跳转后的微信中完成支付'**
  String get completePaymentInWechat;

  /// No description provided for @completePaymentInAlipay.
  ///
  /// In zh, this message translates to:
  /// **'请在跳转后的支付宝中完成支付'**
  String get completePaymentInAlipay;

  /// No description provided for @checkingPaymentStatus.
  ///
  /// In zh, this message translates to:
  /// **'查询中...'**
  String get checkingPaymentStatus;

  /// No description provided for @confirmPayment.
  ///
  /// In zh, this message translates to:
  /// **'确认支付'**
  String get confirmPayment;

  /// No description provided for @classroomInquiry.
  ///
  /// In zh, this message translates to:
  /// **'空教室查询'**
  String get classroomInquiry;

  /// No description provided for @building.
  ///
  /// In zh, this message translates to:
  /// **'教学楼'**
  String get building;

  /// No description provided for @periodSlot.
  ///
  /// In zh, this message translates to:
  /// **'节次'**
  String get periodSlot;

  /// No description provided for @capacityCount.
  ///
  /// In zh, this message translates to:
  /// **'容纳人数: {count}'**
  String capacityCount(String count);

  /// No description provided for @loadListFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'加载列表失败，请重试'**
  String get loadListFailedRetry;

  /// No description provided for @pleaseSelectCompleteRoom.
  ///
  /// In zh, this message translates to:
  /// **'请选择完整的房间信息'**
  String get pleaseSelectCompleteRoom;

  /// No description provided for @payElectricityCampusCard.
  ///
  /// In zh, this message translates to:
  /// **'缴电费 (校园卡支付)'**
  String get payElectricityCampusCard;

  /// No description provided for @payElectricity.
  ///
  /// In zh, this message translates to:
  /// **'缴电费'**
  String get payElectricity;

  /// No description provided for @rechargeFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'充值失败，请重试'**
  String get rechargeFailedRetry;

  /// No description provided for @rechargeFailedWithReason.
  ///
  /// In zh, this message translates to:
  /// **'充值失败: {reason}'**
  String rechargeFailedWithReason(String reason);

  /// No description provided for @fetchCardInfoFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取校园卡信息失败: {reason}'**
  String fetchCardInfoFailed(String reason);

  /// No description provided for @payElectricityWithRoom.
  ///
  /// In zh, this message translates to:
  /// **'缴电费 ({room})'**
  String payElectricityWithRoom(String room);

  /// No description provided for @electricityRechargeSuccess.
  ///
  /// In zh, this message translates to:
  /// **'电费充值成功'**
  String get electricityRechargeSuccess;

  /// No description provided for @electricityRechargeFailed.
  ///
  /// In zh, this message translates to:
  /// **'电费充值失败'**
  String get electricityRechargeFailed;

  /// No description provided for @electricityRechargeTitle.
  ///
  /// In zh, this message translates to:
  /// **'电费充值'**
  String get electricityRechargeTitle;

  /// No description provided for @currentRechargeRoom.
  ///
  /// In zh, this message translates to:
  /// **'当前充值房间'**
  String get currentRechargeRoom;

  /// No description provided for @refreshing.
  ///
  /// In zh, this message translates to:
  /// **'刷新中'**
  String get refreshing;

  /// No description provided for @noRoomSelectedYet.
  ///
  /// In zh, this message translates to:
  /// **'尚未选择房间'**
  String get noRoomSelectedYet;

  /// No description provided for @electricityBalance.
  ///
  /// In zh, this message translates to:
  /// **'电费余额'**
  String get electricityBalance;

  /// No description provided for @fetchFailedClickRetry.
  ///
  /// In zh, this message translates to:
  /// **'获取失败，点击重试'**
  String get fetchFailedClickRetry;

  /// No description provided for @campusArea.
  ///
  /// In zh, this message translates to:
  /// **'校区'**
  String get campusArea;

  /// No description provided for @dormBuilding.
  ///
  /// In zh, this message translates to:
  /// **'楼栋'**
  String get dormBuilding;

  /// No description provided for @dormRoom.
  ///
  /// In zh, this message translates to:
  /// **'房间'**
  String get dormRoom;

  /// No description provided for @campusCardPayment.
  ///
  /// In zh, this message translates to:
  /// **'校园卡支付'**
  String get campusCardPayment;

  /// No description provided for @alipayPayment.
  ///
  /// In zh, this message translates to:
  /// **'支付宝支付'**
  String get alipayPayment;

  /// No description provided for @paymentFailed.
  ///
  /// In zh, this message translates to:
  /// **'支付失败'**
  String get paymentFailed;

  /// No description provided for @campusCard.
  ///
  /// In zh, this message translates to:
  /// **'校园卡'**
  String get campusCard;

  /// No description provided for @balanceAmount.
  ///
  /// In zh, this message translates to:
  /// **'余额 ￥{balance}'**
  String balanceAmount(String balance);

  /// No description provided for @tapQrToRefresh.
  ///
  /// In zh, this message translates to:
  /// **'点击二维码以刷新'**
  String get tapQrToRefresh;

  /// No description provided for @paymentNotice.
  ///
  /// In zh, this message translates to:
  /// **'付款提示'**
  String get paymentNotice;

  /// No description provided for @paymentConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'支付确认'**
  String get paymentConfirmation;

  /// No description provided for @continuePayment.
  ///
  /// In zh, this message translates to:
  /// **'继续支付'**
  String get continuePayment;

  /// No description provided for @scanQrCode.
  ///
  /// In zh, this message translates to:
  /// **'扫一扫'**
  String get scanQrCode;

  /// No description provided for @scanQrCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'将二维码放入框内即可自动扫描'**
  String get scanQrCodeHint;

  /// No description provided for @conversionFailed.
  ///
  /// In zh, this message translates to:
  /// **'转换失败: {reason}'**
  String conversionFailed(String reason);

  /// No description provided for @openBrowserFailed.
  ///
  /// In zh, this message translates to:
  /// **'跳转浏览器失败'**
  String get openBrowserFailed;

  /// No description provided for @webVpnConverter.
  ///
  /// In zh, this message translates to:
  /// **'WebVPN 转换器'**
  String get webVpnConverter;

  /// No description provided for @webVpnDescription.
  ///
  /// In zh, this message translates to:
  /// **'将普通校内链接转换为 WebVPN 链接，以便在校外直接访问。'**
  String get webVpnDescription;

  /// No description provided for @originalUrl.
  ///
  /// In zh, this message translates to:
  /// **'原始地址'**
  String get originalUrl;

  /// No description provided for @conversionResult.
  ///
  /// In zh, this message translates to:
  /// **'转换结果'**
  String get conversionResult;

  /// No description provided for @copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboard;

  /// No description provided for @visit.
  ///
  /// In zh, this message translates to:
  /// **'访问'**
  String get visit;

  /// No description provided for @pasteUrlToConvertHint.
  ///
  /// In zh, this message translates to:
  /// **'在上方粘贴链接以开始转换'**
  String get pasteUrlToConvertHint;

  /// No description provided for @loadTimeoutCampusNetworkSlow.
  ///
  /// In zh, this message translates to:
  /// **'加载超时，可能是校内网络响应缓慢。'**
  String get loadTimeoutCampusNetworkSlow;

  /// No description provided for @takePhoto.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get chooseFromGallery;

  /// No description provided for @loadFailedWithReason.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {reason}'**
  String loadFailedWithReason(String reason);

  /// No description provided for @loadingProgress.
  ///
  /// In zh, this message translates to:
  /// **'加载中... {progress}%'**
  String loadingProgress(int progress);

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @query.
  ///
  /// In zh, this message translates to:
  /// **'查询'**
  String get query;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'没有数据'**
  String get noData;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @completed.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get completed;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @workspace.
  ///
  /// In zh, this message translates to:
  /// **'工作台'**
  String get workspace;

  /// No description provided for @sunshineService.
  ///
  /// In zh, this message translates to:
  /// **'阳光服务'**
  String get sunshineService;

  /// No description provided for @recentPublicAppeals.
  ///
  /// In zh, this message translates to:
  /// **'近期公开诉求'**
  String get recentPublicAppeals;

  /// No description provided for @noPublicAppeals.
  ///
  /// In zh, this message translates to:
  /// **'暂无符合条件的公开诉求'**
  String get noPublicAppeals;

  /// No description provided for @writeAppeal.
  ///
  /// In zh, this message translates to:
  /// **'填写诉求'**
  String get writeAppeal;

  /// No description provided for @appealDetails.
  ///
  /// In zh, this message translates to:
  /// **'诉求详情'**
  String get appealDetails;

  /// No description provided for @transferInfo.
  ///
  /// In zh, this message translates to:
  /// **'流转信息'**
  String get transferInfo;

  /// No description provided for @submitter.
  ///
  /// In zh, this message translates to:
  /// **'提交人'**
  String get submitter;

  /// No description provided for @anonymous.
  ///
  /// In zh, this message translates to:
  /// **'匿名'**
  String get anonymous;

  /// No description provided for @expectedDepartment.
  ///
  /// In zh, this message translates to:
  /// **'期望受理部门'**
  String get expectedDepartment;

  /// No description provided for @handlingDepartment.
  ///
  /// In zh, this message translates to:
  /// **'受理部门'**
  String get handlingDepartment;

  /// No description provided for @expectedResolveTime.
  ///
  /// In zh, this message translates to:
  /// **'期望解决时间'**
  String get expectedResolveTime;

  /// No description provided for @acceptedTime.
  ///
  /// In zh, this message translates to:
  /// **'受理时间'**
  String get acceptedTime;

  /// No description provided for @finishedTime.
  ///
  /// In zh, this message translates to:
  /// **'办结时间'**
  String get finishedTime;

  /// No description provided for @appealContent.
  ///
  /// In zh, this message translates to:
  /// **'诉求内容'**
  String get appealContent;

  /// No description provided for @noDescriptionAvailable.
  ///
  /// In zh, this message translates to:
  /// **'（暂无详细问题描述）'**
  String get noDescriptionAvailable;

  /// No description provided for @processingResult.
  ///
  /// In zh, this message translates to:
  /// **'处理结果'**
  String get processingResult;

  /// No description provided for @sunshineFormTitle.
  ///
  /// In zh, this message translates to:
  /// **'阳光服务填报'**
  String get sunshineFormTitle;

  /// No description provided for @sunshineNotice.
  ///
  /// In zh, this message translates to:
  /// **'欢迎为学校建设与发展建言献策。带 * 的栏目为必填项。\n一般问题 1–3 个工作日办复，复杂问题最长不超过 7 个工作日（以平台说明为准）。相同内容请勿重复提交或一信多投。'**
  String get sunshineNotice;

  /// No description provided for @confirmSubmitAppeal.
  ///
  /// In zh, this message translates to:
  /// **'确认提交诉求'**
  String get confirmSubmitAppeal;

  /// No description provided for @confirmSubmitAppealMessage.
  ///
  /// In zh, this message translates to:
  /// **'将以 {identity} 的身份向“{department}”提交{type}：\n\n{title}\n\n请确认内容真实准确，相同内容请勿重复提交。'**
  String confirmSubmitAppealMessage(
      String identity, String department, String type, String title);

  /// No description provided for @continueEditing.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get continueEditing;

  /// No description provided for @confirmSubmit.
  ///
  /// In zh, this message translates to:
  /// **'确认提交'**
  String get confirmSubmit;

  /// No description provided for @appealTypeInquiry.
  ///
  /// In zh, this message translates to:
  /// **'咨询'**
  String get appealTypeInquiry;

  /// No description provided for @appealTypeSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'建议'**
  String get appealTypeSuggestion;

  /// No description provided for @appealTypeComplaint.
  ///
  /// In zh, this message translates to:
  /// **'投诉'**
  String get appealTypeComplaint;

  /// No description provided for @appealTypePraise.
  ///
  /// In zh, this message translates to:
  /// **'表扬'**
  String get appealTypePraise;

  /// No description provided for @appealSubmitSuccessMsg.
  ///
  /// In zh, this message translates to:
  /// **'您的诉求已受理，感谢您对学校工作的支持。'**
  String get appealSubmitSuccessMsg;

  /// No description provided for @appealSubmitPhoneCodeInvalidMsg.
  ///
  /// In zh, this message translates to:
  /// **'平台提示手机号或验证码不正确。请核对手机号；如需验证码，请在阳光服务官网完成验证。'**
  String get appealSubmitPhoneCodeInvalidMsg;

  /// No description provided for @appealSubmitDuplicateMsg.
  ///
  /// In zh, this message translates to:
  /// **'该类型问题已提交且正在处理，请勿重复提交。'**
  String get appealSubmitDuplicateMsg;

  /// No description provided for @appealSubmitUnknownMsg.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法确认是否提交成功，请先到阳光服务官网“与我相关”核实，勿重复提交。本页已暂停再次提交。'**
  String get appealSubmitUnknownMsg;

  /// No description provided for @submitResult.
  ///
  /// In zh, this message translates to:
  /// **'提交结果'**
  String get submitResult;

  /// No description provided for @submitSuccess.
  ///
  /// In zh, this message translates to:
  /// **'提交成功'**
  String get submitSuccess;

  /// No description provided for @gotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get gotIt;

  /// No description provided for @letterTypeRequired.
  ///
  /// In zh, this message translates to:
  /// **'信件类别 *'**
  String get letterTypeRequired;

  /// No description provided for @handlingDepartmentRequired.
  ///
  /// In zh, this message translates to:
  /// **'受理单位 *'**
  String get handlingDepartmentRequired;

  /// No description provided for @pleaseSelectHandlingDepartment.
  ///
  /// In zh, this message translates to:
  /// **'请选择受理单位'**
  String get pleaseSelectHandlingDepartment;

  /// No description provided for @subjectRequired.
  ///
  /// In zh, this message translates to:
  /// **'主题 *'**
  String get subjectRequired;

  /// No description provided for @contentRequired.
  ///
  /// In zh, this message translates to:
  /// **'内容 *'**
  String get contentRequired;

  /// No description provided for @appealContentHint.
  ///
  /// In zh, this message translates to:
  /// **'请描述具体情况及您的诉求'**
  String get appealContentHint;

  /// No description provided for @nameRequired.
  ///
  /// In zh, this message translates to:
  /// **'姓名 *'**
  String get nameRequired;

  /// No description provided for @phoneRequired.
  ///
  /// In zh, this message translates to:
  /// **'手机号码 *'**
  String get phoneRequired;

  /// No description provided for @pleaseEnterValidPhone.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 11 位手机号'**
  String get pleaseEnterValidPhone;

  /// No description provided for @emailOptional.
  ///
  /// In zh, this message translates to:
  /// **'Email（选填）'**
  String get emailOptional;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的邮箱地址'**
  String get pleaseEnterValidEmail;

  /// No description provided for @expectedResolveTimeOptional.
  ///
  /// In zh, this message translates to:
  /// **'期望解决时间（选填）'**
  String get expectedResolveTimeOptional;

  /// No description provided for @clearDate.
  ///
  /// In zh, this message translates to:
  /// **'清除日期'**
  String get clearDate;

  /// No description provided for @readNoticeAgreement.
  ///
  /// In zh, this message translates to:
  /// **'已阅读填报须知，确认内容真实准确'**
  String get readNoticeAgreement;

  /// No description provided for @fieldCannotBeEmpty.
  ///
  /// In zh, this message translates to:
  /// **'此项不能为空'**
  String get fieldCannotBeEmpty;

  /// No description provided for @fetchSunshineDetailFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载工单详情失败，请重试'**
  String get fetchSunshineDetailFailed;

  /// No description provided for @loadSunshineFormFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载填报信息失败，请检查网络后重试'**
  String get loadSunshineFormFailed;

  /// No description provided for @loadFailedCheckNetwork.
  ///
  /// In zh, this message translates to:
  /// **'加载失败，请检查网络后重试'**
  String get loadFailedCheckNetwork;

  /// No description provided for @statusInProgress.
  ///
  /// In zh, this message translates to:
  /// **'办理中'**
  String get statusInProgress;

  /// No description provided for @statusResolved.
  ///
  /// In zh, this message translates to:
  /// **'已办结'**
  String get statusResolved;

  /// No description provided for @statusUnknown.
  ///
  /// In zh, this message translates to:
  /// **'状态未知'**
  String get statusUnknown;

  /// No description provided for @sunshineServiceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'阳光服务暂时不可用，请稍后重试'**
  String get sunshineServiceUnavailable;

  /// No description provided for @sunshineDataReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能读取阳光服务数据，请检查登录状态后重试'**
  String get sunshineDataReadFailed;

  /// No description provided for @sunshineDataFormatError.
  ///
  /// In zh, this message translates to:
  /// **'阳光服务返回的数据格式异常'**
  String get sunshineDataFormatError;

  /// No description provided for @sunshineTicketNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到诉求工单详情'**
  String get sunshineTicketNotFound;

  /// No description provided for @sunshineFormTimeout.
  ///
  /// In zh, this message translates to:
  /// **'阳光服务表单响应超时，请稍后重试'**
  String get sunshineFormTimeout;

  /// No description provided for @ssoExpiredRelogin.
  ///
  /// In zh, this message translates to:
  /// **'统一认证已过期，请返回个人中心重新登录'**
  String get ssoExpiredRelogin;

  /// No description provided for @sunshineSessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'阳光服务登录已失效，请返回个人中心重新登录后重试'**
  String get sunshineSessionExpired;

  /// No description provided for @noDepartmentsAvailable.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用受理单位，请稍后重试'**
  String get noDepartmentsAvailable;

  /// No description provided for @reload.
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get reload;

  /// No description provided for @submit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get submit;

  /// No description provided for @studentWorkQuestionnaire.
  ///
  /// In zh, this message translates to:
  /// **'学工问卷'**
  String get studentWorkQuestionnaire;

  /// No description provided for @statusSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'已提交'**
  String get statusSubmitted;

  /// No description provided for @statusExpired.
  ///
  /// In zh, this message translates to:
  /// **'已截止'**
  String get statusExpired;

  /// No description provided for @statusPendingFill.
  ///
  /// In zh, this message translates to:
  /// **'待填写'**
  String get statusPendingFill;

  /// No description provided for @questionnaireDataError.
  ///
  /// In zh, this message translates to:
  /// **'问卷数据异常'**
  String get questionnaireDataError;

  /// No description provided for @pleaseFillQuestion.
  ///
  /// In zh, this message translates to:
  /// **'请填写: {title}'**
  String pleaseFillQuestion(String title);

  /// No description provided for @questionnaireCannotBeSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'该问卷当前不可提交'**
  String get questionnaireCannotBeSubmitted;

  /// No description provided for @submitFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'提交失败，请稍后重试'**
  String get submitFailedRetry;

  /// No description provided for @pleaseSelectDate.
  ///
  /// In zh, this message translates to:
  /// **'请选择日期'**
  String get pleaseSelectDate;

  /// No description provided for @pleaseEnterPhone.
  ///
  /// In zh, this message translates to:
  /// **'请输入电话'**
  String get pleaseEnterPhone;

  /// No description provided for @pleaseEnter.
  ///
  /// In zh, this message translates to:
  /// **'请输入'**
  String get pleaseEnter;

  /// No description provided for @noQuestionnairesFound.
  ///
  /// In zh, this message translates to:
  /// **'暂无符合条件的问卷'**
  String get noQuestionnairesFound;

  /// No description provided for @unnamedQuestionnaire.
  ///
  /// In zh, this message translates to:
  /// **'未命名问卷'**
  String get unnamedQuestionnaire;

  /// No description provided for @studentSystemSessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'学工系统登录已失效，请返回个人中心重新登录后重试'**
  String get studentSystemSessionExpired;

  /// No description provided for @readQuestionnaireDataFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能读取问卷数据，请检查登录状态后重试'**
  String get readQuestionnaireDataFailed;

  /// No description provided for @questionnaireListFormatError.
  ///
  /// In zh, this message translates to:
  /// **'问卷列表数据格式异常'**
  String get questionnaireListFormatError;

  /// No description provided for @questionnaireMissingTaskId.
  ///
  /// In zh, this message translates to:
  /// **'该问卷缺少任务标识，无法打开'**
  String get questionnaireMissingTaskId;

  /// No description provided for @leaveApplication.
  ///
  /// In zh, this message translates to:
  /// **'请假申请'**
  String get leaveApplication;

  /// No description provided for @pleaseFillRemark.
  ///
  /// In zh, this message translates to:
  /// **'请填写备注'**
  String get pleaseFillRemark;

  /// No description provided for @leaveType.
  ///
  /// In zh, this message translates to:
  /// **'请假类别'**
  String get leaveType;

  /// No description provided for @startTime.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get endTime;

  /// No description provided for @leaveDuration.
  ///
  /// In zh, this message translates to:
  /// **'请假时长'**
  String get leaveDuration;

  /// No description provided for @calculatingDuration.
  ///
  /// In zh, this message translates to:
  /// **'（试算中…）'**
  String get calculatingDuration;

  /// No description provided for @leaveReason.
  ///
  /// In zh, this message translates to:
  /// **'请假事由'**
  String get leaveReason;

  /// No description provided for @emergencyContact.
  ///
  /// In zh, this message translates to:
  /// **'紧急联系人'**
  String get emergencyContact;

  /// No description provided for @emergencyContactPhone.
  ///
  /// In zh, this message translates to:
  /// **'紧急联系人电话'**
  String get emergencyContactPhone;

  /// No description provided for @pleaseEnter11DigitPhone.
  ///
  /// In zh, this message translates to:
  /// **'请输入11位手机号'**
  String get pleaseEnter11DigitPhone;

  /// No description provided for @accompanyingPersons.
  ///
  /// In zh, this message translates to:
  /// **'同行人员'**
  String get accompanyingPersons;

  /// No description provided for @optional.
  ///
  /// In zh, this message translates to:
  /// **'选填'**
  String get optional;

  /// No description provided for @leaveCampus.
  ///
  /// In zh, this message translates to:
  /// **'离校'**
  String get leaveCampus;

  /// No description provided for @leaveDestination.
  ///
  /// In zh, this message translates to:
  /// **'离校去向'**
  String get leaveDestination;

  /// No description provided for @province.
  ///
  /// In zh, this message translates to:
  /// **'省'**
  String get province;

  /// No description provided for @city.
  ///
  /// In zh, this message translates to:
  /// **'市'**
  String get city;

  /// No description provided for @districtCounty.
  ///
  /// In zh, this message translates to:
  /// **'区/县'**
  String get districtCounty;

  /// No description provided for @detailedAddress.
  ///
  /// In zh, this message translates to:
  /// **'详细地址'**
  String get detailedAddress;

  /// No description provided for @returnToDormitory.
  ///
  /// In zh, this message translates to:
  /// **'回宿舍'**
  String get returnToDormitory;

  /// No description provided for @leaveCity.
  ///
  /// In zh, this message translates to:
  /// **'出市'**
  String get leaveCity;

  /// No description provided for @leaveProvince.
  ///
  /// In zh, this message translates to:
  /// **'出省'**
  String get leaveProvince;

  /// No description provided for @leaveMaterials.
  ///
  /// In zh, this message translates to:
  /// **'请假材料'**
  String get leaveMaterials;

  /// No description provided for @leaveMaterialsHint.
  ///
  /// In zh, this message translates to:
  /// **'选填，点击从相册选择'**
  String get leaveMaterialsHint;

  /// No description provided for @removeAttachment.
  ///
  /// In zh, this message translates to:
  /// **'移除附件'**
  String get removeAttachment;

  /// No description provided for @selectTimeAutoCalculateDuration.
  ///
  /// In zh, this message translates to:
  /// **'请选择起止时间自动计算'**
  String get selectTimeAutoCalculateDuration;

  /// No description provided for @pleaseSelectLeaveType.
  ///
  /// In zh, this message translates to:
  /// **'请选择请假类别'**
  String get pleaseSelectLeaveType;

  /// No description provided for @pleaseSelectStartTime.
  ///
  /// In zh, this message translates to:
  /// **'请选择开始时间'**
  String get pleaseSelectStartTime;

  /// No description provided for @pleaseSelectEndTime.
  ///
  /// In zh, this message translates to:
  /// **'请选择结束时间'**
  String get pleaseSelectEndTime;

  /// No description provided for @timeFormatErrorReselect.
  ///
  /// In zh, this message translates to:
  /// **'时间格式异常，请重新选择'**
  String get timeFormatErrorReselect;

  /// No description provided for @endTimeMustBeAfterStartTime.
  ///
  /// In zh, this message translates to:
  /// **'结束时间应大于开始时间！'**
  String get endTimeMustBeAfterStartTime;

  /// No description provided for @durationCalculateFailedReselect.
  ///
  /// In zh, this message translates to:
  /// **'时长计算失败，请重新选择起止时间'**
  String get durationCalculateFailedReselect;

  /// No description provided for @durationMustBeInteger.
  ///
  /// In zh, this message translates to:
  /// **'请假时长请输入整数！'**
  String get durationMustBeInteger;

  /// No description provided for @pleaseEnterValidDuration.
  ///
  /// In zh, this message translates to:
  /// **'请输入正确的请假时长！'**
  String get pleaseEnterValidDuration;

  /// No description provided for @pleaseFillLeaveReason.
  ///
  /// In zh, this message translates to:
  /// **'请填写请假事由'**
  String get pleaseFillLeaveReason;

  /// No description provided for @pleaseFillEmergencyContact.
  ///
  /// In zh, this message translates to:
  /// **'请填写紧急联系人'**
  String get pleaseFillEmergencyContact;

  /// No description provided for @pleaseFillEmergencyContactPhone.
  ///
  /// In zh, this message translates to:
  /// **'请填写紧急联系人电话'**
  String get pleaseFillEmergencyContactPhone;

  /// No description provided for @invalidEmergencyContactPhone.
  ///
  /// In zh, this message translates to:
  /// **'紧急联系人电话格式不正确'**
  String get invalidEmergencyContactPhone;

  /// No description provided for @pleaseSelectLeaveDestination.
  ///
  /// In zh, this message translates to:
  /// **'请选择离校去向'**
  String get pleaseSelectLeaveDestination;

  /// No description provided for @pleaseFillDetailedAddress.
  ///
  /// In zh, this message translates to:
  /// **'请填写离校详细地址'**
  String get pleaseFillDetailedAddress;

  /// No description provided for @cancelLeavePromptTitle.
  ///
  /// In zh, this message translates to:
  /// **'撤销请假?'**
  String get cancelLeavePromptTitle;

  /// No description provided for @cancelLeavePromptContent.
  ///
  /// In zh, this message translates to:
  /// **'确定撤销这条请假申请吗？'**
  String get cancelLeavePromptContent;

  /// No description provided for @revoke.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get revoke;

  /// No description provided for @revokedSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已撤销'**
  String get revokedSuccess;

  /// No description provided for @revokeFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'撤销失败，请稍后重试'**
  String get revokeFailedRetry;

  /// No description provided for @yes.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get no;

  /// No description provided for @durationDays.
  ///
  /// In zh, this message translates to:
  /// **'{days}天'**
  String durationDays(String days);

  /// No description provided for @durationHours.
  ///
  /// In zh, this message translates to:
  /// **'{hours}小时'**
  String durationHours(String hours);

  /// No description provided for @contactPhone.
  ///
  /// In zh, this message translates to:
  /// **'联系人电话'**
  String get contactPhone;

  /// No description provided for @isLeavingCampus.
  ///
  /// In zh, this message translates to:
  /// **'是否离校'**
  String get isLeavingCampus;

  /// No description provided for @practiceInstructor.
  ///
  /// In zh, this message translates to:
  /// **'实践指导老师'**
  String get practiceInstructor;

  /// No description provided for @attachment.
  ///
  /// In zh, this message translates to:
  /// **'附件'**
  String get attachment;

  /// No description provided for @auditStatus.
  ///
  /// In zh, this message translates to:
  /// **'审核状态'**
  String get auditStatus;

  /// No description provided for @leaveDetails.
  ///
  /// In zh, this message translates to:
  /// **'请假详情'**
  String get leaveDetails;

  /// No description provided for @leaveTypeDetails.
  ///
  /// In zh, this message translates to:
  /// **'{type}详情'**
  String leaveTypeDetails(String type);

  /// No description provided for @revokeApplication.
  ///
  /// In zh, this message translates to:
  /// **'撤销申请'**
  String get revokeApplication;

  /// No description provided for @statusPendingAudit.
  ///
  /// In zh, this message translates to:
  /// **'待审核'**
  String get statusPendingAudit;

  /// No description provided for @statusAuditing.
  ///
  /// In zh, this message translates to:
  /// **'审核中'**
  String get statusAuditing;

  /// No description provided for @statusAudited.
  ///
  /// In zh, this message translates to:
  /// **'已审核'**
  String get statusAudited;

  /// No description provided for @noLeaveRecordsFound.
  ///
  /// In zh, this message translates to:
  /// **'暂无符合条件的请假记录'**
  String get noLeaveRecordsFound;

  /// No description provided for @confirmRevokeLeaveItem.
  ///
  /// In zh, this message translates to:
  /// **'确定撤销《{type}》({timeRange})吗？'**
  String confirmRevokeLeaveItem(String type, String timeRange);

  /// No description provided for @library.
  ///
  /// In zh, this message translates to:
  /// **'图书馆'**
  String get library;

  /// No description provided for @libraryStatusPendingCheckIn.
  ///
  /// In zh, this message translates to:
  /// **'待签到'**
  String get libraryStatusPendingCheckIn;

  /// No description provided for @libraryStatusInUse.
  ///
  /// In zh, this message translates to:
  /// **'使用中'**
  String get libraryStatusInUse;

  /// No description provided for @libraryStatusAway.
  ///
  /// In zh, this message translates to:
  /// **'暂离中'**
  String get libraryStatusAway;

  /// No description provided for @libraryStatusCanCheckIn.
  ///
  /// In zh, this message translates to:
  /// **'可签到'**
  String get libraryStatusCanCheckIn;

  /// No description provided for @libraryStatusFinished.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get libraryStatusFinished;

  /// No description provided for @libraryStatusCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get libraryStatusCancelled;

  /// No description provided for @checkInSuccessEnjoy.
  ///
  /// In zh, this message translates to:
  /// **'签到成功！祝您学习愉快。'**
  String get checkInSuccessEnjoy;

  /// No description provided for @checkInFailedWithReason.
  ///
  /// In zh, this message translates to:
  /// **'签到失败: {reason}'**
  String checkInFailedWithReason(String reason);

  /// No description provided for @confirmCheckOutTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认退座？'**
  String get confirmCheckOutTitle;

  /// No description provided for @confirmCheckOutMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定结束在【{room}】的 {seat} 号座位使用吗？'**
  String confirmCheckOutMessage(String room, String seat);

  /// No description provided for @confirmCheckOut.
  ///
  /// In zh, this message translates to:
  /// **'确认退座'**
  String get confirmCheckOut;

  /// No description provided for @checkOutSuccess.
  ///
  /// In zh, this message translates to:
  /// **'退座成功'**
  String get checkOutSuccess;

  /// No description provided for @checkOutFailedWithReason.
  ///
  /// In zh, this message translates to:
  /// **'退座失败: {reason}'**
  String checkOutFailedWithReason(String reason);

  /// No description provided for @confirmCancelReservationTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认取消预约？'**
  String get confirmCancelReservationTitle;

  /// No description provided for @confirmCancelReservationMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定取消在【{room}】的 {seat} 号座位预约吗？'**
  String confirmCancelReservationMessage(String room, String seat);

  /// No description provided for @reservationCancelledSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已成功取消该预约'**
  String get reservationCancelledSuccess;

  /// No description provided for @cancelReservationFailedWithReason.
  ///
  /// In zh, this message translates to:
  /// **'取消失败: {reason}'**
  String cancelReservationFailedWithReason(String reason);

  /// No description provided for @submittingReservation.
  ///
  /// In zh, this message translates to:
  /// **'正在提交预约...'**
  String get submittingReservation;

  /// No description provided for @reservationSuccess.
  ///
  /// In zh, this message translates to:
  /// **'预约成功'**
  String get reservationSuccess;

  /// No description provided for @readingRoomLabel.
  ///
  /// In zh, this message translates to:
  /// **'阅览室：{room}'**
  String readingRoomLabel(String room);

  /// No description provided for @seatNumberLabel.
  ///
  /// In zh, this message translates to:
  /// **'座位号：{seat} 号'**
  String seatNumberLabel(String seat);

  /// No description provided for @dateLabel.
  ///
  /// In zh, this message translates to:
  /// **'日期：{date}'**
  String dateLabel(String date);

  /// No description provided for @timeValueLabel.
  ///
  /// In zh, this message translates to:
  /// **'时间：{time}'**
  String timeValueLabel(String time);

  /// No description provided for @reservationNotice.
  ///
  /// In zh, this message translates to:
  /// **'请在规定时间内完成签到，超时未签到将视为违规。'**
  String get reservationNotice;

  /// No description provided for @reservationFailed.
  ///
  /// In zh, this message translates to:
  /// **'预约失败'**
  String get reservationFailed;

  /// No description provided for @iUnderstand.
  ///
  /// In zh, this message translates to:
  /// **'我知道了'**
  String get iUnderstand;

  /// No description provided for @seatWithNumber.
  ///
  /// In zh, this message translates to:
  /// **'{seat} 号座位'**
  String seatWithNumber(String seat);

  /// No description provided for @cancelReservation.
  ///
  /// In zh, this message translates to:
  /// **'取消预约'**
  String get cancelReservation;

  /// No description provided for @checkIn.
  ///
  /// In zh, this message translates to:
  /// **'签到'**
  String get checkIn;

  /// No description provided for @checkOut.
  ///
  /// In zh, this message translates to:
  /// **'退座'**
  String get checkOut;

  /// No description provided for @reserveSeat.
  ///
  /// In zh, this message translates to:
  /// **'预约选座'**
  String get reserveSeat;

  /// No description provided for @recentReservations.
  ///
  /// In zh, this message translates to:
  /// **'近期预约记录'**
  String get recentReservations;

  /// No description provided for @noReservationRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史预约记录'**
  String get noReservationRecords;

  /// No description provided for @reserve.
  ///
  /// In zh, this message translates to:
  /// **'预约'**
  String get reserve;

  /// No description provided for @selectReadingRoom.
  ///
  /// In zh, this message translates to:
  /// **'选择阅览室'**
  String get selectReadingRoom;

  /// No description provided for @noRoomsFound.
  ///
  /// In zh, this message translates to:
  /// **'暂无符合条件的阅览室'**
  String get noRoomsFound;

  /// No description provided for @totalSeats.
  ///
  /// In zh, this message translates to:
  /// **'总座位数：{capacity}'**
  String totalSeats(String capacity);

  /// No description provided for @pleaseSelectSeatFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先在地图中选择一个座位'**
  String get pleaseSelectSeatFirst;

  /// No description provided for @refreshSeatStatus.
  ///
  /// In zh, this message translates to:
  /// **'刷新座位状态'**
  String get refreshSeatStatus;

  /// No description provided for @dateAndPeriod.
  ///
  /// In zh, this message translates to:
  /// **'日期：{day}  |  时段：{time}'**
  String dateAndPeriod(String day, String time);

  /// No description provided for @seatAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可选'**
  String get seatAvailable;

  /// No description provided for @seatSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选'**
  String get seatSelected;

  /// No description provided for @seatOccupied.
  ///
  /// In zh, this message translates to:
  /// **'占用/不可选'**
  String get seatOccupied;

  /// No description provided for @loadingSeatMap.
  ///
  /// In zh, this message translates to:
  /// **'正在加载座位分布图...'**
  String get loadingSeatMap;

  /// No description provided for @reserveNow.
  ///
  /// In zh, this message translates to:
  /// **'立即预约'**
  String get reserveNow;

  /// No description provided for @quickReserve.
  ///
  /// In zh, this message translates to:
  /// **'快速预约'**
  String get quickReserve;

  /// No description provided for @selectDate.
  ///
  /// In zh, this message translates to:
  /// **'选择日期'**
  String get selectDate;

  /// No description provided for @noAvailableSlotsForDate.
  ///
  /// In zh, this message translates to:
  /// **'该日期已无可用预约时段，请选择其他日期。'**
  String get noAvailableSlotsForDate;

  /// No description provided for @confirmReservationPeriod.
  ///
  /// In zh, this message translates to:
  /// **'确认预约 ({day} {start} - {end})'**
  String confirmReservationPeriod(String day, String start, String end);

  /// No description provided for @pleaseSelectValidPeriod.
  ///
  /// In zh, this message translates to:
  /// **'请选择有效时段'**
  String get pleaseSelectValidPeriod;

  /// No description provided for @selectReservationPeriod.
  ///
  /// In zh, this message translates to:
  /// **'选择预约时段'**
  String get selectReservationPeriod;

  /// No description provided for @confirmPeriod.
  ///
  /// In zh, this message translates to:
  /// **'确定时段'**
  String get confirmPeriod;

  /// No description provided for @todayWithDate.
  ///
  /// In zh, this message translates to:
  /// **'今天 ({date})'**
  String todayWithDate(String date);

  /// No description provided for @tomorrowWithDate.
  ///
  /// In zh, this message translates to:
  /// **'明天 ({date})'**
  String tomorrowWithDate(String date);

  /// No description provided for @monthDayFormat.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日'**
  String monthDayFormat(int month, int day);

  /// No description provided for @newVersionFoundSnackBar.
  ///
  /// In zh, this message translates to:
  /// **'🚀 发现新版本 v{version}，点击查看详情'**
  String newVersionFoundSnackBar(String version);

  /// No description provided for @viewAction.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get viewAction;

  /// No description provided for @alreadyLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get alreadyLatestVersion;

  /// No description provided for @checkUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败: {error}'**
  String checkUpdateFailed(String error);

  /// No description provided for @downloadingUpdate.
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新 v{version}...'**
  String downloadingUpdate(String version);

  /// No description provided for @downloadingUpdateTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新'**
  String get downloadingUpdateTitle;

  /// No description provided for @downloadFailedWithReason.
  ///
  /// In zh, this message translates to:
  /// **'下载失败: {error}'**
  String downloadFailedWithReason(String error);

  /// No description provided for @classReminderChannelName.
  ///
  /// In zh, this message translates to:
  /// **'上课提醒'**
  String get classReminderChannelName;

  /// No description provided for @classReminderChannelDesc.
  ///
  /// In zh, this message translates to:
  /// **'在每节课开始前发送提醒'**
  String get classReminderChannelDesc;

  /// No description provided for @homeworkReminderChannelName.
  ///
  /// In zh, this message translates to:
  /// **'作业截止提醒'**
  String get homeworkReminderChannelName;

  /// No description provided for @homeworkReminderChannelDesc.
  ///
  /// In zh, this message translates to:
  /// **'在作业截止前发送提醒'**
  String get homeworkReminderChannelDesc;

  /// No description provided for @libraryReminderChannelName.
  ///
  /// In zh, this message translates to:
  /// **'图书馆预约提醒'**
  String get libraryReminderChannelName;

  /// No description provided for @libraryReminderChannelDesc.
  ///
  /// In zh, this message translates to:
  /// **'在图书馆座位预约开始前发送提醒'**
  String get libraryReminderChannelDesc;

  /// No description provided for @homeworkDueInLessThan.
  ///
  /// In zh, this message translates to:
  /// **'作业将在不到{time}后截止'**
  String homeworkDueInLessThan(String time);

  /// No description provided for @homeworkDueIn.
  ///
  /// In zh, this message translates to:
  /// **'作业将在{time}后截止'**
  String homeworkDueIn(String time);

  /// No description provided for @minutesCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}分钟'**
  String minutesCount(int count);

  /// No description provided for @hoursCount.
  ///
  /// In zh, this message translates to:
  /// **'{count}小时'**
  String hoursCount(String count);

  /// No description provided for @seatNumberNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'{time} {seat}号座位'**
  String seatNumberNotificationTitle(String time, String seat);

  /// No description provided for @liveMinutesRemainingClass.
  ///
  /// In zh, this message translates to:
  /// **'还有 {minutes} 分钟上课'**
  String liveMinutesRemainingClass(int minutes);

  /// No description provided for @liveClassStartingTime.
  ///
  /// In zh, this message translates to:
  /// **'{time}开课'**
  String liveClassStartingTime(String time);

  /// No description provided for @liveMinutesRemainingSeat.
  ///
  /// In zh, this message translates to:
  /// **'还有 {minutes} 分钟开始 · 请按时签到'**
  String liveMinutesRemainingSeat(int minutes);

  /// No description provided for @liveSeatStartingTime.
  ///
  /// In zh, this message translates to:
  /// **'{time}开始'**
  String liveSeatStartingTime(String time);

  /// No description provided for @aiApiKeyNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置 API Key，请先在「AI 助理设置」中填入 API Key'**
  String get aiApiKeyNotConfigured;

  /// No description provided for @weeksRange.
  ///
  /// In zh, this message translates to:
  /// **'第{weeks}周'**
  String weeksRange(String weeks);

  /// No description provided for @ruleModeCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get ruleModeCopy;

  /// No description provided for @ruleModeSwap.
  ///
  /// In zh, this message translates to:
  /// **'对调'**
  String get ruleModeSwap;

  /// No description provided for @ruleModeShift.
  ///
  /// In zh, this message translates to:
  /// **'平移'**
  String get ruleModeShift;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'en',
        'es',
        'fr',
        'gan',
        'hsn',
        'ja',
        'pt',
        'ru',
        'wuu',
        'yue',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'hefei':
            return AppLocalizationsZhHefei();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'HK':
            return AppLocalizationsZhHk();
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'gan':
      return AppLocalizationsGan();
    case 'hsn':
      return AppLocalizationsHsn();
    case 'ja':
      return AppLocalizationsJa();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'wuu':
      return AppLocalizationsWuu();
    case 'yue':
      return AppLocalizationsYue();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
