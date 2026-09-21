import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/electricity_service.dart';
import '../services/campus_card_service.dart';
import '../models/electricity_model.dart';
import 'payment_result_screen.dart';
import 'campus_card_payment_sheet.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';

class ElectricityRechargeScreen extends ConsumerStatefulWidget {
  const ElectricityRechargeScreen({super.key});

  @override
  ConsumerState<ElectricityRechargeScreen> createState() => _ElectricityRechargeScreenState();
}

class _ElectricityRechargeScreenState extends ConsumerState<ElectricityRechargeScreen> {
  final _logger = AppLogger.instance;
  final TextEditingController _amountController = TextEditingController();

  bool _isLoading = true;
  String? _error;

  List<ElectricityArea> _areas = [];
  List<ElectricityBuilding> _buildings = [];
  List<ElectricityRoom> _rooms = [];

  ElectricityArea? _selectedArea;
  ElectricityBuilding? _selectedBuilding;
  ElectricityRoom? _selectedRoom;

  double? _selectedAmount;
  final List<double> _presetAmounts = [10, 20, 50, 100];
  CampusCardInfo? _cardInfo;
  bool _isPaying = false;
  bool _isLoadingBalance = false;
  ElectricityBalanceInfo? _balanceInfo;
  String? _balanceError;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(electricityServiceProvider);
      final savedRoom = await service.getSavedRoom();
      _areas = await service.getAreas();
      
      if (_areas.isNotEmpty) {
        ElectricityArea? targetArea;
        if (savedRoom != null && savedRoom.areaName.isNotEmpty) {
          targetArea = _areas.where((e) => e.name == savedRoom.areaName).firstOrNull;
        }
        _selectedArea = targetArea ?? _areas.first;

        final buildings = await service.getBuildings(_selectedArea!.name);
        _buildings = buildings;

        ElectricityBuilding? targetBuilding;
        if (savedRoom != null && targetArea != null && savedRoom.buildingName.isNotEmpty) {
          targetBuilding = _buildings.where((e) => e.name == savedRoom.buildingName).firstOrNull;
        }
        _selectedBuilding = targetBuilding ?? (_buildings.isNotEmpty ? _buildings.first : null);

        if (_selectedBuilding != null) {
          final rooms = await service.getRooms(_selectedArea!.name, _selectedBuilding!.name);
          _rooms = rooms;

          ElectricityRoom? targetRoom;
          if (savedRoom != null && targetBuilding != null && savedRoom.roomId.isNotEmpty) {
            targetRoom = _rooms.where((e) => e.id == savedRoom.roomId || e.name == savedRoom.roomName).firstOrNull;
          }
          _selectedRoom = targetRoom ?? (_rooms.isNotEmpty ? _rooms.first : null);
        }

        _saveCurrentSelection();
      }

      // 静默后台预加载校园卡信息
      ref.read(campusCardServiceProvider).fetchRechargeInfo().then((info) {
        if (mounted) setState(() => _cardInfo = info);
      }).catchError((e) {
        _logger.w('Pre-fetching campus card info error: $e');
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (_selectedRoom != null) {
          _loadBalance();
        }
      }
    } catch (e) {
      _logger.e('Failed to init electricity data: $e');
      if (mounted) {
        setState(() {
          _error = '加载列表失败，请重试';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBalance() async {
    if (_selectedArea == null || _selectedBuilding == null || _selectedRoom == null) {
      if (mounted) {
        setState(() {
          _balanceInfo = null;
          _balanceError = null;
          _isLoadingBalance = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingBalance = true;
        _balanceError = null;
      });
    }

    try {
      final service = ref.read(electricityServiceProvider);
      final info = await service.getBalance(
        areaName: _selectedArea!.name,
        buildingName: _selectedBuilding!.name,
        roomId: _selectedRoom!.id,
        mertype: _selectedRoom!.mertype,
      );
      if (mounted) {
        setState(() {
          _balanceInfo = info;
          _isLoadingBalance = false;
        });
      }
    } catch (e) {
      _logger.w('Failed to load electricity balance: $e');
      if (mounted) {
        setState(() {
          _balanceError = e.toString();
          _isLoadingBalance = false;
        });
      }
    }
  }

  void _saveCurrentSelection() {
    if (_selectedArea != null && _selectedBuilding != null && _selectedRoom != null) {
      ref.read(electricityServiceProvider).saveSavedRoom(
        SavedElectricityRoom(
          areaName: _selectedArea!.name,
          buildingName: _selectedBuilding!.name,
          roomId: _selectedRoom!.id,
          roomName: _selectedRoom!.name,
          mertype: _selectedRoom!.mertype,
        ),
      );
    }
  }

  Future<void> _loadBuildings(String areaName) async {
    try {
      final service = ref.read(electricityServiceProvider);
      final buildings = await service.getBuildings(areaName);
      if (mounted) {
        setState(() {
          _buildings = buildings;
          _selectedBuilding = buildings.isNotEmpty ? buildings.first : null;
          _rooms = [];
          _selectedRoom = null;
          _balanceInfo = null;
          _balanceError = null;
        });
        if (_selectedBuilding != null) {
          await _loadRooms(areaName, _selectedBuilding!.name);
        }
      }
    } catch (e) {
      _logger.w('Failed to load buildings: $e');
    }
  }

  Future<void> _loadRooms(String areaName, String buildingName) async {
    try {
      final service = ref.read(electricityServiceProvider);
      final rooms = await service.getRooms(areaName, buildingName);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _selectedRoom = rooms.isNotEmpty ? rooms.first : null;
        });
        _saveCurrentSelection();
        if (_selectedRoom != null) {
          _loadBalance();
        }
      }
    } catch (e) {
      _logger.w('Failed to load rooms: $e');
    }
  }

  void _handlePresetAmountSelect(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _handleCampusCardRecharge() async {
    if (_selectedArea == null || _selectedBuilding == null || _selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择完整的房间信息')),
      );
      return;
    }

    final amountText = _amountController.text;
    final amount = int.tryParse(amountText);
    
    if (amount == null || amount < 1 || amount > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入1-1000之间的整数金额')),
      );
      return;
    }

    // 弹出确认卡片
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PaymentResultSheet(
        type: PaymentResultType.confirm,
        merchantName: '缴电费 (校园卡支付)',
        amount: amountText,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPaying = true);

    try {
      final service = ref.read(electricityServiceProvider);
      final success = await service.recharge(
        areaName: _selectedArea!.name,
        buildingName: _selectedBuilding!.name,
        roomId: _selectedRoom!.id,
        roomName: _selectedRoom!.name,
        mertype: _selectedRoom!.mertype,
        amount: amount.toDouble(),
      );

      if (mounted) {
        setState(() => _isPaying = false);
        if (success) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => PaymentResultSheet(
              type: PaymentResultType.success,
              merchantName: '缴电费',
              amount: amountText,
            ),
          );
          ref.read(campusCardServiceProvider).fetchRechargeInfo();
          _loadBalance();
        } else {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => const PaymentResultSheet(
              type: PaymentResultType.failure,
              merchantName: '缴电费 (校园卡支付)',
              message: '充值失败，请重试',
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Recharge failed: $e');
      if (mounted) {
        setState(() => _isPaying = false);
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => PaymentResultSheet(
            type: PaymentResultType.failure,
            merchantName: '缴电费 (校园卡支付)',
            message: '充值失败: $e',
          ),
        );
      }
    }
  }

  Future<void> _handleThirdPartyRecharge(PaymentMethod method) async {
    if (_selectedArea == null || _selectedBuilding == null || _selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择完整的房间信息')),
      );
      return;
    }

    final amountText = _amountController.text;
    final amount = int.tryParse(amountText);

    if (amount == null || amount < 1 || amount > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入1-1000之间的整数金额')),
      );
      return;
    }

    final CampusCardInfo cardInfo;
    final cached = _cardInfo ?? ref.read(campusCardServiceProvider).cachedInfo;
    if (cached != null) {
      cardInfo = cached;
    } else {
      setState(() => _isPaying = true);
      try {
        cardInfo = await ref.read(campusCardServiceProvider).fetchRechargeInfo();
        _cardInfo = cardInfo;
      } catch (e) {
        _logger.e('Failed to fetch card info: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('获取校园卡信息失败: $e')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _isPaying = false);
      }
    }

    if (!mounted) return;

    final roomDesc = '${_selectedArea!.name} ${_selectedBuilding!.name} ${_selectedRoom!.name}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CampusCardPaymentSheet(
        amount: amountText,
        merchantName: '缴电费 ($roomDesc)',
        info: cardInfo,
        paymentMethod: method,
        successTitle: '电费充值成功',
        onCardRechargeSuccess: () async {
          final service = ref.read(electricityServiceProvider);
          final success = await service.recharge(
            areaName: _selectedArea!.name,
            buildingName: _selectedBuilding!.name,
            roomId: _selectedRoom!.id,
            roomName: _selectedRoom!.name,
            mertype: _selectedRoom!.mertype,
            amount: amount.toDouble(),
          );
          if (!success) {
            throw Exception('电费充值接口未返回成功');
          }
        },
      ),
    ).then((_) {
      if (mounted) {
        ref.read(campusCardServiceProvider).fetchRechargeInfo();
        _loadBalance();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(AppConstants.primaryColorValue);
    const amberColor = Color(0xFFFFC107);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('电费充值', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: themeColor))
        : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initData, 
                    style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                    child: const Text('重试', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flat Header (Amber)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? themeColor.withValues(alpha: 0.1) : amberColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? themeColor.withValues(alpha: 0.2) : amberColor.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '当前充值房间',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold),
                            ),
                            if (_selectedRoom != null)
                              InkWell(
                                onTap: _isLoadingBalance ? null : _loadBalance,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isLoadingBalance)
                                        SizedBox(
                                          width: 11,
                                          height: 11,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.refresh,
                                          size: 13,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      const SizedBox(width: 3),
                                      Text(
                                        _isLoadingBalance ? '刷新中' : '刷新余额',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedRoom != null 
                            ? '${_selectedArea?.name} - ${_selectedBuilding?.name} - ${_selectedRoom?.name}'
                            : '尚未选择房间',
                          style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '电费余额',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_balanceError != null && _balanceInfo == null)
                          InkWell(
                            onTap: _loadBalance,
                            child: Row(
                              children: [
                                Text(
                                  '获取失败，点击重试',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.refresh, size: 13, color: Colors.red.shade400),
                              ],
                            ),
                          )
                        else
                          Text(
                            _balanceInfo != null
                                ? '${_balanceInfo!.balance} 元'
                                : (_isLoadingBalance ? '查询中...' : '0.00 元'),
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Independent Room Selection Boxes (No Fill Color)
                  _buildRoomSelectionBox('校区', _areas.map((e) => e.name).toList(), _selectedArea?.name, (val) {
                    final area = _areas.firstWhere((e) => e.name == val);
                    setState(() => _selectedArea = area);
                    _loadBuildings(area.name);
                  }),
                  const SizedBox(height: 12),
                  _buildRoomSelectionBox('楼栋', _buildings.map((e) => e.name).toList(), _selectedBuilding?.name, (val) {
                    final building = _buildings.firstWhere((e) => e.name == val);
                    setState(() => _selectedBuilding = building);
                    _loadRooms(_selectedArea!.name, building.name);
                  }),
                  const SizedBox(height: 12),
                  _buildRoomSelectionBox('房间', _rooms.map((e) => e.name).toList(), _selectedRoom?.name, (val) {
                    final room = _rooms.firstWhere((e) => e.name == val);
                    setState(() => _selectedRoom = room);
                    _saveCurrentSelection();
                    _loadBalance();
                  }),
                  
                  const SizedBox(height: 32),
                  
                  Text('选择充值金额', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54)),
                  const SizedBox(height: 12),
                  
                  // Grid (No Shadow)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: _presetAmounts.length,
                    itemBuilder: (context, index) {
                      final amount = _presetAmounts[index];
                      final isSelected = _selectedAmount == amount;
                      return InkWell(
                        onTap: () => _handlePresetAmountSelect(amount),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? themeColor : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? themeColor : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3))),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${amount.toStringAsFixed(0)}元',
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Custom Input (No Fill Color)
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: '其他金额',
                      labelStyle: TextStyle(color: isDark ? themeColor.withOpacity(0.8) : themeColor),
                      prefixText: '¥ ',
                      filled: isDark,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: themeColor.withOpacity(0.3))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: themeColor.withOpacity(0.4))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: themeColor, width: 1.5)),
                    ),
                    onChanged: (value) => setState(() => _selectedAmount = double.tryParse(value)),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 底部支付操作按钮 (校园卡支付、微信支付、支付宝支付)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 校园卡支付
                          SizedBox(
                            width: 125,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isPaying ? null : _handleCampusCardRecharge,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: _isPaying 
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.credit_card, size: 18),
                                      SizedBox(width: 6),
                                      Text('校园卡支付', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 微信支付
                          SizedBox(
                            width: 125,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isPaying ? null : () => _handleThirdPartyRecharge(PaymentMethod.wechat),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF07C160),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.string(
                                    kWechatSvg,
                                    width: 18,
                                    height: 18,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('微信支付', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 支付宝支付
                          SizedBox(
                            width: 125,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isPaying ? null : () => _handleThirdPartyRecharge(PaymentMethod.alipay),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1677FF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.string(
                                    kAlipaySvg,
                                    width: 18,
                                    height: 18,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('支付宝支付', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildRoomSelectionBox(String label, List<String> items, String? current, Function(String?) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: items.contains(current) ? current : null,
      decoration: InputDecoration(
        labelText: label,
        filled: isDark,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3)),
        ),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
    );
  }
}
