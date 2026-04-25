import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../services/campus_card_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/route_utils.dart';
import 'payment_result_screen.dart';
import 'campus_card_recharge_screen.dart';

class PaymentCodeScreen extends ConsumerStatefulWidget {
  const PaymentCodeScreen({super.key});

  @override
  ConsumerState<PaymentCodeScreen> createState() => _PaymentCodeScreenState();
}

class _PaymentCodeScreenState extends ConsumerState<PaymentCodeScreen> with WidgetsBindingObserver {
  final _logger = AppLogger.instance;
  
  bool _isLoading = true;
  String? _error;
  String? _qrBase64;
  Uint8List? _qrBytes;
  String? _paycode;
  String? _userInfo;
  
  Timer? _refreshTimer;
  Timer? _statusTimer;
  
  int _refreshCountdown = 60;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPaymentCode();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPaymentCode();
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
      _statusTimer?.cancel();
    }
  }

  Future<void> _loadPaymentCode({bool isSilent = false}) async {
    if (!mounted) return;
    
    if (_qrBase64 == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final service = ref.read(campusCardServiceProvider);
      final data = await service.fetchPaymentCode();
      
      if (mounted) {
        setState(() {
          _qrBase64 = data['qrBase64'];
          if (_qrBase64 != null) {
            _qrBytes = base64Decode(_qrBase64!);
          }
          _paycode = data['paycode'];
          _userInfo = data['info'];
          _isLoading = false;
          _refreshCountdown = 60;
          _error = null;
        });
        
        _startTimers();
      }
    } catch (e) {
      _logger.e('Failed to load payment code: $e');
      if (mounted) {
        setState(() {
          if (!isSilent || _qrBase64 == null) {
            _error = e.toString();
            _isLoading = false;
          }
        });
      }
    }
  }

  void _startTimers() {
    _refreshTimer?.cancel();
    _statusTimer?.cancel();

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_refreshCountdown > 0) {
          _refreshCountdown--;
        } else {
          _loadPaymentCode(isSilent: true);
        }
      });
    });

    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _queryStatus();
    });
  }

  Future<void> _queryStatus() async {
    if (_paycode == null || _isPolling || !mounted) return;
    
    _isPolling = true;
    try {
      final service = ref.read(campusCardServiceProvider);
      final res = await service.queryOrderStatus(_paycode!);
      
      if (res['success'] == true) {
        final status = res['resultData']['status'];
        if (status == "1") {
          _handlePaymentSuccess(res['resultData']);
        } else if (["2", "4", "6", "7"].contains(status)) {
           _handlePaymentError(res['resultData']['message'] ?? '支付失败');
        }
      }
    } catch (e) {
      _logger.w('Query status error: $e');
    } finally {
      _isPolling = false;
    }
  }

  void _handlePaymentSuccess(Map<String, dynamic> data) {
    _statusTimer?.cancel();
    _refreshTimer?.cancel();
    
    String? amountStr;
    if (data['txamt'] != null) {
      amountStr = (double.parse(data['txamt'].toString()) / 100).toStringAsFixed(2);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PaymentResultSheet(
        type: PaymentResultType.success,
        merchantName: data['mercname'] ?? data['merchantName'],
        amount: amountStr,
        time: data['paytime'] ?? '',
        journalNo: data['journo'] ?? '',
      ),
    ).then((_) {
      if (mounted) _loadPaymentCode();
    });
  }

  String _getBalance() {
    if (_userInfo == null) return '0.00';
    try {
      // 尝试从 "姓名：xxx 余额：xx.xx" 中提取余额
      if (_userInfo!.contains('余额：')) {
        return _userInfo!.split('余额：').last.replaceAll('元', '').trim();
      }
    } catch (e) {
      _logger.w('Parse balance error: $e');
    }
    return '0.00';
  }

  void _handlePaymentError(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentResultSheet(
        type: PaymentResultType.failure,
        message: message,
      ),
    ).then((_) {
      if (mounted) _loadPaymentCode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // 主体蓝色卡片
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1677FF), // 支付宝蓝
                    borderRadius: BorderRadius.circular(6), // 圆角 8px
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 卡片顶栏
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.credit_card, size: 16, color: Color(0xFF1677FF)),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '校园卡',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: SizedBox(height: 38), // 保留原本“付款码”文字的高度空间
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // 二维码区域
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6), // 圆角 8px
                          ),
                          child: GestureDetector(
                            onTap: _isLoading ? null : () => _loadPaymentCode(),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 180,
                              height: 180,
                              alignment: Alignment.center,
                              child: (_isLoading && _qrBytes == null)
                                ? const CircularProgressIndicator(color: Color(0xFF1677FF))
                                : _error != null && _qrBytes == null
                                  ? const Icon(Icons.error_outline, color: Colors.red, size: 48)
                                  : _qrBytes != null
                                    ? Image.memory(
                                        _qrBytes!,
                                        width: 180,
                                        height: 180,
                                        fit: BoxFit.contain,
                                      )
                                    : const SizedBox(),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24), // 蓝色卡片下方增加空间
                
                // 余额展示卡片 (灰色圆角矩形)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.credit_card_outlined, 
                        size: 20, 
                        color: isDark ? Colors.white70 : Colors.black45,
                      ), // 镂空银行卡图标
                      const SizedBox(width: 12),
                      Text(
                        '余额 ￥${_getBalance()}', // 格式改为：余额 ￥x
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black.withOpacity(0.6), // 稍微灰一点的文字
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(context, createSlideUpRoute(const CampusCardRechargeScreen())).then((_) => _loadPaymentCode()),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('充值', style: TextStyle(color: Color(0xFF1677FF), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 提示语 (左对齐)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '点击二维码以刷新',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
