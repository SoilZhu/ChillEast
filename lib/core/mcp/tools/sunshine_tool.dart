import '../../../features/sunshine/models/sunshine_models.dart';
import '../../../features/sunshine/services/sunshine_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 查询阳光服务受理部门 (query_sunshine_departments)
class SunshineDepartmentsQueryTool {
  static const String toolName = 'query_sunshine_departments';

  static McpTool create({SunshineService? service}) {
    final sunshineService = service ?? SunshineService();

    return McpTool(
      name: toolName,
      description: '查询学校“阳光服务”平台当前所有可受理诉求的部门/单位列表（如后勤保卫部、教务处、图书馆、校医院等）。',
      inputSchema: {
        'type': 'object',
        'properties': {},
      },
      handler: (arguments) async {
        try {
          final formData = await sunshineService.fetchForm();
          final depts = formData.departments.map((d) => {
            'code': d.code,
            'name': d.name,
          }).toList();

          return McpToolResult.json({
            'success': true,
            'userName': formData.identity.name,
            'departmentCount': depts.length,
            'departments': depts,
          });
        } catch (e) {
          return McpToolResult.error('获取阳光服务受理部门失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 快速提交阳光服务诉求 (submit_sunshine_letter)
class SunshineSubmitTool {
  static const String toolName = 'submit_sunshine_letter';

  static McpTool create({SunshineService? service}) {
    final sunshineService = service ?? SunshineService();

    return McpTool(
      name: toolName,
      description:
          '向学校“阳光服务”平台快速提交诉求表单（支持咨询、建议、投诉、表扬）。支持自动识别部门并填充个人信息。'
          '【重要】：在正式提交前，必须向用户核对受理单位、类型、标题和诉求正文，征得用户明确同意确认后，传入 confirmed=true 方可真正提交。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'department': {
            'type': 'string',
            'description': '受理部门名称或关键词（如“后勤保卫部”、“教务处”、“图书馆”、“信息与网络中心”等，支持模糊匹配）。',
          },
          'title': {
            'type': 'string',
            'description': '诉求标题（必填，要求简明准确，50字以内）。',
          },
          'content': {
            'type': 'string',
            'description': '诉求详细内容（必填，清晰阐述遇到的问题、具体诉求或建议）。',
          },
          'type': {
            'type': 'string',
            'description': '诉求类别：2-咨询, 3-建议, 1-投诉, 4-表扬。可传数字或汉字（如“咨询”、“建议”），默认为“咨询”。',
            'default': '2',
          },
          'phone': {
            'type': 'string',
            'description': '联系电话（可选，默认使用学号绑定的手机号）。',
          },
          'email': {
            'type': 'string',
            'description': '电子邮箱（可选，默认使用预留邮箱）。',
          },
          'finishTime': {
            'type': 'string',
            'description': '期望解决时间，格式为 YYYY-MM-DD（可选，不填默认7天后）。',
          },
          'confirmed': {
            'type': 'boolean',
            'description':
                '用户是否已明确同意并确认提交表单。默认为 false。'
                '【重要】：首次调用时若用户未对整理好的具体表单内容（部门、标题、正文等）做最终确认，请保持 false。'
                '工具将返回待确认的表单预览；待用户明确确认后，再将 confirmed 设为 true 真正完成投递。',
            'default': false,
          },
        },
        'required': ['department', 'title', 'content'],
      },
      handler: (arguments) async {
        final deptInput = (arguments['department'] as String?)?.trim() ?? '';
        final title = (arguments['title'] as String?)?.trim() ?? '';
        final content = (arguments['content'] as String?)?.trim() ?? '';
        final typeInput = (arguments['type'] as String?)?.trim() ?? '2';
        final confirmed = arguments['confirmed'] as bool? ?? false;

        if (deptInput.isEmpty) {
          return McpToolResult.error('受理部门不能为空，请输入或指定部门');
        }
        if (title.isEmpty) {
          return McpToolResult.error('诉求标题不能为空');
        }
        if (content.isEmpty) {
          return McpToolResult.error('诉求正文内容不能为空');
        }

        // 1. 获取表单环境与部门列表
        SunshineFormData formData;
        try {
          formData = await sunshineService.fetchForm();
        } catch (e) {
          return McpToolResult.error('连接阳光服务失败，请检查登录状态或稍后重试: $e');
        }

        // 2. 匹配受理部门
        SunshineDepartment? matchedDept;
        for (final d in formData.departments) {
          if (d.name == deptInput || d.code == deptInput) {
            matchedDept = d;
            break;
          }
        }
        if (matchedDept == null) {
          for (final d in formData.departments) {
            if (d.name.contains(deptInput) || deptInput.contains(d.name)) {
              matchedDept = d;
              break;
            }
          }
        }

        if (matchedDept == null) {
          final sampleDepts = formData.departments.take(8).map((d) => d.name).join('、');
          return McpToolResult.error(
            '未找到名为“$deptInput”的受理部门。可选部门参考：$sampleDepts 等，可调用 query_sunshine_departments 查看完整列表。',
          );
        }

        // 3. 解析类别
        String typeCode = '2';
        if (typeInput == '1' || typeInput.contains('投诉')) {
          typeCode = '1';
        } else if (typeInput == '3' || typeInput.contains('建议')) {
          typeCode = '3';
        } else if (typeInput == '4' || typeInput.contains('表扬')) {
          typeCode = '4';
        } else {
          typeCode = '2';
        }
        const typeNames = {'1': '投诉', '2': '咨询', '3': '建议', '4': '表扬'};
        final typeName = typeNames[typeCode] ?? '咨询';

        // 4. 补充电话、邮箱与期望时间
        final phone = (arguments['phone'] as String?)?.trim().isNotEmpty == true
            ? (arguments['phone'] as String).trim()
            : formData.identity.phone;
        final email = (arguments['email'] as String?)?.trim().isNotEmpty == true
            ? (arguments['email'] as String).trim()
            : formData.identity.email;

        String finishTime = (arguments['finishTime'] as String?)?.trim() ?? '';
        if (finishTime.isEmpty) {
          final future = DateTime.now().add(const Duration(days: 7));
          finishTime =
              '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';
        }

        // 5. 校验用户确认状态
        if (!confirmed) {
          return McpToolResult.json({
            'status': 'requires_confirmation',
            'needsUserConsent': true,
            'message':
                '阳光服务诉求表单已就绪。【重要】：请向用户呈现以下待提交的诉求核对信息，'
                '并明确征得用户的同意与确认。用户明确同意确认后，传入 confirmed=true 重新调用本工具正式提交。',
            'formPreview': {
              'submitterName': formData.identity.name,
              'departmentName': matchedDept.name,
              'departmentCode': matchedDept.code,
              'typeName': typeName,
              'typeCode': typeCode,
              'title': title,
              'content': content,
              'phone': phone,
              'email': email,
              'finishTime': finishTime,
            },
          });
        }

        // 6. 用户已确认，真正执行投递
        try {
          final result = await sunshineService.submit(
            identity: formData.identity,
            department: matchedDept,
            type: typeCode,
            title: title,
            content: content,
            phone: phone,
            email: email,
            finishTime: finishTime,
          );

          if (result == '1') {
            return McpToolResult.json({
              'status': 'success',
              'message': '诉求提交成功！阳光服务平台已受理并流转至【${matchedDept.name}】。',
              'department': matchedDept.name,
              'type': typeName,
              'title': title,
            });
          } else if (result == '2') {
            return McpToolResult.json({
              'status': 'success',
              'message': '诉求提交成功，等待平台审核后将流转至【${matchedDept.name}】。',
              'department': matchedDept.name,
              'type': typeName,
              'title': title,
            });
          } else {
            return McpToolResult.error('提交未被服务器成功处理，状态码: $result');
          }
        } catch (e) {
          return McpToolResult.error('提交阳光服务诉求失败: $e');
        }
      },
    );
  }
}
