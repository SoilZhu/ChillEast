import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/campus_card_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/constants/app_constants.dart';
import 'payment_result_screen.dart';

class CampusCardPaymentSheet extends ConsumerStatefulWidget {
  final String amount;
  final String merchantName;
  final CampusCardInfo info;
  final PaymentMethod paymentMethod;

  const CampusCardPaymentSheet({
    super.key,
    required this.amount,
    required this.merchantName,
    required this.info,
    this.paymentMethod = PaymentMethod.wechat,
  });

  @override
  ConsumerState<CampusCardPaymentSheet> createState() => _CampusCardPaymentSheetState();
}

class _CampusCardPaymentSheetState extends ConsumerState<CampusCardPaymentSheet> {
  final _logger = AppLogger.instance;
  bool _isConfirming = true;
  bool _isPaying = false;
  bool _isSuccess = false;
  bool _isCheckingResult = false;
  String? _error;
  String? _htmlForm;

  WeChatRechargeOrder? _weChatOrder;
  Timer? _pollingTimer;
  bool _needsWeChatWebViewFallback = false;

  bool get _isWeChat => widget.paymentMethod == PaymentMethod.wechat;
  Color get _themeColor => _isWeChat ? const Color(0xFF07C160) : const Color(0xFF1677FF);

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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
    if (_weChatOrder == null || _isSuccess) return;
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
        _handleSuccess();
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
              _handleSuccess();
              return;
            }
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('支付处理中，请在微信中完成支付后稍候查询')),
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

  void _handleSuccess() {
    if (_isSuccess) return;
    _pollingTimer?.cancel();
    setState(() {
      _isSuccess = true;
      _isPaying = false;
    });
    // 通知外部刷新余额
    ref.read(campusCardServiceProvider).fetchRechargeInfo();
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
                    : (_isPaying ? Icons.hourglass_empty : Icons.payment_outlined),
                size: 20,
                color: _isSuccess ? primaryColor : _themeColor,
              ),
              const SizedBox(width: 8),
              Text(
                _isSuccess
                    ? '支付成功'
                    : (_isPaying
                        ? '正在支付...'
                        : '支付确认 (${_isWeChat ? '微信支付' : '支付宝'})'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _isSuccess ? primaryColor : _themeColor,
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
              '支付失败: $_error',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],

          const SizedBox(height: 28),

          if (_isPaying && !_isSuccess) ...[
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: _themeColor),
                  const SizedBox(height: 16),
                  Text(
                    _isWeChat ? '请在跳转后的微信中完成支付' : '请在跳转后的支付宝中完成支付',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  if (_isWeChat) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isCheckingResult
                          ? null
                          : () => _checkWeChatStatus(isManual: true),
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
                          : const Icon(Icons.refresh, size: 16),
                      label: Text(_isCheckingResult ? '查询中...' : '已完成支付，查询结果'),
                    ),
                  ],
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
                  child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ),
              if (_isConfirming) const SizedBox(width: 16),

              if (_isConfirming)
                TextButton(
                  onPressed: _startPayment,
                  child: Text('确认支付', style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ),

              if (_isSuccess || _error != null)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('确定', style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
                      _handleSuccess();
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
