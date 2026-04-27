import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/electricity_service.dart';
import '../services/campus_card_service.dart';
import '../models/electricity_model.dart';
import 'payment_result_screen.dart';
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
  bool _isPaying = false;

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
      _areas = await service.getAreas();
      
      if (_areas.isNotEmpty) {
        _selectedArea = _areas.first;
        await _loadBuildings(_selectedArea!.name);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

  Future<void> _handleRecharge() async {
    if (_selectedArea == null || _selectedBuilding == null || _selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择完整的房间信息')),
      );
      return;
    }

    final amountText = _amountController.text;
    final amount = double.tryParse(amountText);
    
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的充值金额')),
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
        mertype: _selectedRoom!.mertype,
        amount: amount,
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('充值失败，请重试')),
          );
        }
      }
    } catch (e) {
      _logger.e('Recharge failed: $e');
      if (mounted) {
        setState(() => _isPaying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('充值失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = const Color(AppConstants.primaryColorValue);
    final amberColor = const Color(0xFFFFC107);
    
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
                      color: isDark ? themeColor.withOpacity(0.1) : amberColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? themeColor.withOpacity(0.2) : amberColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前充值房间', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          _selectedRoom != null 
                            ? '${_selectedArea?.name} - ${_selectedBuilding?.name} - ${_selectedRoom?.name}'
                            : '尚未选择房间',
                          style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
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
                  
                  // Right Aligned Recharge Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 100,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _isPaying ? null : _handleRecharge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero, // Minimal padding to prevent overflow
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _isPaying 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, size: 16), // Smaller icon
                                SizedBox(width: 4), // Less spacing
                                Text('充值', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), // Slightly smaller text
                              ],
                            ),
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
