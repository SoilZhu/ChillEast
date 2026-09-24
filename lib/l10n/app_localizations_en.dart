// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ChillEast';

  @override
  String get settings => 'Settings';

  @override
  String get agentSettings => 'Agent Settings';

  @override
  String get appearanceSettings => 'Appearance Settings';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'System Default';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get english => 'English';

  @override
  String get traditionalChineseHK => 'Traditional Chinese (Hong Kong, China)';

  @override
  String get traditionalChineseTW => 'Traditional Chinese';

  @override
  String get japanese => 'Japanese';

  @override
  String get spanish => 'Spanish';

  @override
  String get french => 'French';

  @override
  String get portuguese => 'Portuguese';

  @override
  String get russian => 'Russian';

  @override
  String get cantonese => 'Cantonese';

  @override
  String get wuSuzhou => 'Wu';

  @override
  String get xiangChangsha => 'Xiang';

  @override
  String get jianghuaiHefei => 'Jianghuai Mandarin';

  @override
  String get ganNanchang => 'Gan';

  @override
  String get tabHome => 'Home';

  @override
  String get tabTimetable => 'Schedule';

  @override
  String get tabHomework => 'Homework';

  @override
  String get tabNotice => 'Notices';

  @override
  String get tabFunctions => 'Services';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get loggingInWait => 'Logging in, please wait...';

  @override
  String get profile => 'Profile';

  @override
  String get helpFeedback => 'Help & Feedback';

  @override
  String get about => 'About';

  @override
  String get logout => 'Log Out';

  @override
  String get notLoggedIn => 'Not Logged In';

  @override
  String get clickToLogin => 'Tap to log in for more features';

  @override
  String get defaultStudentName => 'HUNAU Student';

  @override
  String get logoutConfirmTitle => 'Confirm Logout';

  @override
  String get logoutConfirmContent =>
      'Logging out will clear your local credentials and disconnect data sync.';

  @override
  String get checkUpdate => 'Check for Updates';

  @override
  String get openSourceLicenses => 'Open Source Licenses';

  @override
  String get sendEmail => 'Send Email';

  @override
  String get developer => 'Developer';

  @override
  String get loginTitle => 'Login';

  @override
  String get loginSubtitle => 'Please log in to continue.';

  @override
  String get studentId => 'Student ID';

  @override
  String get studentIdHint => 'Please enter student ID';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Please enter password';

  @override
  String get loginButton => 'Log In';

  @override
  String get funcSunshine => 'Sunshine Service';

  @override
  String get funcQuestionnaire => 'Student Questionnaires';

  @override
  String get funcLeave => 'Leave Requests';

  @override
  String get funcPaymentCode => 'Payment Code';

  @override
  String get funcRecharge => 'Card Top-up';

  @override
  String get funcLibrary => 'Library';

  @override
  String get funcEmptyClassroom => 'Available Classrooms';

  @override
  String get funcXgxt => 'Student Affairs';

  @override
  String get funcRepairs => 'Campus Repairs';

  @override
  String get repairWorkOrders => 'Repair work orders';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get funcGym => 'Gym Booking';

  @override
  String get funcTeachingEval => 'Teaching Eval';

  @override
  String get funcScore => 'Grades';

  @override
  String get funcVpn => 'VPN Converter';

  @override
  String get funcCampusCard => 'Campus Card';

  @override
  String get funcEleRecharge => 'Electricity Top-up';

  @override
  String get funcBus => 'Campus Bus';

  @override
  String get funcCsBus => 'Changsha Bus';

  @override
  String get funcCampusBusRoute => 'Campus Bus Routes';

  @override
  String get more => 'More';

  @override
  String get homeButtonsSetting => 'Home Button Layout & Visibility';

  @override
  String get homeButtonsTitle => 'Home Buttons';

  @override
  String get functionsButtonsSetting => 'Service Button Layout & Visibility';

  @override
  String get functionsButtonsTitle => 'Service Buttons';

  @override
  String get feedButtonsSetting => 'Feed Layout & Visibility';

  @override
  String get feedButtonsTitle => 'Home Feed';

  @override
  String get visibleFunctions => 'Visible Services';

  @override
  String get hiddenFunctions => 'Hidden Services (Drag here to hide)';

  @override
  String get dragToReorderTip =>
      'Long press and drag icons to reorder, show, or hide services';

  @override
  String get loginRequiredTitle => 'Login Required';

  @override
  String get loginRequiredMessage =>
      'Log in to view your schedule, homework, and grades';

  @override
  String get noticeTitle => 'Notices';

  @override
  String get noticeLoginTitle => 'Login required for notices';

  @override
  String get noticeLoginMessage =>
      'Log in to receive the latest school notices and announcements';

  @override
  String get loadingNotices => 'Loading notices...';

  @override
  String get loadFailed => 'Failed to load';

  @override
  String get retry => 'Retry';

  @override
  String get noNotices => 'No notices yet';

  @override
  String get noNoticesSubtitle => 'New messages will appear here';

  @override
  String get loadingMore => 'Loading more...';

  @override
  String get noMoreNotices => 'No more notices';

  @override
  String get homeworkLoginTitle => 'Login required to sync homework';

  @override
  String get homeworkLoginMessage =>
      'Log in to sync course homework from Chaoxing in real-time, or tap bottom-right to add manually';

  @override
  String get homeworkTabArchived => 'Archived';

  @override
  String get homeworkTabCompleted => 'Completed';

  @override
  String get homeworkTabPending => 'Pending';

  @override
  String get homeworkEmptyArchived => 'Archive is empty';

  @override
  String get homeworkEmptyCompleted => 'No completed homework yet';

  @override
  String get homeworkEmptyPending => 'No pending homework';

  @override
  String homeworkLoadFailed(String error) {
    return 'Failed to load homework: $error';
  }

  @override
  String get scoreQuery => 'Grades Inquiry';

  @override
  String get currentSemester => 'Current Semester';

  @override
  String get noScoreData => 'No grade records for this semester';

  @override
  String scoreCredit(String credit) {
    return 'Credits: $credit';
  }

  @override
  String get normalExam => 'Regular Exam';

  @override
  String get gradeExcellent => 'Excellent';

  @override
  String get gradeFailed => 'Failed';

  @override
  String get courseReminder => 'Class Reminder';

  @override
  String get courseReminderTime => 'Class Reminder Time';

  @override
  String get homeworkReminder => 'Homework Due Reminder';

  @override
  String get homeworkReminderTime => 'Homework Reminder Time';

  @override
  String get libraryReminder => 'Library Booking Reminder';

  @override
  String get libraryReminderTime => 'Library Reminder Time';

  @override
  String get notifDurationNone => 'Off';

  @override
  String notifMinutesBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String notifHoursBefore(String hours) {
    return '$hours hr before';
  }

  @override
  String setSuccessfully(String label) {
    return 'Set to: $label';
  }

  @override
  String setNotificationFailed(String error) {
    return 'Failed to set notification: $error';
  }

  @override
  String get liveUpdatesNotSupported =>
      'Current device does not support Live Updates (Android 16+ required)';

  @override
  String get needNotificationPermission => 'Notification permission required';

  @override
  String get liveActivity => 'Live Activity';

  @override
  String get liveActivitySubtitle => 'Reminders via Live Updates API';

  @override
  String get liveActivityEnabled => 'Live Activity enabled';

  @override
  String get liveActivityDisabled => 'Live Activity disabled';

  @override
  String get liveActivityEnabledFlymeDisabled =>
      'Live Activity enabled; Flyme Live Notifications disabled';

  @override
  String get flymeLive => 'Flyme Live Notifications';

  @override
  String get flymeLiveSubtitle => 'Reminders via Flyme Live Notifications API';

  @override
  String get flymeLiveEnabled => 'Flyme Live Notifications enabled';

  @override
  String get flymeLiveDisabled => 'Flyme Live Notifications disabled';

  @override
  String get flymeLiveEnabledActivityDisabled =>
      'Flyme Live Notifications enabled; Live Activity disabled';

  @override
  String get openSystemSettingsFailed =>
      'Unable to open system settings. Please open Settings > Notifications manually';

  @override
  String get doubleTapToRetract => 'Double-tap to dismiss';

  @override
  String get systemNotificationDisabled => 'System notifications disabled';

  @override
  String get testRetracted => 'Test dismissed';

  @override
  String get testSent => 'Test notification sent';

  @override
  String get sendFailedCheckPermission =>
      'Send failed: Please check notification permissions';

  @override
  String get aiSettingsSaved => '✅ Agent settings saved';

  @override
  String get aiSettingsResetDefaults => 'Defaults restored';

  @override
  String get aiApiUrl => 'API Base URL';

  @override
  String get aiApiUrlHint => 'Default relay service';

  @override
  String get aiModelName => 'Model Name';

  @override
  String get aiModelNameHint => 'Default: soilzhu-latest';

  @override
  String get aiApiKeyCustom => 'API Key (Custom)';

  @override
  String get aiApiKeyDefault => 'API Key (Default)';

  @override
  String get aiApiKeyHint =>
      'Leave empty for default key, or enter your key (sk-...)';

  @override
  String get paste => 'Paste';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get resetDefaults => 'Restore Defaults';

  @override
  String get ossDescription =>
      'ChillEast is built on various open source components. We respect and appreciate the contributions of every developer.';

  @override
  String get needLocationForBus =>
      'Location permission required to show nearby buses';

  @override
  String get libraryReservation => 'Library Booking';

  @override
  String get signIn => 'Check In';

  @override
  String get signBack => 'Check Out';

  @override
  String get signInSuccess => 'Check-in successful! Enjoy your study.';

  @override
  String signInFailed(String error) {
    return 'Check-in failed: $error';
  }

  @override
  String get signBackConfirmTitle => 'Confirm Check-out?';

  @override
  String signBackConfirmContent(String room, String seat) {
    return 'End usage of seat $seat in $room?';
  }

  @override
  String get thinkAgain => 'Think Again';

  @override
  String get confirmSignBack => 'Confirm Check-out';

  @override
  String get signBackSuccess => 'Checked out successfully';

  @override
  String signBackFailed(String error) {
    return 'Check-out failed: $error';
  }

  @override
  String get cancelReserveConfirmTitle => 'Cancel Reservation?';

  @override
  String cancelReserveConfirmContent(String room, String seat) {
    return 'Cancel reservation for seat $seat in $room?';
  }

  @override
  String get confirmCancel => 'Confirm Cancel';

  @override
  String get reserveCancelledSuccess => 'Reservation cancelled successfully';

  @override
  String cancelFailed(String error) {
    return 'Cancellation failed: $error';
  }

  @override
  String get tomorrowTimetable => 'Tomorrow\'s Schedule';

  @override
  String get todayTimetable => 'Today\'s Schedule';

  @override
  String get tomorrowAgenda => 'Tomorrow\'s agenda';

  @override
  String get todayAgenda => 'Today\'s agenda';

  @override
  String get timetableLoginRequiredTitle => 'Login Required for Schedule';

  @override
  String get timetableLoginRequiredMessage =>
      'Log in to sync and view your class schedule';

  @override
  String get viewAll => 'View All';

  @override
  String get noCoursesTomorrow => 'No classes scheduled for tomorrow';

  @override
  String get noCoursesToday => 'No classes scheduled for today';

  @override
  String get locationServiceDisabled => 'Location service disabled';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Location permission permanently denied. Please enable it in Settings.';

  @override
  String getLocationFailed(String error) {
    return 'Failed to get location: $error';
  }

  @override
  String get newChat => 'New Chat';

  @override
  String get requestException => 'Request Exception';

  @override
  String get checkAgentSettings => 'Check Agent Settings';

  @override
  String get checkAgentSettingsArrow => 'Check Agent Settings >';

  @override
  String get quickPromptsTitle => 'Quick Prompts';

  @override
  String get promptTodayCourses => 'What classes do I have today?';

  @override
  String get promptPendingHomework => 'What homework is due?';

  @override
  String get promptReserveLibrary => 'Book a library seat';

  @override
  String get promptSubmitSunshine => 'Submit Sunshine feedback';

  @override
  String get promptCampusCardBalance => 'Check campus card balance';

  @override
  String get promptDormElectricity => 'Check dorm electricity balance';

  @override
  String get promptEmptyClassrooms => 'Find empty classrooms now';

  @override
  String get promptImportantNotices => 'Any important recent notices?';

  @override
  String get copiedAnswer => 'Answer copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get aiThinking => 'Thinking...';

  @override
  String get noticeDetail => 'Notice Details';

  @override
  String get noticeNotFound => 'Notice details not found';

  @override
  String get noTitle => 'No Title';

  @override
  String get senderSystem => 'System';

  @override
  String get versionUpdate => 'App Update';

  @override
  String foundNewVersion(String version) {
    return 'New version available: v$version';
  }

  @override
  String get releaseNotes => 'Release Notes';

  @override
  String get updateNow => 'Update Now';

  @override
  String get later => 'Later';

  @override
  String get timetableRefreshed => 'Timetable refreshed';

  @override
  String timetableRefreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get noTimetableToShare => 'No timetable to share';

  @override
  String get timetableFileNotFound => 'Timetable file not found';

  @override
  String get shareTimetableText => 'My Hunan Agricultural University Timetable';

  @override
  String shareFailed(String error) {
    return 'Share failed: $error';
  }

  @override
  String get tabAgenda => 'Agenda';

  @override
  String get tabWeek => 'Week';

  @override
  String get adjustTimetable => 'Adjust Timetable';

  @override
  String get backToToday => 'Today';

  @override
  String get refreshTimetable => 'Refresh Timetable';

  @override
  String get timetableSettings => 'Timetable settings';

  @override
  String get notSet => 'Not set';

  @override
  String get timetableAutoSync => 'Auto-sync timetable';

  @override
  String get disableAutoSyncTitle => 'Turn off auto-sync?';

  @override
  String get disableAutoSyncMessage =>
      'Turning off will delete the local timetable (reschedule and suspension rules will be kept). To view your timetable, tap the refresh button on the timetable page to sync manually.';

  @override
  String get localTimetableDeleted => 'Local timetable deleted';

  @override
  String get noLocalTimetable => 'No local timetable';

  @override
  String get tapRefreshButtonToSync =>
      'Tap the refresh button above to sync manually';

  @override
  String get shareTimetable => 'Share Timetable';

  @override
  String get noCoursesThisSemester =>
      'No courses or homework scheduled for this semester';

  @override
  String get timetableInfoIncomplete => 'Timetable information is incomplete';

  @override
  String get pleaseReDownloadTimetable => 'Please re-download timetable';

  @override
  String get deadlinePrefix => 'Deadline';

  @override
  String get noDeadline => 'No deadline';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get month1 => 'January';

  @override
  String get month2 => 'February';

  @override
  String get month3 => 'March';

  @override
  String get month4 => 'April';

  @override
  String get month5 => 'May';

  @override
  String get month6 => 'June';

  @override
  String get month7 => 'July';

  @override
  String get month8 => 'August';

  @override
  String get month9 => 'September';

  @override
  String get month10 => 'October';

  @override
  String get month11 => 'November';

  @override
  String get month12 => 'December';

  @override
  String get fetchTimetable => 'Get Timetable';

  @override
  String get syncTimetablePrompt =>
      'You are logged in. Would you like to sync your courses and import to calendar now?';

  @override
  String get skip => 'Skip';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get academicSemester => 'Semester';

  @override
  String get firstWeekMonday => 'First Week Monday';

  @override
  String get selectDateHint => 'Please select a date';

  @override
  String get importButton => 'Import';

  @override
  String get selectFirstWeekMondayHelp =>
      'Select Monday of the first week of this semester';

  @override
  String get timetableImportSuccess => '🎉 Timetable imported successfully!';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get timetableSyncing => 'Syncing Timetable';

  @override
  String get timetableSyncingDesc =>
      'The system is fetching your timetable\nPlease wait a moment...';

  @override
  String get noTimetableFound => 'No timetable found';

  @override
  String weekNumber(int week) {
    return 'Week $week';
  }

  @override
  String get teacher => 'Teacher';

  @override
  String get classroom => 'Classroom';

  @override
  String get weeksLabel => 'Weeks';

  @override
  String get periodsLabel => 'Periods';

  @override
  String get timeLabel => 'Time';

  @override
  String get close => 'Close';

  @override
  String get unknown => 'Unknown';

  @override
  String get reschedule => 'Reschedule';

  @override
  String get suspension => 'Suspension';

  @override
  String get addCourse => 'Add Class';

  @override
  String get myAdjustments => 'My Adjustments';

  @override
  String get rescheduleSingleClass => 'Reschedule Class';

  @override
  String get rescheduleWholeDay => 'Reschedule Day';

  @override
  String get noCoursesSyncFirst =>
      'No courses yet, please sync timetable first';

  @override
  String get courseLabel => 'Course';

  @override
  String get classTimeSlot => 'Time Slot';

  @override
  String get originalWeek => 'Original Week';

  @override
  String get currentWeekSuffix => ' (This Week)';

  @override
  String noClassInWeek(int week) {
    return 'No class in week $week';
  }

  @override
  String get rescheduleTo => 'Reschedule To';

  @override
  String get rescheduleAway => 'Reschedule Away';

  @override
  String get targetWeek => 'Target Week';

  @override
  String get targetWeekday => 'Target Weekday';

  @override
  String get newWeek => 'New Week';

  @override
  String get newWeekday => 'New Weekday';

  @override
  String get newPeriod => 'New Period';

  @override
  String get originalWeekday => 'Original Weekday';

  @override
  String get noCoursesOnDay => 'No courses on that day';

  @override
  String get noCoursesOnDayCannotReschedule =>
      'No courses on that day, cannot reschedule';

  @override
  String get rescheduleMethod => 'Adjustment Method';

  @override
  String get rescheduleCopy => 'Copy';

  @override
  String get rescheduleShift => 'Shift';

  @override
  String get rescheduleSwap => 'Swap';

  @override
  String get rescheduleCopyDesc =>
      'Keep courses on original date; courses on target date will be overwritten';

  @override
  String get rescheduleSwapDesc => 'Courses of both days are swapped';

  @override
  String get rescheduleShiftDesc =>
      'Move courses without keeping original date; courses on target date will be overwritten';

  @override
  String get selectCourseFirst => 'Please select a course first';

  @override
  String get confirmReschedule => 'Confirm Reschedule';

  @override
  String rescheduleWarnNoCourse(int week, String course) {
    return 'Week $week does not have \"$course\". Continue?';
  }

  @override
  String get goBack => 'Go Back';

  @override
  String get continueAction => 'Continue';

  @override
  String get rescheduleSaved => 'Reschedule saved';

  @override
  String get rescheduleDaySaved => 'Day adjustment saved';

  @override
  String get save => 'Save';

  @override
  String get allCourses => 'All Courses';

  @override
  String get specifyPeriods => 'Specify Periods';

  @override
  String get startWeek => 'Start Week';

  @override
  String get endWeek => 'End Week';

  @override
  String get weekday => 'Weekday';

  @override
  String get startPeriod => 'Start Period';

  @override
  String get endPeriod => 'End Period';

  @override
  String get suspensionSaved => 'Suspension saved';

  @override
  String get addCourseTitle => 'Add Course';

  @override
  String get courseNameLabel => 'Course Name';

  @override
  String get teacherOptional => 'Teacher (Optional)';

  @override
  String get classroomOptional => 'Classroom (Optional)';

  @override
  String get pleaseEnterCourseName => 'Please enter course name';

  @override
  String get addedToTimetable => 'Added to timetable';

  @override
  String get add => 'Add';

  @override
  String get noAdjustmentsYet => 'No adjustments yet';

  @override
  String get ruleTypeRescheduleDay => 'Day Shift';

  @override
  String get ruleTypeSuspension => 'Suspension';

  @override
  String get ruleTypeAddCourse => 'Add Course';

  @override
  String get ruleDeleted => 'Deleted';

  @override
  String get clearAllAdjustmentsConfirmTitle => 'Clear all adjustments?';

  @override
  String get clearAllAdjustmentsConfirmContent =>
      'Restores the timetable to original educational system data.';

  @override
  String get clear => 'Clear';

  @override
  String get cleared => 'Cleared';

  @override
  String get clearAll => 'Clear All';

  @override
  String get keepOriginalPeriod => 'Keep Original Period';

  @override
  String periodNumbered(int period) {
    return 'Period $period';
  }

  @override
  String periodTimeRange(int start, int end, String time) {
    return 'Periods $start-$end $time';
  }

  @override
  String periodsRange(int start, int end) {
    return 'Periods $start-$end';
  }

  @override
  String weekNumbered(int week) {
    return 'Week $week';
  }

  @override
  String courseSummaryText(
      int sourceWeek,
      String course,
      String sourceDay,
      int sourceStart,
      int sourceEnd,
      int targetWeek,
      String targetDay,
      int targetStart,
      int targetEnd) {
    return 'W$sourceWeek \"$course\": $sourceDay P$sourceStart-$sourceEnd → W$targetWeek $targetDay P$targetStart-$targetEnd';
  }

  @override
  String usualTimeFormat(String day, int start, int end, String weeks) {
    return 'Regular: Every $day Periods $start-$end ($weeks)';
  }

  @override
  String originalSlotFormat(String day, String periods, String weeks) {
    return '$day Periods $periods ($weeks)';
  }

  @override
  String originalPeriodSummary(String day, int start, int end) {
    return 'Orig $day Periods $start-$end';
  }

  @override
  String get noDeadlineHomework => 'Homework without deadline';

  @override
  String get homeworkLoggingInWait => '⏳ Logging in, please wait...';

  @override
  String get homeworkDetail => 'Homework Detail';

  @override
  String get completeInChaoXing => 'Complete in Chaoxing';

  @override
  String get manualAdd => 'Manually added';

  @override
  String get movedToArchive => 'Moved to archive';

  @override
  String get movedOutOfArchive => 'Moved out of archive';

  @override
  String get homeworkDeleted => 'Homework deleted';

  @override
  String get undo => 'Undo';

  @override
  String get homeworkTitleHint => 'What are you planning to do?';

  @override
  String get courseName => 'Course Name';

  @override
  String get inputCourseHint => 'Enter course name';

  @override
  String get remark => 'Remark';

  @override
  String get addRemarkHint => 'Add remark';

  @override
  String get funcEvaluation => 'Teaching Evaluation';

  @override
  String get defaultHitokoto => 'ChillEast, ease in lake east!';

  @override
  String get loggingInPleaseWait => 'Logging in, please wait...';

  @override
  String get whatsNewHint => 'What\'s new?';

  @override
  String get enableClassReminderHere => 'Enable class reminders here';

  @override
  String get systemNotice => 'System Notice';

  @override
  String get noticeTagNotice => 'N';

  @override
  String get scoreGradeExcellent => 'Excellent';

  @override
  String get scoreGradeFail => 'Fail';

  @override
  String get feedbackEmailSubject => 'ChillEast App Feedback';

  @override
  String get bill => 'Bills';

  @override
  String get pleaseSelectStartDate => 'Please select start date';

  @override
  String get pleaseSelectEndDate => 'Please select end date';

  @override
  String get endDateMustBeAfterStartDate => 'End date must be after start date';

  @override
  String get endDateCannotBeInFuture => 'End date cannot be in the future';

  @override
  String get dateRangeMaxOneMonth => 'Date range cannot exceed one month!';

  @override
  String get startDate => 'Start Date';

  @override
  String get endDate => 'End Date';

  @override
  String get pleaseSelect => 'Please select';

  @override
  String get type => 'Type';

  @override
  String get transactionConsume => 'Expense';

  @override
  String get transactionRecharge => 'Top-up';

  @override
  String get transactionSubsidy => 'Subsidy';

  @override
  String get transactionTransfer => 'Transfer';

  @override
  String get noTransactions => 'No transactions yet';

  @override
  String get pleaseEnterValidAmountRange =>
      'Please enter an integer between 1 and 1000';

  @override
  String get campusCardRecharge => 'Campus Card Top-up';

  @override
  String get refreshBalance => 'Refresh Balance';

  @override
  String cardNumberPrefix(String number) {
    return 'Card: $number';
  }

  @override
  String get currentBalanceYuan => 'Current Balance (¥)';

  @override
  String get selectRechargeAmount => 'Select Amount';

  @override
  String amountYuan(String amount) {
    return '¥$amount';
  }

  @override
  String get customAmount => 'Other Amount';

  @override
  String get wechatPay => 'WeChat Pay';

  @override
  String get alipay => 'Alipay';

  @override
  String get paymentProcessingWechatHint =>
      'Payment processing, please complete in WeChat and check back shortly';

  @override
  String get paymentProcessingAlipayHint =>
      'Payment not detected yet. Please complete in Alipay and retry';

  @override
  String get rechargeCardSuccessElectricityFailed =>
      'Card top-up succeeded, but electricity recharge failed';

  @override
  String get paymentSuccess => 'Payment Successful';

  @override
  String get recharging => 'Recharging...';

  @override
  String get paying => 'Paying...';

  @override
  String paymentConfirmationMethod(String method) {
    return 'Confirm Payment ($method)';
  }

  @override
  String paymentFailedWithReason(String reason) {
    return 'Payment failed: $reason';
  }

  @override
  String get pleaseWaitDoNotClose => 'Please wait, do not close this page';

  @override
  String get completePaymentInWechat => 'Please complete payment in WeChat';

  @override
  String get completePaymentInAlipay => 'Please complete payment in Alipay';

  @override
  String get checkingPaymentStatus => 'Checking...';

  @override
  String get confirmPayment => 'Confirm Payment';

  @override
  String get classroomInquiry => 'Available Classrooms';

  @override
  String get building => 'Building';

  @override
  String get periodSlot => 'Period';

  @override
  String capacityCount(String count) {
    return 'Capacity: $count';
  }

  @override
  String get loadListFailedRetry => 'Failed to load list, please retry';

  @override
  String get pleaseSelectCompleteRoom => 'Please select complete room info';

  @override
  String get payElectricityCampusCard => 'Pay Electricity (Campus Card)';

  @override
  String get payElectricity => 'Pay Electricity';

  @override
  String get rechargeFailedRetry => 'Recharge failed, please retry';

  @override
  String rechargeFailedWithReason(String reason) {
    return 'Recharge failed: $reason';
  }

  @override
  String fetchCardInfoFailed(String reason) {
    return 'Failed to fetch card info: $reason';
  }

  @override
  String payElectricityWithRoom(String room) {
    return 'Pay Electricity ($room)';
  }

  @override
  String get electricityRechargeSuccess => 'Electricity recharge successful';

  @override
  String get electricityRechargeFailed => 'Electricity recharge failed';

  @override
  String get electricityRechargeTitle => 'Electricity Recharge';

  @override
  String get currentRechargeRoom => 'Current Room';

  @override
  String get refreshing => 'Refreshing';

  @override
  String get noRoomSelectedYet => 'No room selected yet';

  @override
  String get electricityBalance => 'Electricity Balance';

  @override
  String get fetchFailedClickRetry => 'Failed to load, tap to retry';

  @override
  String get campusArea => 'Campus';

  @override
  String get dormBuilding => 'Building';

  @override
  String get dormRoom => 'Room';

  @override
  String get campusCardPayment => 'Campus Card Payment';

  @override
  String get alipayPayment => 'Alipay Payment';

  @override
  String get paymentFailed => 'Payment Failed';

  @override
  String get campusCard => 'Campus Card';

  @override
  String balanceAmount(String balance) {
    return 'Balance: ¥$balance';
  }

  @override
  String get tapQrToRefresh => 'Tap QR code to refresh';

  @override
  String get paymentNotice => 'Payment Notice';

  @override
  String get paymentConfirmation => 'Payment Confirmation';

  @override
  String get continuePayment => 'Continue Payment';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get scanQrCodeHint => 'Place QR code inside frame to scan';

  @override
  String conversionFailed(String reason) {
    return 'Conversion failed: $reason';
  }

  @override
  String get openBrowserFailed => 'Failed to open browser';

  @override
  String get webVpnConverter => 'WebVPN Converter';

  @override
  String get webVpnDescription =>
      'Convert campus intranet links to WebVPN links for direct off-campus access.';

  @override
  String get originalUrl => 'Original URL';

  @override
  String get conversionResult => 'Conversion Result';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get visit => 'Visit';

  @override
  String get pasteUrlToConvertHint => 'Paste link above to start conversion';

  @override
  String get loadTimeoutCampusNetworkSlow =>
      'Load timed out. Campus network may be responding slowly.';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String loadFailedWithReason(String reason) {
    return 'Load failed: $reason';
  }

  @override
  String loadingProgress(int progress) {
    return 'Loading... $progress%';
  }

  @override
  String get all => 'All';

  @override
  String get query => 'Search';

  @override
  String get done => 'Done';

  @override
  String get noData => 'No data';

  @override
  String get ok => 'OK';

  @override
  String get completed => 'Completed';

  @override
  String get refresh => 'Refresh';

  @override
  String get workspace => 'Workspace';

  @override
  String get sunshineService => 'Sunshine Service';

  @override
  String get recentPublicAppeals => 'Recent Public Appeals';

  @override
  String get noPublicAppeals => 'No matching public appeals';

  @override
  String get writeAppeal => 'Submit Appeal';

  @override
  String get appealDetails => 'Appeal Details';

  @override
  String get transferInfo => 'Transfer Information';

  @override
  String get submitter => 'Submitter';

  @override
  String get anonymous => 'Anonymous';

  @override
  String get expectedDepartment => 'Expected Handling Department';

  @override
  String get handlingDepartment => 'Handling Department';

  @override
  String get expectedResolveTime => 'Expected Resolve Time';

  @override
  String get acceptedTime => 'Accepted Time';

  @override
  String get finishedTime => 'Finished Time';

  @override
  String get appealContent => 'Appeal Content';

  @override
  String get noDescriptionAvailable => '(No detailed description available)';

  @override
  String get processingResult => 'Processing Result';

  @override
  String get sunshineFormTitle => 'Sunshine Service Form';

  @override
  String get sunshineNotice =>
      'Welcome to provide advice and suggestions for school development. Fields marked with * are required.\nGeneral issues are handled within 1–3 working days; complex issues within 7 working days. Please do not submit duplicates.';

  @override
  String get confirmSubmitAppeal => 'Confirm Appeal Submission';

  @override
  String confirmSubmitAppealMessage(
      String identity, String department, String type, String title) {
    return 'Submitting $type to \"$department\" as $identity:\n\n$title\n\nPlease ensure details are accurate; do not submit duplicates.';
  }

  @override
  String get continueEditing => 'Continue Editing';

  @override
  String get confirmSubmit => 'Confirm Submit';

  @override
  String get appealTypeInquiry => 'Inquiry';

  @override
  String get appealTypeSuggestion => 'Suggestion';

  @override
  String get appealTypeComplaint => 'Complaint';

  @override
  String get appealTypePraise => 'Praise';

  @override
  String get appealSubmitSuccessMsg =>
      'Your appeal has been accepted. Thank you for supporting the school.';

  @override
  String get appealSubmitPhoneCodeInvalidMsg =>
      'Platform reports incorrect phone number or verification code. Please check your phone number.';

  @override
  String get appealSubmitDuplicateMsg =>
      'This type of issue has already been submitted and is processing. Please do not submit duplicates.';

  @override
  String get appealSubmitUnknownMsg =>
      'Cannot confirm submission status. Please check \"Related to Me\" on the portal. Duplicate submissions paused.';

  @override
  String get submitResult => 'Submission Result';

  @override
  String get submitSuccess => 'Submission Successful';

  @override
  String get gotIt => 'Got it';

  @override
  String get letterTypeRequired => 'Letter Type *';

  @override
  String get handlingDepartmentRequired => 'Handling Department *';

  @override
  String get pleaseSelectHandlingDepartment =>
      'Please select handling department';

  @override
  String get subjectRequired => 'Subject *';

  @override
  String get contentRequired => 'Content *';

  @override
  String get appealContentHint =>
      'Please describe the situation and your appeal';

  @override
  String get nameRequired => 'Name *';

  @override
  String get phoneRequired => 'Phone Number *';

  @override
  String get pleaseEnterValidPhone =>
      'Please enter a valid 11-digit phone number';

  @override
  String get emailOptional => 'Email (Optional)';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email address';

  @override
  String get expectedResolveTimeOptional => 'Expected Resolve Time (Optional)';

  @override
  String get clearDate => 'Clear Date';

  @override
  String get readNoticeAgreement =>
      'I have read the instructions and confirm the content is accurate';

  @override
  String get fieldCannotBeEmpty => 'This field cannot be empty';

  @override
  String get fetchSunshineDetailFailed =>
      'Failed to load appeal details, please retry';

  @override
  String get loadSunshineFormFailed =>
      'Failed to load form information, please check network and retry';

  @override
  String get loadFailedCheckNetwork =>
      'Loading failed, please check network and retry';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusResolved => 'Resolved';

  @override
  String get statusUnknown => 'Unknown Status';

  @override
  String get sunshineServiceUnavailable =>
      'Sunshine service is temporarily unavailable, please try again later';

  @override
  String get sunshineDataReadFailed =>
      'Failed to read sunshine data, please check login status and try again';

  @override
  String get sunshineDataFormatError => 'Sunshine data format error';

  @override
  String get sunshineTicketNotFound => 'Appeal ticket details not found';

  @override
  String get sunshineFormTimeout =>
      'Sunshine form response timed out, please try again later';

  @override
  String get ssoExpiredRelogin =>
      'SSO login expired, please return to profile and re-login';

  @override
  String get sunshineSessionExpired =>
      'Sunshine session expired, please re-login and try again';

  @override
  String get noDepartmentsAvailable =>
      'No handling departments available, please try again later';

  @override
  String get reload => 'Reload';

  @override
  String get submit => 'Submit';

  @override
  String get studentWorkQuestionnaire => 'Student Questionnaire';

  @override
  String get pendingQuestionnaires => 'Pending questionnaires';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusPendingFill => 'Pending';

  @override
  String get questionnaireDataError => 'Questionnaire data error';

  @override
  String pleaseFillQuestion(String title) {
    return 'Please fill: $title';
  }

  @override
  String get questionnaireCannotBeSubmitted =>
      'This questionnaire currently cannot be submitted';

  @override
  String get submitFailedRetry => 'Submission failed, please try again later';

  @override
  String get pleaseSelectDate => 'Please select date';

  @override
  String get pleaseEnterPhone => 'Please enter phone number';

  @override
  String get pleaseEnter => 'Please enter';

  @override
  String get noQuestionnairesFound => 'No matching questionnaires found';

  @override
  String get unnamedQuestionnaire => 'Unnamed Questionnaire';

  @override
  String get studentSystemSessionExpired =>
      'Student system session expired, please re-login and retry';

  @override
  String get readQuestionnaireDataFailed =>
      'Failed to read questionnaire data, please check login status';

  @override
  String get questionnaireListFormatError =>
      'Questionnaire list data format error';

  @override
  String get questionnaireMissingTaskId =>
      'Missing task ID, unable to open questionnaire';

  @override
  String get leaveApplication => 'Leave Application';

  @override
  String get pleaseFillRemark => 'Please enter remark';

  @override
  String get leaveType => 'Leave Type';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get leaveDuration => 'Leave Duration';

  @override
  String get calculatingDuration => '(Calculating...)';

  @override
  String get leaveReason => 'Reason for Leave';

  @override
  String get emergencyContact => 'Emergency Contact';

  @override
  String get emergencyContactPhone => 'Emergency Contact Phone';

  @override
  String get pleaseEnter11DigitPhone => 'Please enter 11-digit phone number';

  @override
  String get accompanyingPersons => 'Accompanying Persons';

  @override
  String get optional => 'Optional';

  @override
  String get leaveCampus => 'Leave Campus';

  @override
  String get leaveDestination => 'Leave Destination';

  @override
  String get province => 'Province';

  @override
  String get city => 'City';

  @override
  String get districtCounty => 'District/County';

  @override
  String get detailedAddress => 'Detailed Address';

  @override
  String get returnToDormitory => 'Return to Dorm';

  @override
  String get leaveCity => 'Leave City';

  @override
  String get leaveProvince => 'Leave Province';

  @override
  String get leaveMaterials => 'Leave Materials';

  @override
  String get leaveMaterialsHint => 'Optional, tap to choose from gallery';

  @override
  String get removeAttachment => 'Remove Attachment';

  @override
  String get selectTimeAutoCalculateDuration =>
      'Select start and end times to auto calculate';

  @override
  String get pleaseSelectLeaveType => 'Please select leave type';

  @override
  String get pleaseSelectStartTime => 'Please select start time';

  @override
  String get pleaseSelectEndTime => 'Please select end time';

  @override
  String get timeFormatErrorReselect => 'Invalid time format, please reselect';

  @override
  String get endTimeMustBeAfterStartTime =>
      'End time must be after start time!';

  @override
  String get durationCalculateFailedReselect =>
      'Duration calculation failed, please reselect start and end times';

  @override
  String get durationMustBeInteger => 'Leave duration must be an integer!';

  @override
  String get pleaseEnterValidDuration => 'Please enter a valid leave duration!';

  @override
  String get pleaseFillLeaveReason => 'Please enter leave reason';

  @override
  String get pleaseFillEmergencyContact => 'Please enter emergency contact';

  @override
  String get pleaseFillEmergencyContactPhone =>
      'Please enter emergency contact phone number';

  @override
  String get invalidEmergencyContactPhone =>
      'Invalid emergency contact phone number';

  @override
  String get pleaseSelectLeaveDestination =>
      'Please select departure destination';

  @override
  String get pleaseFillDetailedAddress =>
      'Please enter detailed departure address';

  @override
  String get cancelLeavePromptTitle => 'Cancel Leave Request?';

  @override
  String get cancelLeavePromptContent =>
      'Are you sure you want to cancel this leave request?';

  @override
  String get revoke => 'Revoke';

  @override
  String get revokedSuccess => 'Revoked successfully';

  @override
  String get revokeFailedRetry => 'Failed to revoke, please try again later';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String durationDays(String days) {
    return '$days days';
  }

  @override
  String durationHours(String hours) {
    return '$hours hours';
  }

  @override
  String get contactPhone => 'Contact Phone';

  @override
  String get isLeavingCampus => 'Leaving Campus';

  @override
  String get practiceInstructor => 'Practice Instructor';

  @override
  String get attachment => 'Attachment';

  @override
  String get auditStatus => 'Audit Status';

  @override
  String get leaveDetails => 'Leave Details';

  @override
  String leaveTypeDetails(String type) {
    return '$type Details';
  }

  @override
  String get revokeApplication => 'Revoke Request';

  @override
  String get statusPendingAudit => 'Pending';

  @override
  String get statusAuditing => 'In Review';

  @override
  String get statusAudited => 'Reviewed';

  @override
  String get noLeaveRecordsFound => 'No matching leave records found';

  @override
  String confirmRevokeLeaveItem(String type, String timeRange) {
    return 'Are you sure you want to revoke \"$type\" ($timeRange)?';
  }

  @override
  String get library => 'Library';

  @override
  String get libraryStatusPendingCheckIn => 'Pending Check-in';

  @override
  String get libraryStatusInUse => 'In Use';

  @override
  String get libraryStatusAway => 'Away';

  @override
  String get libraryStatusCanCheckIn => 'Can Check-in';

  @override
  String get libraryStatusFinished => 'Finished';

  @override
  String get libraryStatusCancelled => 'Cancelled';

  @override
  String get checkInSuccessEnjoy => 'Check-in successful! Enjoy your study.';

  @override
  String checkInFailedWithReason(String reason) {
    return 'Check-in failed: $reason';
  }

  @override
  String get confirmCheckOutTitle => 'Confirm Check-out?';

  @override
  String confirmCheckOutMessage(String room, String seat) {
    return 'Are you sure you want to check out from seat $seat in $room?';
  }

  @override
  String get confirmCheckOut => 'Confirm Check-out';

  @override
  String get checkOutSuccess => 'Checked out successfully';

  @override
  String checkOutFailedWithReason(String reason) {
    return 'Check-out failed: $reason';
  }

  @override
  String get confirmCancelReservationTitle => 'Cancel Reservation?';

  @override
  String confirmCancelReservationMessage(String room, String seat) {
    return 'Are you sure you want to cancel reservation for seat $seat in $room?';
  }

  @override
  String get reservationCancelledSuccess =>
      'Reservation cancelled successfully';

  @override
  String cancelReservationFailedWithReason(String reason) {
    return 'Cancellation failed: $reason';
  }

  @override
  String get submittingReservation => 'Submitting reservation...';

  @override
  String get reservationSuccess => 'Reservation Successful';

  @override
  String readingRoomLabel(String room) {
    return 'Reading Room: $room';
  }

  @override
  String seatNumberLabel(String seat) {
    return 'Seat No.: $seat';
  }

  @override
  String dateLabel(String date) {
    return 'Date: $date';
  }

  @override
  String timeValueLabel(String time) {
    return 'Time: $time';
  }

  @override
  String get reservationNotice =>
      'Please check in on time. Overdue check-ins will be marked as violations.';

  @override
  String get reservationFailed => 'Reservation Failed';

  @override
  String get iUnderstand => 'I Understand';

  @override
  String seatWithNumber(String seat) {
    return 'Seat $seat';
  }

  @override
  String get cancelReservation => 'Cancel Reservation';

  @override
  String get checkIn => 'Check-in';

  @override
  String get checkOut => 'Check-out';

  @override
  String get reserveSeat => 'Reserve Seat';

  @override
  String get recentReservations => 'Recent Reservations';

  @override
  String get noReservationRecords => 'No reservation history';

  @override
  String get reserve => 'Reserve';

  @override
  String get selectReadingRoom => 'Select Reading Room';

  @override
  String get noRoomsFound => 'No matching reading rooms found';

  @override
  String totalSeats(String capacity) {
    return 'Total Seats: $capacity';
  }

  @override
  String get pleaseSelectSeatFirst => 'Please select a seat on the map first';

  @override
  String get refreshSeatStatus => 'Refresh Seat Status';

  @override
  String dateAndPeriod(String day, String time) {
    return 'Date: $day  |  Time: $time';
  }

  @override
  String get seatAvailable => 'Available';

  @override
  String get seatSelected => 'Selected';

  @override
  String get seatOccupied => 'Occupied / Unavailable';

  @override
  String get loadingSeatMap => 'Loading seat map...';

  @override
  String get reserveNow => 'Reserve Now';

  @override
  String get quickReserve => 'Quick Reserve';

  @override
  String get selectDate => 'Select Date';

  @override
  String get noAvailableSlotsForDate =>
      'No available slots for this date. Please select another date.';

  @override
  String confirmReservationPeriod(String day, String start, String end) {
    return 'Confirm Reservation ($day $start - $end)';
  }

  @override
  String get pleaseSelectValidPeriod => 'Please select a valid time period';

  @override
  String get selectReservationPeriod => 'Select Reservation Period';

  @override
  String get confirmPeriod => 'Confirm Period';

  @override
  String todayWithDate(String date) {
    return 'Today ($date)';
  }

  @override
  String tomorrowWithDate(String date) {
    return 'Tomorrow ($date)';
  }

  @override
  String monthDayFormat(int month, int day) {
    return '$month/$day';
  }

  @override
  String newVersionFoundSnackBar(String version) {
    return '🚀 New version v$version found. Tap to view details';
  }

  @override
  String get viewAction => 'View';

  @override
  String get alreadyLatestVersion => 'Already on the latest version';

  @override
  String checkUpdateFailed(String error) {
    return 'Failed to check for updates: $error';
  }

  @override
  String downloadingUpdate(String version) {
    return 'Downloading update v$version...';
  }

  @override
  String get downloadingUpdateTitle => 'Downloading Update';

  @override
  String downloadFailedWithReason(String error) {
    return 'Download failed: $error';
  }

  @override
  String get classReminderChannelName => 'Class Reminder';

  @override
  String get classReminderChannelDesc =>
      'Send reminder before each class starts';

  @override
  String get homeworkReminderChannelName => 'Homework Due Reminder';

  @override
  String get homeworkReminderChannelDesc =>
      'Send reminder before homework is due';

  @override
  String get libraryReminderChannelName => 'Library Reservation Reminder';

  @override
  String get libraryReminderChannelDesc =>
      'Send reminder before library seat reservation starts';

  @override
  String homeworkDueInLessThan(String time) {
    return 'Homework is due in less than $time';
  }

  @override
  String homeworkDueIn(String time) {
    return 'Homework is due in $time';
  }

  @override
  String minutesCount(int count) {
    return '$count mins';
  }

  @override
  String hoursCount(String count) {
    return '$count hours';
  }

  @override
  String seatNumberNotificationTitle(String time, String seat) {
    return '$time Seat $seat';
  }

  @override
  String liveMinutesRemainingClass(int minutes) {
    return '$minutes mins until class';
  }

  @override
  String liveClassStartingTime(String time) {
    return 'Starts $time';
  }

  @override
  String liveMinutesRemainingSeat(int minutes) {
    return '$minutes mins until reservation · Please check in on time';
  }

  @override
  String liveSeatStartingTime(String time) {
    return 'Starts $time';
  }

  @override
  String get aiApiKeyNotConfigured =>
      'API Key is not configured. Please enter API Key in AI Assistant Settings first.';

  @override
  String weeksRange(String weeks) {
    return 'Weeks $weeks';
  }

  @override
  String get ruleModeCopy => 'Copy';

  @override
  String get ruleModeSwap => 'Swap';

  @override
  String get ruleModeShift => 'Shift';

  @override
  String get uploadImage => 'Upload Image';

  @override
  String get describeImagePrompt => 'Please analyze or describe this image';

  @override
  String get removeImage => 'Remove Image';

  @override
  String get repairsTitle => 'Campus Repairs';

  @override
  String get repairsQuickReport => 'Choose a repair type';

  @override
  String get repairsQuickReportHint =>
      'Use native forms instead of opening the web page';

  @override
  String get repairsMyOrders => 'My work orders';

  @override
  String get repairsMyOrdersHint =>
      'Work-order status is synchronized with campus repairs';

  @override
  String get repairsInProgress => 'In progress';

  @override
  String get repairsCompleted => 'Completed';

  @override
  String get repairsHeroTitle => 'Campus service, repaired in one tap';

  @override
  String get repairsHeroSubtitle =>
      'Native forms with synchronized work-order status. Choose the service type that best matches your issue.';

  @override
  String get repairsNoCompleted => 'No completed work orders';

  @override
  String get repairsNoOngoing => 'No ongoing work orders';

  @override
  String get repairsUnnamedOrder => 'Unnamed work order';

  @override
  String get repairsEnterValue => 'Enter or paste the platform value';

  @override
  String repairsRequiredField(String field) {
    return 'Please fill in $field';
  }

  @override
  String get repairsSubmitSuccess => 'Submitted';

  @override
  String get repairsSubmitSuccessMessage =>
      'Your work order was submitted. Track it under My work orders.';

  @override
  String get repairsFormHint =>
      'Fields marked * are required. Photo attachments can be captured or picked from gallery.';

  @override
  String get repairsSelectValue => 'Select';

  @override
  String get repairsSubmit => 'Submit work order';

  @override
  String get repairsSubmitting => 'Submitting…';

  @override
  String get repairsOrderDetail => 'Work order details';

  @override
  String get repairsOrderNumber => 'Number';

  @override
  String get repairsOrderStatus => 'Status';

  @override
  String get repairsOrderType => 'Service';

  @override
  String get repairsDepartment => 'Department';

  @override
  String get repairsCreatedAt => 'Created';

  @override
  String get repairsDescription => 'Description';

  @override
  String get repairsNoDescription => 'No description';

  @override
  String get repairsDrafts => 'Drafts';

  @override
  String get repairsNoDrafts => 'No drafts';

  @override
  String get repairsSaveDraft => 'Save draft';

  @override
  String get repairsSavingDraft => 'Saving draft…';

  @override
  String get repairsSaveDraftSuccess => 'Saved to drafts';

  @override
  String get repairsCancelOrder => 'Cancel repair';

  @override
  String get repairsCancellingOrder => 'Cancelling…';

  @override
  String get repairsCancelConfirmTitle => 'Cancel repair order?';

  @override
  String get repairsCancelConfirmMessage =>
      'Processing will stop after cancellation. Are you sure you want to cancel?';

  @override
  String get repairsCancelSuccess => 'Repair order has been cancelled';

  @override
  String get repairsApplicant => 'Applicant';

  @override
  String get repairsApplicantDepartment => 'Applicant department';

  @override
  String get repairsPhone => 'Phone';

  @override
  String get repairsHandler => 'Handler';

  @override
  String get repairsHandleResult => 'Resolution';

  @override
  String get repairsUserFeedback => 'Feedback';

  @override
  String get repairsRating => 'Rating';

  @override
  String get repairsSupplement => 'Notes';

  @override
  String get repairsPriority => 'Priority';

  @override
  String get repairsCurrentNode => 'Current step';

  @override
  String get repairsCompletedAt => 'Completed';

  @override
  String get repairsActivityTimeline => 'Activity history';

  @override
  String get repairsAttachments => 'Attachments';

  @override
  String get repairsNoActivity => 'No activity history';

  @override
  String get repairsUploadImage => 'Add Photo';

  @override
  String get repairsUploading => 'Uploading photo…';

  @override
  String get repairsUploadFailed => 'Failed to upload photo';

  @override
  String get repairsDeleteImage => 'Delete Photo';

  @override
  String get repairsDeleteConfirm => 'Delete this photo?';

  @override
  String get repairsSubmitTicket => 'Submit Repair Ticket';

  @override
  String get repairsSelectCategory => 'Select Repair Category';
}
