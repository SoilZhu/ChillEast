import 'package:flutter/material.dart';

enum PaymentResultType {
  success,
  failure,
  notice,
  confirm,
}

class PaymentResultSheet extends StatelessWidget {
  final PaymentResultType type;
  final String? merchantName;
  final String? amount;
  final String? message;
  final String? time;
  final String? journalNo;

  final VoidCallback? onConfirm;
  final String? confirmText;

  const PaymentResultSheet({
    super.key,
    required this.type,
    this.merchantName,
    this.amount,
    this.message,
    this.time,
    this.journalNo,
    this.onConfirm,
    this.confirmText,
  });

  @override
  Widget build(BuildContext context) {
    Color themeColor;
    IconData statusIcon;
    String statusTitle;

    switch (type) {
      case PaymentResultType.success:
        themeColor = const Color(0xFF1677FF);
        statusIcon = Icons.check_circle_outline;
        statusTitle = '支付成功';
        break;
      case PaymentResultType.failure:
        themeColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        statusTitle = '支付失败';
        break;
      case PaymentResultType.notice:
        themeColor = Colors.orange;
        statusIcon = Icons.info_outline;
        statusTitle = '付款提示';
        break;
      case PaymentResultType.confirm:
        themeColor = const Color(0xFF09C489); // Theme Green
        statusIcon = Icons.payment_outlined;
        statusTitle = '支付确认';
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态 (左对齐，小)
          Row(
            children: [
              Icon(statusIcon, size: 20, color: themeColor),
              const SizedBox(width: 8),
              Text(
                statusTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: themeColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 金额 (左对齐，中/大)
          if ((type == PaymentResultType.success || type == PaymentResultType.confirm) && amount != null && amount!.isNotEmpty)
            Text(
              '¥$amount',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            
          // 错误消息 (如果不是成功状态)
          if (type != PaymentResultType.success && type != PaymentResultType.confirm && message != null && message!.isNotEmpty)
            Text(
              message!,
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

          const SizedBox(height: 8),

          // 商户名 (如果有) (左对齐，小，淡色)
          if ((type == PaymentResultType.success || type == PaymentResultType.confirm) && merchantName != null && merchantName!.isNotEmpty)
            Text(
              merchantName!,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),

          const SizedBox(height: 32),
          
          // 底部操作 (右对齐)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 取消 (确认模式下)
              if (type == PaymentResultType.confirm)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              if (type == PaymentResultType.confirm) const SizedBox(width: 16),

              // 继续支付 (纯文字)
              if (type == PaymentResultType.success) ...[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '继续支付',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1677FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
              
              // 完成 / 确认 (按钮)
              SizedBox(
                width: 100,
                height: 40,
                child: ElevatedButton(
                  onPressed: type == PaymentResultType.confirm 
                    ? onConfirm 
                    : () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    type == PaymentResultType.confirm ? (confirmText ?? '确认支付') : '完成',
                    style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          // 底部安全区留白
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
