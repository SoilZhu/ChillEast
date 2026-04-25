/// App 全局常量定义
class AppConstants {
  // SSO统一认证中心
  static const String ssoBaseUrl = 'https://sso.hunau.edu.cn';
  static const String ssoLoginUrl = '$ssoBaseUrl/cas/login';
  static const String ssoMainPage = '$ssoBaseUrl/portal/main.html';
  
  // 融合门户
  static const String portalBaseUrl = 'https://portal.hunau.edu.cn';
  static const String portalIndexUrl = '$portalBaseUrl/index';
  static const String portalWorkspaceUrl = '$portalBaseUrl/fusion/workspace';

  // WebVPN
  static const String webvpnBaseUrl = 'https://webvpn.hunau.edu.cn';
  static const String webvpnLoginUrl = '$webvpnBaseUrl/login?cas_login=true';
  // 别名,保持向后兼容
  static String get fusionWorkspaceUrl => portalWorkspaceUrl;
  
  // 通知公告 (TODO: 需要确认实际URL)
  static String noticeDetailUrl(String id) => '$portalBaseUrl/fusion/notice/detail/$id';
  
  // 学工系统
  static const String xgxtBaseUrl = 'https://xgxt.hunau.edu.cn';
  static const String xgxtCasUrl = '$xgxtBaseUrl/cas';
  static const String xgxtWapUrl = '$xgxtBaseUrl/wap/main/welcome';
  
  // 教务系统 (TODO: 暂时保留，等待后续重构)
  static const String jwxtBaseUrl = 'http://jwxt.hunau.edu.cn';
  static const String jwxtSsoUrl = '$jwxtBaseUrl/sso.jsp';
  static const String jwxtCookieSyncUrl = '$jwxtBaseUrl/cookieSync';
  static const String jwxtTimetableUrl = '$jwxtBaseUrl/jsxsd/xskb/xskb_list.do';
  
  // CAS配置 (用于教务系统登录)
  static const String casLoginUrl = 'https://cas.hunau.edu.cn/cas/login';
  static const String casServiceForJwxt = '$jwxtSsoUrl';
  
  // API接口
  static const String fusionUserInfoUrl = '$portalBaseUrl/fusion/personal/getUserInfo';
  static String fusionAvatarUrl(String uid) => 'https://photo.chaoxing.com/p/${uid}_480';
  static const String fusionMessageListUrl = '$portalBaseUrl/fusion/message/getMessageListByWfw';
  static const String fusionMessageCookieSyncUrl = '$portalBaseUrl/fusion/page/toMessage';
  
  // 超星通知系统 (新API)
  static const String chaoxingNoticeBaseUrl = 'https://notice.chaoxing.com';
  static const String chaoxingNoticeListUrl = '$chaoxingNoticeBaseUrl/pc/notice/getNoticeList';
  // 超星通知详情页 (使用 uuid 解析)
  static String chaoxingNoticeDetailUrl(String uuid) => 
      '$chaoxingNoticeBaseUrl/pc/notice/$uuid/detail?sendTag=0';
  
  // 其他功能URL
  // 超星应用中心 - 教学评价 (会自动跳转到 jxpj.hunau.edu.cn)
  static const String teachingEvalUrl = 'https://v1.chaoxing.com/appInter/openPcApp?mappId=8056745';
  // 超星场馆预约系统
  static const String gymReservationUrl = 'https://reserve.chaoxing.com/front/web/apps/reservepc/index?reserveId=14191&fidEnc=a915b52ee0aa18ad';
  
  
  // 长沙公交查询
  static const String changshaBusUrl = 'https://xlcxweb.busrise.cn/h5/mycs/#/';
  static const String schoolBusUrl = 'https://bus.jingzhixx.com/h5/';
  static const String lecturesUrl = 'https://hd.chaoxing.com/hd/?marketId=18614&fidEnc=a915b52ee0aa18ad';
  
  // 办事大厅 (超星授权)
  static const String ehallUrl = 'https://auth.chaoxing.com/connect/oauth2/authorize?appid=b90d1387d9ea42e7bba56450e6eb7087&redirect_uri=https%3A%2F%2Fehall.hunau.edu.cn%2Fmobile%2Findex.html%3Fuseragent%3Dchaoxing%26appId%3Db90d1387d9ea42e7bba56450e6eb7087%26appKey%3DI7JYq0kU87gKgF2b%26uid%3D22073114%26fidEnc%3Da915b52ee0aa18ad%26mappId%3D4311705%26formid%3D&response_type=code&scope=snsapi_base&state=128516';
  // 图书馆预约 (超星授权)
  static const String libraryUrl = 'https://auth.chaoxing.com/connect/oauth2/authorize?appid=a78d8ada07784074a6ae839eb187d649&redirect_uri=https%3A%2F%2Flibseat.hunau.edu.cn%2Fappindex.aspx%3Funitcode%3Dhunau%26appId%3Da78d8ada07784074a6ae839eb187d649%26appKey%3D6z2PCy8Jr1eAD72j%26uid%3D67661390%26fidEnc%3Da915b52ee0aa18ad%26formid%3Dnull%26mappId%3D8234750&response_type=code&scope=snsapi_base&state=128516';
  // 校园卡 (超星授权)
  static const String campusCardUrl = 'https://auth.chaoxing.com/connect/oauth2/authorize?appid=5f1cdbd2506748a8a1d7cbe737e40d32&redirect_uri=http%3A%2F%2Ffin-serv.hunau.edu.cn%2Fhomecx%2FopenCXOAuthPage%3Furltype%3D1%26appId%3D5f1cdbd2506748a8a1d7cbe737e40d32%26appKey%3D8VT2Ov83Vv12M8ZC%26uid%3D22073114%26fidEnc%3Da915b52ee0aa18ad%26mappId%3D4556968%26formid%3Dnull&response_type=code&scope=snsapi_base&state=128516';
  static const String paymentCodeUrl = campusCardUrl; // 起始地址相同
  static const String campusCardUA = 'Mozilla/5.0 (Linux; Android 16; MEIZU 20 Build/BQ2A.251110.001-BP2A.250605.031.A3; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/147.0.7727.55 Mobile Safari/537.36 (device:MEIZU 20) Language/zh_CN com.chaoxing.mobile.hunannongyedaxue/ChaoXingStudy_1000257_5.3_android_phone_53_234 (Kalimdor)';
  
  // 报修平台
  static const String repairsBaseUrl = 'https://bxpt.hunau.edu.cn';
  static const String repairsIndexUrl = '$repairsBaseUrl/relax/mobile/index.html';
  static const String repairsSsoUrl = '$ssoLoginUrl?service=http%3A%2F%2Fbxpt.hunau.edu.cn%2Frelax%2Fsso%2Fcas%2Flogin';
  
  // 存储键名
  static const String storageUsernameKey = 'username';
  static const String storagePasswordKey = 'password';
  static const String storageTokenKey = 'token';
  static const String storageAuthStateKey = 'auth_state';
  
  // 学期默认值
  static const String defaultSemester = '2025-2026-2';
  
  // 主题色 - 湖南农业大学绿 (更新为 09C489)
  static const int primaryColorValue = 0xFF09C489;
}
