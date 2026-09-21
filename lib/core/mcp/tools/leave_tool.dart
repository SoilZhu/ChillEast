import '../../../features/leave/models/leave_models.dart';
import '../../../features/leave/services/leave_service.dart';
import '../models/mcp_tool.dart';

LeaveService _resolveService(LeaveService? service) =>
    service ?? LeaveService();

Map<String, dynamic> _formatRecord(LeaveRecord record) => {
      'id': record.id,
      'type': record.typeName,
      'timeRange': record.timeRange,
      'startTime': record.startTime,
      'endTime': record.endTime,
      'duration': record.durationLabel,
      'reason': record.reason,
      'status': record.statusLabel,
      'canDelete': record.canDelete,
    };

/// MCP Tool: 查询请假记录 (query_leaves)
class LeaveListTool {
  static const String toolName = 'query_leaves';

  static McpTool create({LeaveService? service}) {
    final leaveService = _resolveService(service);

    return McpTool(
      name: toolName,
      description:
          '查询学校学工系统“请假申请”的请假记录。返回每条记录的类别（事假/病假）、起止时间、时长、事由与审核状态（待审核/审核中/已审核）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'description': '按状态过滤：待审核、审核中、已审核、全部。默认为全部。',
          },
        },
      },
      handler: (arguments) async {
        final status = (arguments['status'] as String?)?.trim() ?? '全部';
        try {
          final items = await leaveService.fetchList();
          final filtered = items.where((item) {
            if (status.contains('待审核')) return item.auditStatus == '0';
            if (status.contains('审核中')) return item.auditStatus == '8';
            if (status.contains('已审')) return item.auditStatus == '9';
            return true;
          }).toList();
          return McpToolResult.json({
            'success': true,
            'count': filtered.length,
            'leaves': filtered.map(_formatRecord).toList(),
          });
        } catch (e) {
          return McpToolResult.error('查询请假记录失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 查询请假单详情 (query_leave_detail)
class LeaveDetailTool {
  static const String toolName = 'query_leave_detail';

  static McpTool create({LeaveService? service}) {
    final leaveService = _resolveService(service);

    return McpTool(
      name: toolName,
      description:
          '查询某条请假记录的完整详情（事由、紧急联系人、离校去向、备注、出市/出省、附件等）。id 取自 query_leaves 返回的 id 字段。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': '请假记录 id（query_leaves 返回的 id 字段）。',
          },
        },
        'required': ['id'],
      },
      handler: (arguments) async {
        final id = (arguments['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) {
          return McpToolResult.error('请提供请假记录 id');
        }
        try {
          final detail = await leaveService.fetchRecord(id);
          return McpToolResult.json({
            'success': true,
            'detail': detail.raw,
          });
        } catch (e) {
          return McpToolResult.error('查询请假详情失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 代提交请假申请 (submit_leave)
class LeaveSubmitTool {
  static const String toolName = 'submit_leave';

  static McpTool create({LeaveService? service}) {
    final leaveService = _resolveService(service);

    return McpTool(
      name: toolName,
      description: '代用户提交请假申请。请假时长由起止时间自动计算，无需传入。'
          '时间格式均为 YYYY-MM-DD HH:mm（24小时制）。暂不支持代传附件（请假材料需用户在 App 内手工提交）。'
          '【重要】：首次调用保持 confirmed=false，工具返回待确认的申请预览；'
          '向用户逐项核对后，征得明确同意再传 confirmed=true 真正提交。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'description': '请假类别：事假或病假（支持关键词）。',
          },
          'startTime': {
            'type': 'string',
            'description': '开始时间，格式 YYYY-MM-DD HH:mm，如“2026-09-22 10:00”。',
          },
          'endTime': {
            'type': 'string',
            'description': '结束时间，格式 YYYY-MM-DD HH:mm，必须晚于开始时间。',
          },
          'reason': {
            'type': 'string',
            'description': '请假事由（必填）。',
          },
          'contact': {
            'type': 'string',
            'description': '紧急联系人（必填）。',
          },
          'phone': {
            'type': 'string',
            'description': '紧急联系人电话（必填，11位手机号）。',
          },
          'companions': {
            'type': 'string',
            'description': '同行人员（选填）。',
          },
          'leaveSchool': {
            'type': 'boolean',
            'description': '是否离校。默认为 false；为 true 时去向、详细地址、备注必填。',
            'default': false,
          },
          'province': {
            'type': 'string',
            'description': '离校去向省份关键词（如“湖南”，离校时必填）。',
          },
          'city': {
            'type': 'string',
            'description': '离校去向城市关键词（如“长沙”，选填，越细越好）。',
          },
          'county': {
            'type': 'string',
            'description': '离校区县关键词（如“岳麓”，选填）。',
          },
          'address': {
            'type': 'string',
            'description': '离校详细地址（离校时必填）。',
          },
          'backDorm': {
            'type': 'boolean',
            'description': '是否回宿舍。默认为 false。',
            'default': false,
          },
          'remark': {
            'type': 'string',
            'description': '备注（离校时必填）。',
          },
          'outCity': {
            'type': 'boolean',
            'description': '是否出市。默认为 false。',
            'default': false,
          },
          'outProvince': {
            'type': 'boolean',
            'description': '是否出省。默认为 false。',
            'default': false,
          },
          'confirmed': {
            'type': 'boolean',
            'description':
                '用户是否已对下方预览中的申请内容做最终确认。默认为 false；仅当用户明确同意提交后才传 true。',
            'default': false,
          },
        },
        'required': [
          'type',
          'startTime',
          'endTime',
          'reason',
          'contact',
          'phone'
        ],
      },
      handler: (arguments) async {
        String str(String key) =>
            (arguments[key] as String?)?.trim() ?? '';
        bool flag(String key) => arguments[key] as bool? ?? false;

        final typeInput = str('type');
        final start = str('startTime');
        final end = str('endTime');
        final reason = str('reason');
        final contact = str('contact');
        final phone = str('phone');
        final leaveSchool = flag('leaveSchool');
        final confirmed = flag('confirmed');

        if (typeInput.isEmpty) return McpToolResult.error('请假类别不能为空');
        if (reason.isEmpty) return McpToolResult.error('请假事由不能为空');
        if (contact.isEmpty) return McpToolResult.error('紧急联系人不能为空');
        if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
          return McpToolResult.error('紧急联系人电话须为11位手机号');
        }
        DateTime? startDt;
        DateTime? endDt;
        try {
          startDt = DateTime.parse(start.replaceFirst(' ', 'T'));
          endDt = DateTime.parse(end.replaceFirst(' ', 'T'));
        } catch (_) {
          return McpToolResult.error('时间格式须为 YYYY-MM-DD HH:mm（24小时制）');
        }
        if (!endDt.isAfter(startDt)) {
          return McpToolResult.error('结束时间必须晚于开始时间');
        }

        // 1. 类别匹配
        List<LeaveDictItem> types;
        try {
          types = await leaveService.fetchTypes();
        } catch (e) {
          return McpToolResult.error('连接学工系统失败，请检查登录状态或稍后重试: $e');
        }
        LeaveDictItem? matchedType;
        for (final t in types) {
          if (t.id == typeInput || t.name == typeInput) {
            matchedType = t;
            break;
          }
        }
        if (matchedType == null) {
          for (final t in types) {
            if (t.name.contains(typeInput) || typeInput.contains(t.name)) {
              matchedType = t;
              break;
            }
          }
        }
        if (matchedType == null) {
          return McpToolResult.error(
              '未知的请假类别“$typeInput”，可选：${types.map((t) => t.name).join('、')}。');
        }

        // 2. 离校去向匹配（省/市/县逐级）
        String regionId = '';
        String regionName = '';
        final address = str('address');
        final remark = str('remark');
        if (leaveSchool) {
          final provinceInput = str('province');
          if (provinceInput.isEmpty) {
            return McpToolResult.error('离校需提供去向省份（province）');
          }
          if (address.isEmpty) return McpToolResult.error('离校需提供详细地址');
          if (remark.isEmpty) return McpToolResult.error('离校需提供备注');
          List<RegionNode> regions;
          try {
            regions = await leaveService.fetchRegions();
          } catch (e) {
            return McpToolResult.error('获取地区数据失败: $e');
          }
          final province = _matchRegion(regions, provinceInput);
          if (province == null) {
            return McpToolResult.error('未找到省份“$provinceInput”');
          }
          RegionNode deepest = province;
          final cityInput = str('city');
          if (cityInput.isNotEmpty) {
            final city = _matchRegion(province.children, cityInput);
            if (city == null) {
              return McpToolResult.error(
                  '“${province.name}”下未找到城市“$cityInput”');
            }
            deepest = city;
            final countyInput = str('county');
            if (countyInput.isNotEmpty) {
              final county = _matchRegion(city.children, countyInput);
              if (county == null) {
                return McpToolResult.error(
                    '“${city.name}”下未找到区县“$countyInput”');
              }
              deepest = county;
            }
          }
          regionId = deepest.id;
          regionName = deepest.name;
        }

        // 3. 时长自动计算
        LeaveDuration duration;
        try {
          duration = await leaveService.calculate(start, end);
        } catch (e) {
          return McpToolResult.error('计算请假时长失败: $e');
        }

        final preview = {
          'type': matchedType.name,
          'startTime': start,
          'endTime': end,
          'duration': '${duration.days}天${duration.hours}小时',
          'reason': reason,
          'contact': contact,
          'phone': phone,
          'companions': str('companions'),
          'leaveSchool': leaveSchool ? '是' : '否',
          'destination': regionName,
          'address': address,
          'backDorm': flag('backDorm') ? '是' : '否',
          'remark': remark,
          'outCity': flag('outCity') ? '是' : '否',
          'outProvince': flag('outProvince') ? '是' : '否',
        };

        // 4. 未确认：只返回预览
        if (!confirmed) {
          return McpToolResult.json({
            'status': 'requires_confirmation',
            'needsUserConsent': true,
            'message': '请假申请已就绪。【重要】：请向用户逐项呈现以下待提交内容并征得明确同意，'
                '用户确认后传入 confirmed=true 重新调用本工具正式提交。附件需用户在 App 内手工补充。',
            'applicationPreview': preview,
          });
        }

        // 5. 已确认：真正提交（不重试写入，避免重复投递）
        final fields = <String, String>{
          'qjlxM.dm': matchedType.id,
          'qjlx': matchedType.name,
          'kssj': start,
          'jssj': end,
          'ts': duration.days.toString(),
          'jsTs': duration.days.toString(),
          'hour': duration.hours.toString(),
          'jsHour': duration.hours.toString(),
          'qjsy': reason,
          'lxr': contact,
          'lxrdh': phone,
          'txry': str('companions'),
          'lxInd': leaveSchool ? '1' : '0',
          'lxqx.dm': regionId,
          'lxqx1': regionName,
          'lxMdd': address,
          'huisusheInd': flag('backDorm') ? '1' : '0',
          'lxBz': remark,
          'chushiInd': flag('outCity') ? '1' : '0',
          'chushengInd': flag('outProvince') ? '1' : '0',
          'pathFile': '',
          'qjLocation': '',
          'qjLocationZb': '',
          'operationType': 'Create',
          'id': '',
        };
        try {
          await leaveService.submit(fields: fields);
          return McpToolResult.json({
            'status': 'success',
            'message':
                '请假申请提交成功！${matchedType.name}（$start ~ $end，共${duration.days}天${duration.hours}小时），请提醒用户在 App 内按需补充请假材料。',
          });
        } catch (e) {
          return McpToolResult.error('提交请假申请失败: $e');
        }
      },
    );
  }
}

RegionNode? _matchRegion(List<RegionNode> nodes, String keyword) {
  for (final node in nodes) {
    if (node.id == keyword || node.name == keyword) return node;
  }
  for (final node in nodes) {
    if (node.name.contains(keyword) || keyword.contains(node.name)) {
      return node;
    }
  }
  return null;
}
