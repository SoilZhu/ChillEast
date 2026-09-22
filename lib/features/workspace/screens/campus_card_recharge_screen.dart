import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/campus_card_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/l10n_extension.dart';
import 'campus_card_payment_sheet.dart';

class CampusCardRechargeScreen extends ConsumerStatefulWidget {
  const CampusCardRechargeScreen({super.key});

  @override
  ConsumerState<CampusCardRechargeScreen> createState() => _CampusCardRechargeScreenState();
}

class _CampusCardRechargeScreenState extends ConsumerState<CampusCardRechargeScreen> with WidgetsBindingObserver {
  final _logger = AppLogger.instance;
  final TextEditingController _amountController = TextEditingController();
  
  CampusCardInfo? _info;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  
  double? _selectedAmount;
  final List<double> _presetAmounts = [10, 30, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadInfo(isSilent: true);
    }
  }

  Future<void> _loadInfo({bool isSilent = false}) async {
    if (!mounted) return;
    if (_info == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      final service = ref.read(campusCardServiceProvider);
      final info = await service.fetchRechargeInfo();
      if (mounted) {
        setState(() {
          _info = info;
          _isLoading = false;
          _isRefreshing = false;
          _error = null;
        });
      }
    } catch (e) {
      _logger.e('Failed to load recharge info: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          if (!isSilent || _info == null) {
            _error = e.toString();
            _isLoading = false;
          }
        });
      }
    }
  }

  void _handlePresetAmountSelect(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _handleRecharge(PaymentMethod method) async {
    final amountText = _amountController.text;
    final amount = int.tryParse(amountText);
    
    if (amount == null || amount < 1 || amount > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseEnterValidAmountRange)),
      );
      return;
    }

    if (_info == null) return;

    // 直接显示原生的支付确认卡片，内部处理支付流程
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CampusCardPaymentSheet(
        amount: amountText,
        merchantName: context.l10n.campusCardRecharge,
        info: _info!,
        paymentMethod: method,
      ),
    ).then((_) {
      if (mounted) _loadInfo(isSilent: true); // 关闭后静默刷新最新余额
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = const Color(0xFF1677FF); // Alipay Blue for consistency
    final primaryColor = const Color(AppConstants.primaryColorValue);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.campusCardRecharge, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: context.l10n.refreshBalance,
            onPressed: _isRefreshing ? null : () => _loadInfo(isSilent: true),
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadInfo, 
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: Text(context.l10n.retry, style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // MD2 Style Info Card (Flat)
                  InkWell(
                    onTap: _isRefreshing ? null : () => _loadInfo(isSilent: true),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : primaryColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _info?.name ?? '---',
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.l10n.cardNumberPrefix(_info?.idserial ?? '---'),
                                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
                                  ),
                                 ],
                               ),
                               Icon(Icons.account_balance_wallet_outlined, color: primaryColor, size: 32),
                             ],
                           ),
                           const SizedBox(height: 24),
                           Row(
                             children: [
                               Text(
                                 context.l10n.currentBalanceYuan,
                                 style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
                               ),
                               const SizedBox(width: 6),
                               if (_isRefreshing)
                                 const SizedBox(
                                   width: 12,
                                   height: 12,
                                   child: CircularProgressIndicator(strokeWidth: 1.5),
                                 )
                               else
                                 Icon(
                                   Icons.refresh,
                                   size: 13,
                                   color: isDark ? Colors.white38 : Colors.black38,
                                 ),
                             ],
                           ),
                           const SizedBox(height: 4),
                           Text(
                             '¥${_info?.balance ?? '0.00'}',
                             style: TextStyle(color: primaryColor, fontSize: 32, fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                     ),
                   ),
                   
                   const SizedBox(height: 32),
                   
                   Text(
                     context.l10n.selectRechargeAmount,
                     style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54),
                   ),
                   const SizedBox(height: 16),
                   
                   // 金额预设网格 (MD2 Flat)
                   GridView.builder(
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 3,
                       crossAxisSpacing: 10,
                       mainAxisSpacing: 10,
                       childAspectRatio: 2.2,
                     ),
                     itemCount: _presetAmounts.length,
                     itemBuilder: (context, index) {
                       final amount = _presetAmounts[index];
                       final isSelected = _selectedAmount == amount;
                       return InkWell(
                         onTap: () => _handlePresetAmountSelect(amount),
                         borderRadius: BorderRadius.circular(6),
                         child: Container(
                           decoration: BoxDecoration(
                             color: isSelected ? themeColor : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                             borderRadius: BorderRadius.circular(6),
                             border: Border.all(
                               color: isSelected ? themeColor : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3)),
                             ),
                           ),
                           alignment: Alignment.center,
                           child: Text(
                             context.l10n.amountYuan(amount.toStringAsFixed(0)),
                             style: TextStyle(
                               color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                               fontSize: 15,
                             ),
                           ),
                         ),
                       );
                     },
                   ),
                   
                   const SizedBox(height: 16),
                   
                   // 自定义金额输入 (MD2 Outlined)
                   TextField(
                     controller: _amountController,
                     keyboardType: TextInputType.number,
                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                     decoration: InputDecoration(
                       labelText: context.l10n.customAmount,
                       labelStyle: TextStyle(color: isDark ? themeColor.withOpacity(0.8) : themeColor),
                       prefixText: '¥ ',
                       filled: isDark,
                       fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                       border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(6),
                         borderSide: BorderSide(color: themeColor.withOpacity(0.3)),
                       ),
                       enabledBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(6),
                         borderSide: BorderSide(color: themeColor.withOpacity(0.3)),
                       ),
                       focusedBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(6),
                         borderSide: BorderSide(color: themeColor, width: 1.5),
                       ),
                     ),
                     style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                     onChanged: (value) {
                       setState(() {
                         _selectedAmount = double.tryParse(value);
                       });
                     },
                   ),
                   
                   const SizedBox(height: 48),
                   
                   // 右对齐的两个支付按钮 (微信支付 & 支付宝)
                   Row(
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                       // 微信支付按钮
                       SizedBox(
                         height: 44,
                         child: ElevatedButton(
                           onPressed: () => _handleRecharge(PaymentMethod.wechat),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: const Color(0xFF07C160),
                             foregroundColor: Colors.white,
                             elevation: 0,
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                           ),
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               SvgPicture.string(
                                 kWechatSvg,
                                 width: 22,
                                 height: 22,
                                 colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                               ),
                               const SizedBox(width: 8),
                               Text(
                                 context.l10n.wechatPay,
                                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                               ),
                             ],
                           ),
                         ),
                       ),
                       const SizedBox(width: 12),
                       // 支付宝按钮
                       SizedBox(
                         height: 44,
                         child: ElevatedButton(
                           onPressed: () => _handleRecharge(PaymentMethod.alipay),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: const Color(0xFF1677FF),
                             foregroundColor: Colors.white,
                             elevation: 0,
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                           ),
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               SvgPicture.string(
                                 kAlipaySvg,
                                 width: 22,
                                 height: 22,
                                 colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                               ),
                               const SizedBox(width: 8),
                               Text(
                                 context.l10n.alipay,
                                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                               ),
                             ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
    );
  }
}
