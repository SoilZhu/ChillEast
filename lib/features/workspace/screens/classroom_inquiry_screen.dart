import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/classroom_model.dart';
import '../services/classroom_service.dart';

final classroomServiceProvider = Provider((ref) => ClassroomService());

class ClassroomInquiryScreen extends ConsumerStatefulWidget {
  const ClassroomInquiryScreen({super.key});

  @override
  ConsumerState<ClassroomInquiryScreen> createState() => _ClassroomInquiryScreenState();
}

class _ClassroomInquiryScreenState extends ConsumerState<ClassroomInquiryScreen> {
  ClassroomInquiryOptions? _options;
  bool _loadingOptions = true;
  bool _searching = false;
  List<ClassroomModel> _classrooms = [];
  
  String? _selectedBuilding;
  String? _selectedWeek;
  String? _selectedSection;
  String? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await ref.read(classroomServiceProvider).fetchOptions();
      if (mounted) {
        setState(() {
          _options = options;
          _loadingOptions = false;
          
          if (options.buildings.isNotEmpty) _selectedBuilding = options.buildings.first;
          if (options.weeks.isNotEmpty) _selectedWeek = options.weeks.first;
          if (options.sections.isNotEmpty) _selectedSection = options.sections.first;
          if (options.days.isNotEmpty) _selectedDay = options.days.first['value'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingOptions = false);
      }
    }
  }

  Future<void> _search() async {
    if (_selectedBuilding == null || _selectedWeek == null || _selectedSection == null || _selectedDay == null) {
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await ref.read(classroomServiceProvider).queryClassrooms(
        building: _selectedBuilding!,
        week: _selectedWeek!,
        jc: _selectedSection!,
        day: _selectedDay!,
      );
      if (mounted) {
        setState(() {
          _classrooms = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('空教室查询'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: _loadingOptions 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchPanel(),
                Expanded(
                  child: _searching 
                      ? const Center(child: CircularProgressIndicator())
                      : _buildResultList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchPanel() {
    if (_options == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildPlainDropdown('教学楼', _options!.buildings, _selectedBuilding, (val) => setState(() => _selectedBuilding = val))),
              const SizedBox(width: 12),
              Expanded(child: _buildPlainDropdown('周次', _options!.weeks, _selectedWeek, (val) => setState(() => _selectedWeek = val))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPlainDropdown('节次', _options!.sections, _selectedSection, (val) => setState(() => _selectedSection = val))),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlainDropdown(
                  '星期', 
                  _options!.days.map((e) => e['label']!).toList(), 
                  _options!.days.firstWhere((e) => e['value'] == _selectedDay, orElse: () => _options!.days.first)['label'],
                  (label) {
                    final val = _options!.days.firstWhere((e) => e['label'] == label)['value'];
                    setState(() => _selectedDay = val);
                  }
                )
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _search,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('查询'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainDropdown(String label, List<String> items, String? current, Function(String?) onChanged) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current,
              isExpanded: true,
              dropdownColor: isDark ? Colors.black : Colors.white,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultList() {
    if (_classrooms.isEmpty) {
      if (!_searching && _options != null) {
        return Center(
          child: Text('没有数据', style: TextStyle(color: Colors.grey[400])),
        );
      }
      return const SizedBox();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _classrooms.length,
      itemBuilder: (context, index) {
        final room = _classrooms[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.jsmc,
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '容纳人数: ${room.zws}',
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.grey[600],
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
