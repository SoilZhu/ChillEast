import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/campus_card_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/l10n_extension.dart';

const String kAlipaySvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g><path fill="none" d="M0 0h24v24H0z"/><path d="M21.422 15.358c-3.83-1.153-6.055-1.84-6.678-2.062a12.41 12.41 0 0 0 1.32-3.32H12.8V8.872h4v-.68h-4V6.344h-1.536c-.28 0-.312.248-.312.248v1.592H7.2v.68h3.752v1.104H7.88v.616h6.224a10.972 10.972 0 0 1-.888 2.176c-1.408-.464-2.192-.784-3.912-.944-3.256-.312-4.008 1.48-4.128 2.576C5 16.064 6.48 17.424 8.688 17.424s3.68-1.024 5.08-2.72c1.167.558 3.338 1.525 6.514 2.902A9.99 9.99 0 0 1 12 22C6.477 22 2 17.523 2 12S6.477 2 12 2s10 4.477 10 10a9.983 9.983 0 0 1-.578 3.358zm-12.99 1.01c-2.336 0-2.704-1.48-2.584-2.096.12-.616.8-1.416 2.104-1.416 1.496 0 2.832.384 4.44 1.16-1.136 1.48-2.52 2.352-3.96 2.352z"/></g></svg>''';
const String kWechatSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M8.691 2.188C3.891 2.188 0 5.478 0 9.53c0 2.212 1.17 4.203 3.002 5.55a.59.59 0 0 1 .213.665l-.39 1.48c-.019.07-.048.141-.048.213 0 .163.13.295.29.295a.326.326 0 0 0 .167-.054l1.903-1.114a.864.864 0 0 1 .717-.098 10.16 10.16 0 0 0 2.837.403c.276 0 .543-.027.811-.05-.858-2.525.405-5.32 2.964-6.494 1.706-.782 3.65-.77 5.342-.036C16.89 5.568 13.143 2.188 8.691 2.188zm-2.42 4.095c.578 0 1.047.469 1.048 1.048s-.469 1.048-1.048 1.048c-.579 0-1.048-.469-1.048-1.048s.47-1.048 1.048-1.048zm5.234 0c.579 0 1.048.469 1.048 1.048s-.47 1.048-1.048 1.048c-.579 0-1.048-.469-1.048-1.048s.47-1.048 1.048-1.048zm3.834 4.544c-3.993 0-7.23 2.742-7.23 6.124 0 1.843.975 3.502 2.502 4.625.138.102.21.272.177.444l-.325 1.233c-.016.059-.04.118-.04.178 0 .135.109.246.242.246.06 0 .12-.022.17-.057l1.586-.928a.72.72 0 0 1 .597-.082c.74.202 1.52.312 2.321.312 3.993 0 7.23-2.742 7.23-6.124 0-3.382-3.237-6.124-7.23-6.124zm-2.016 3.41c.482 0 .873.391.873.873s-.391.873-.873.873c-.482 0-.873-.391-.873-.873s.391-.873.873-.873zm4.362 0c.482 0 .873.391.873.873s-.391.873-.873.873c-.482 0-.873-.391-.873-.873s.391-.873.873-.873z"/></svg>''';

class CampusCardPaymentSheet extends ConsumerStatefulWidget {
  final String amount;
  final String merchantName;
  final CampusCardInfo info;
  final PaymentMethod paymentMethod;
  final String? successTitle;
  final Future<void> Function()? onCardRechargeSuccess;

  const CampusCardPaymentSheet({
    super.key,
    required this.amount,
    required this.merchantName,
    required this.info,
    this.paymentMethod = PaymentMethod.wechat,
    this.successTitle,
    this.onCardRechargeSuccess,
  });

  @override
  ConsumerState<CampusCardPaymentSheet> createState() => _CampusCardPaymentSheetState();
}

class _CampusCardPaymentSheetState extends ConsumerState<CampusCardPaymentSheet> with WidgetsBindingObserver {
  final _logger = AppLogger.instance;
  bool _isConfirming = true;
  bool _isPaying = false;
  bool _isSuccess = false;
  bool _isCheckingResult = false;
  bool _isExecutingSecondary = false;
  String? _error;
  String? _secondaryError;
  String? _htmlForm;

  WeChatRechargeOrder? _weChatOrder;
  Timer? _pollingTimer;
  bool _needsWeChatWebViewFallback = false;

  bool get _isWeChat => widget.paymentMethod == PaymentMethod.wechat;
  Color get _themeColor => _isWeChat ? const Color(0xFF07C160) : const Color(0xFF1677FF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isPaying && !_isSuccess && !_isExecutingSecondary) {
      if (_isWeChat) {
        _checkWeChatStatus(isManual: false);
      } else {
        _checkAlipayStatus(isManual: false);
      }
    }
  }

  Future<void> _startPayment() async {
    setState(() {
      _isConfirming = false;
      _isPaying = true;
      _error = null;
    });

    final service = ref.read(campusCardServiceProvider);

    if (widget.paymentMethod == PaymentMethod.alipay) {
      try {
        _htmlForm = await service.getAlipayForm(double.parse(widget.amount));
        if (mounted) setState(() {});
      } catch (e) {
        _logger.e('Failed to get alipay form: $e');
        if (mounted) {
          setState(() {
            _isPaying = false;
            _error = e.toString();
          });
        }
      }
    } else {
      // 微信支付流程
      try {
        final order = await service.createWeChatOrder(double.parse(widget.amount));
        _weChatOrder = order;

        // 尝试解析并唤起微信 deep link (weixin://wap/pay?...)
        final deepLink = await service.getWeChatDeepLink(order.mwebUrl);
        bool launched = false;
        if (deepLink != null) {
          final uri = Uri.parse(deepLink);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
          }
        }
        _needsWeChatWebViewFallback = !launched;

        // 启动后台定时轮询（每 3 秒一次，最多轮询 25 次即 75 秒）
        _startPollingWeChatStatus();

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        _logger.e('Failed to create wechat order: $e');
        if (mounted) {
          setState(() {
            _isPaying = false;
            _error = e.toString();
          });
        }
      }
    }
  }

  void _startPollingWeChatStatus() {
    _pollingTimer?.cancel();
    int pollCount = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      pollCount++;
      if (pollCount > 25 || _isSuccess || !mounted) {
        timer.cancel();
        return;
      }
      await _checkWeChatStatus(isManual: false);
    });
  }

  Future<void> _checkWeChatStatus({bool isManual = true}) async {
    if (_weChatOrder == null || _isSuccess || _isExecutingSecondary) return;
    if (isManual) {
      setState(() => _isCheckingResult = true);
    }
    try {
      final service = ref.read(campusCardServiceProvider);
      final result = await service.queryWeChatPayStatus(
        partnerjourno: _weChatOrder!.partnerjourno,
        returnurl: _weChatOrder!.returnurl,
      );

      if (result.isSuccess) {
        _pollingTimer?.cancel();
        await _handleSuccess();
      } else if (result.isPending) {
        if (isManual) {
          // 手动查询时，双重核验实际卡余额是否已经到账增加
          final oldBal = double.tryParse(widget.info.balance);
          if (oldBal != null) {
            final newInfo = await service.fetchRechargeInfo();
            final newBal = double.tryParse(newInfo.balance);
            if (newBal != null && newBal > oldBal) {
              _logger.i('🎉 Card balance increased from $oldBal to $newBal');
              _pollingTimer?.cancel();
              await _handleSuccess();
              return;
            }
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.paymentProcessingWechatHint)),
            );
          }
        }
      } else if (!result.isPending && result.message != null && isManual) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message!)),
          );
        }
      }
    } catch (e) {
      _logger.w('⚠️ Check WeChat status error: $e');
    } finally {
      if (isManual && mounted) {
        setState(() => _isCheckingResult = false);
      }
    }
  }

  Future<void> _checkAlipayStatus({bool isManual = true}) async {
    if (_isSuccess || _isExecutingSecondary) return;
    if (isManual) {
      setState(() => _isCheckingResult = true);
    }
    try {
      final service = ref.read(campusCardServiceProvider);
      final oldBal = double.tryParse(widget.info.balance);
      final newInfo = await service.fetchRechargeInfo(isRetry: true);
      final newBal = double.tryParse(newInfo.balance);
      if (oldBal != null && newBal != null && newBal > oldBal) {
        _logger.i('🎉 Alipay: Card balance increased from $oldBal to $newBal');
        await _handleSuccess();
        return;
      }
      if (isManual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.paymentProcessingAlipayHint)),
        );
      }
    } catch (e) {
      _logger.w('⚠️ Check Alipay status error: $e');
    } finally {
      if (isManual && mounted) {
        setState(() => _isCheckingResult = false);
      }
    }
  }

  Future<void> _handleSuccess() async {
    if (_isSuccess || _isExecutingSecondary) return;
    _pollingTimer?.cancel();

    // 触发外部校园卡余额刷新
    ref.read(campusCardServiceProvider).fetchRechargeInfo();

    if (widget.onCardRechargeSuccess != null) {
      if (mounted) {
        setState(() {
          _isPaying = false;
          _isExecutingSecondary = true;
          _error = null;
          _secondaryError = null;
        });
      }

      try {
        await widget.onCardRechargeSuccess!();
        if (mounted) {
          setState(() {
            _isExecutingSecondary = false;
            _isSuccess = true;
          });
          ref.read(campusCardServiceProvider).fetchRechargeInfo();
        }
      } catch (e) {
        _logger.e('Secondary action failed: $e');
        if (mounted) {
          setState(() {
            _isExecutingSecondary = false;
            _secondaryError = e.toString().replaceFirst('Exception: ', '');
          });
          ref.read(campusCardServiceProvider).fetchRechargeInfo();
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isPaying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(AppConstants.primaryColorValue);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态标题
          Row(
            children: [
              Icon(
                _isSuccess
                    ? Icons.check_circle_outline
                    : (_isExecutingSecondary
                        ? Icons.sync
                        : (_secondaryError != null
                            ? Icons.warning_amber_rounded
                            : (_isPaying ? Icons.hourglass_empty : Icons.payment_outlined))),
                size: 20,
                color: _isSuccess
                    ? primaryColor
                    : (_secondaryError != null
                        ? Colors.orange
                        : (_isExecutingSecondary ? primaryColor : _themeColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _secondaryError != null
                      ? context.l10n.rechargeCardSuccessElectricityFailed
                      : (_isSuccess
                          ? (widget.successTitle ?? context.l10n.paymentSuccess)
                          : (_isExecutingSecondary
                              ? context.l10n.recharging
                              : (_isPaying
                                  ? context.l10n.paying
                                  : context.l10n.paymentConfirmationMethod(_isWeChat ? context.l10n.wechatPay : context.l10n.alipay)))),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _isSuccess
                        ? primaryColor
                        : (_secondaryError != null
                            ? Colors.orange
                            : (_isExecutingSecondary ? primaryColor : _themeColor)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 金额
          Text(
            '¥${widget.amount}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),

          const SizedBox(height: 8),

          // 商户名 & 持卡人
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.merchantName,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
              Text(
                '${widget.info.name} (${widget.info.idserial})',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              context.l10n.paymentFailedWithReason(_error!),
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],

          if (_isExecutingSecondary) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.recharging,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.pleaseWaitDoNotClose,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          if (_isPaying && !_isSuccess && !_isExecutingSecondary && _secondaryError == null) ...[
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: _themeColor),
                  const SizedBox(height: 16),
                  Text(
                    _isWeChat ? context.l10n.completePaymentInWechat : context.l10n.completePaymentInAlipay,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isCheckingResult
                        ? null
                        : () => _isWeChat
                            ? _checkWeChatStatus(isManual: true)
                            : _checkAlipayStatus(isManual: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _themeColor,
                      side: BorderSide(color: _themeColor.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: _isCheckingResult
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _themeColor),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: Text(_isCheckingResult ? context.l10n.checkingPaymentStatus : context.l10n.completed),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isConfirming)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ),
              if (_isConfirming) const SizedBox(width: 16),

              if (_isConfirming)
                TextButton(
                  onPressed: _startPayment,
                  child: Text(context.l10n.confirmPayment, style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ),

              if (_isSuccess || _error != null || _secondaryError != null)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.ok, style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
            ],
          ),

          // 隐藏的 WebView 用来跑支付宝表单或微信兜底页面
          if (!_isSuccess && (_htmlForm != null || _needsWeChatWebViewFallback))
            SizedBox(
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0.01,
                child: InAppWebView(
                  initialData: _htmlForm != null ? InAppWebViewInitialData(data: _htmlForm!) : null,
                  initialUrlRequest: (_htmlForm == null && _needsWeChatWebViewFallback && _weChatOrder != null)
                      ? URLRequest(
                          url: WebUri(_weChatOrder!.mwebUrl),
                          headers: {'Referer': 'https://fin-serv.hunau.edu.cn/'},
                        )
                      : null,
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    userAgent: AppConstants.campusCardUA,
                  ),
                  onLoadStart: (controller, url) async {
                    final path = url?.path ?? '';
                    if (path.contains('paySuccess')) {
                      await _handleSuccess();
                    }
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final url = navigationAction.request.url?.toString() ?? '';
                    if (url.startsWith('alipays://') ||
                        url.startsWith('alipay://') ||
                        url.startsWith('weixin://')) {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
