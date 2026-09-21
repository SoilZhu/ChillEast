/// 校园卡流水记录
class TransactionRecord {
  /// 商户名称 (JS 字段 `mername`)
  final String merchantName;

  /// 金额 (JS 字段 `txamt`，原样展示)
  final String amount;

  /// 时间 (JS 字段 `txdate`)
  final String time;

  /// 类型值 (`1消费/2充值/3补助/4转账`)，接口未返回时为空，
  /// UI 按当前筛选或兜底图标展示
  final String tradeType;

  const TransactionRecord({
    required this.merchantName,
    required this.amount,
    required this.time,
    this.tradeType = '',
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      merchantName: (json['mername'] ?? json['mercname'] ?? '').toString(),
      amount: (json['txamt'] ?? '').toString(),
      time: (json['txdate'] ?? json['paytime'] ?? '').toString(),
      tradeType: (json['tradeType'] ??
              json['tradetype'] ??
              json['type'] ??
              json['txtype'] ??
              '')
          .toString(),
    );
  }
}

/// 流水类型，对齐 `openQueryCardSelfTrade` 页面的 `<select id="choose">`
enum TransactionType {
  all('-1', '全部'),
  consume('1', '消费'),
  recharge('2', '充值'),
  subsidy('3', '补助'),
  transfer('4', '转账');

  final String value;
  final String label;
  const TransactionType(this.value, this.label);
}
