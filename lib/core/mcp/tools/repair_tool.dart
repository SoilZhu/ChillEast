import 'dart:io';
import '../../../core/state/auth_state.dart';
import '../../../features/repairs/models/repair_models.dart';
import '../../../features/repairs/services/repair_service.dart';
import '../models/mcp_tool.dart';

RepairService _resolveService(RepairService? service) =>
    service ?? RepairService(const AuthState.initial());

Map<String, dynamic> _formatOrder(RepairOrder order) => {
      'id': order.id,
      'code': order.code,
      'title': order.title,
      'catalog': order.catalog,
      'department': order.department,
      'status': order.status,
      'createdAt': order.createdAt != null
          ? '${order.createdAt!.year}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.day.toString().padLeft(2, '0')}'
          : null,
      'description': order.description,
    };

/// MCP Tool: 查询报修工单列表 (query_repairs)
class RepairOrdersQueryTool {
  static const String toolName = 'query_repairs';

  static McpTool create({RepairService? service, String toolName = toolName}) {
    final repairService = _resolveService(service);

    return McpTool(
      name: toolName,
      description:
          '查询学校报修平台当前用户的报修工单列表（支持查询“处理中”、“已完成”、“草稿箱”或“全部”）。返回工单编号、标题、分类、创建日期及处理状态。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'description': '按状态过滤：处理中、已完成、草稿箱、全部。默认为“处理中”。',
            'default': '处理中',
          },
        },
      },
      handler: (arguments) async {
        final status = (arguments['status'] as String?)?.trim() ?? '处理中';
        try {
          List<RepairOrder> orders = [];
          if (status.contains('草稿')) {
            orders = await repairService.fetchOrders(
                ongoing: false, isDraft: true);
          } else if (status.contains('已完成') || status.contains('完成')) {
            orders = await repairService.fetchOrders(ongoing: false);
          } else if (status.contains('全')) {
            final results = await Future.wait([
              repairService.fetchOrders(ongoing: true),
              repairService.fetchOrders(ongoing: false),
              repairService.fetchOrders(ongoing: false, isDraft: true),
            ]);
            orders = [...results[0], ...results[1], ...results[2]];
          } else {
            // 默认处理中
            orders = await repairService.fetchOrders(ongoing: true);
          }

          return McpToolResult.json({
            'success': true,
            'count': orders.length,
            'status': status,
            'orders': orders.map(_formatOrder).toList(),
          });
        } catch (e) {
          return McpToolResult.error('查询报修工单列表失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 查询报修工单详情 (query_repair_detail)
class RepairDetailTool {
  static const String toolName = 'query_repair_detail';

  static McpTool create({RepairService? service}) {
    final repairService = _resolveService(service);

    return McpTool(
      name: toolName,
      description:
          '查询某条报修工单的详细信息、流转活动日志及处理进度。id 取自 query_repairs 返回的 id 字段。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': '报修工单 id（query_repairs 返回的 id 字段）。',
          },
        },
        'required': ['id'],
      },
      handler: (arguments) async {
        final id = (arguments['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) {
          return McpToolResult.error('请提供报修工单 id');
        }
        try {
          final detail = await repairService.fetchOrderDetailById(id);
          return McpToolResult.json({
            'success': true,
            'order': _formatOrder(detail),
            'applicant': detail.applicant,
            'phone': detail.phone,
            'handler': detail.handler,
            'handlerDepartment': detail.handlerDepartment,
            'handleResult': detail.handleResult,
            'currentNode': detail.currentNode,
            'activityLogs': detail.logs
                .map((l) => {
                      'time': l.time?.toIso8601String(),
                      'userName': l.userName,
                      'description': l.description,
                    })
                .toList(),
            'attachments': detail.attachments
                .map((a) => {
                      'id': a.id,
                      'fileName': a.fileName,
                      'downloadUrl': a.downloadUrl,
                      'createTime': a.createTime?.toIso8601String(),
                    })
                .toList(),
          });
        } catch (e) {
          return McpToolResult.error('查询报修详情失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 提交报修工单 (submit_repair_order)
class RepairSubmitTool {
  static const String toolName = 'submit_repair_order';

  /// 记录当前会话最新上传的图片本地路径，供报修工具自动识别
  static String? lastChatImagePath;

  static McpTool create({RepairService? service}) {
    final repairService = _resolveService(service);

    return McpTool(
      name: toolName,
      description:
          '向学校报修平台提交报修工单（支持后勤报修、校园网络报修、一校通报修、业务系统报修四大类）。'
          '【重要·后勤必有图】：后勤报修（宿舍水电、门窗家具、生活公共设施等）必须附带现场故障照片！若用户在聊天中上传了图片，请直接传入该路径；若无图片，严禁提交，必须向用户索取照片。'
          '【重要·确认原则】：在正式提交前，必须向用户清晰呈现报修分类、故障地点、故障描述、预约时间等预览信息并征求用户明确同意确认。首次调用时 confirmed 保持 false，用户确认后再传 confirmed=true 正式提交。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'catalog': {
            'type': 'string',
            'description':
                '报修分类名称，可选：“后勤报修”（宿舍生活公用设施）、“校园网络报修”（校园网/WiFi/网线）、“一校通报修”（校园卡/数字设备）、“业务系统报修”（教务/研究生等软件业务系统）。',
          },
          'description': {
            'type': 'string',
            'description': '故障详细描述（必填，清晰阐明遇到的问题）。',
          },
          'location': {
            'type': 'string',
            'description': '报修具体位置（如“东湖校区12栋502”、“第九教学楼201教室”等）。',
          },
          'title': {
            'type': 'string',
            'description': '工单简要标题（可选，不填将自动生成，如“某某的后勤维修服务”）。',
          },
          'image_path': {
            'type': 'string',
            'description':
                '现场故障图片的本地文件绝对路径（后勤报修严格必填！若用户在当前聊天中发送了图片，请传入该图片的本地路径）。',
          },
          'image_paths': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': '多张现场故障图片的本地文件路径列表（可选）。',
          },
          'appointment_date': {
            'type': 'string',
            'description': '期望预约维修日期，格式为 YYYY/MM/DD 或 YYYY-MM-DD（可选，默认为当天）。',
          },
          'appointment_time': {
            'type': 'string',
            'description': '期望预约维修时间段（如“8_9”、“9_10”、“14_15”等，或“上午”、“下午”，可选）。',
          },
          'phone': {
            'type': 'string',
            'description': '联系电话（可选，默认使用学号绑定的手机号）。',
          },
          'confirmed': {
            'type': 'boolean',
            'description':
                '用户是否已明确同意并确认提交表单。默认为 false。'
                '首次整理调用请保持 false，工具将返回待确认的表单预览；待用户明确确认后，再将 confirmed 设为 true 真正完成投递。',
            'default': false,
          },
        },
        'required': ['catalog', 'description'],
      },
      handler: (arguments) async {
        final catalogInput =
            (arguments['catalog'] as String?)?.trim() ?? '后勤报修';
        final description =
            (arguments['description'] as String?)?.trim() ?? '';
        final location = (arguments['location'] as String?)?.trim() ?? '';
        final userTitle = (arguments['title'] as String?)?.trim() ?? '';
        final phone = (arguments['phone'] as String?)?.trim();
        final appointmentDate =
            (arguments['appointment_date'] as String?)?.trim();
        final appointmentTime =
            (arguments['appointment_time'] as String?)?.trim();
        final confirmed = arguments['confirmed'] == true;

        if (description.isEmpty) {
          return McpToolResult.error('请提供故障详细描述');
        }

        // 1. 匹配报修大类
        final matchedCatalog = RepairService.catalogs.firstWhere(
          (c) =>
              c.title == catalogInput ||
              catalogInput.contains(c.title) ||
              c.title.contains(catalogInput),
          orElse: () {
            if (catalogInput.contains('网') || catalogInput.contains('wifi')) {
              return RepairService.catalogs.firstWhere(
                  (c) => c.title.contains('网络'));
            }
            if (catalogInput.contains('卡') || catalogInput.contains('一校通')) {
              return RepairService.catalogs.firstWhere(
                  (c) => c.title.contains('一校通'));
            }
            if (catalogInput.contains('系统') || catalogInput.contains('软件')) {
              return RepairService.catalogs.firstWhere(
                  (c) => c.title.contains('业务系统'));
            }
            return RepairService.catalogs.first; // 默认后勤报修
          },
        );

        final isLogistics = matchedCatalog.title.contains('后勤');

        // 2. 收集图片路径
        final candidatePaths = <String>[];
        final singlePath = (arguments['image_path'] as String?)?.trim();
        if (singlePath != null && singlePath.isNotEmpty) {
          candidatePaths.add(singlePath);
        }
        final listPaths = arguments['image_paths'];
        if (listPaths is List) {
          for (final p in listPaths) {
            if (p is String && p.trim().isNotEmpty) {
              candidatePaths.add(p.trim());
            }
          }
        }
        // 如果未显式提供图片且是后勤报修，尝试读取当前对话上传的图片
        if (candidatePaths.isEmpty && lastChatImagePath != null) {
          candidatePaths.add(lastChatImagePath!);
        }

        // 验证文件有效性
        final validImageFiles = <File>[];
        for (final p in candidatePaths) {
          final f = File(p);
          if (f.existsSync()) {
            validImageFiles.add(f);
          }
        }

        // 【后勤报修强制必须有图校验】
        if (isLogistics && validImageFiles.isEmpty) {
          return McpToolResult.error(
            '【后勤报修严格要求提供现场图片】：'
            '后勤报修系统要求必须上传现场故障照片！'
            '请引导用户在当前对话中发送/上传故障照片，然后再进行报修提交。',
          );
        }

        // 解析工单标题
        final realName = repairService.auth.realName ?? '用户';
        final resolvedTitle = userTitle.isNotEmpty
            ? userTitle
            : '$realName的${matchedCatalog.title}';

        // 格式化预约日期
        final now = DateTime.now();
        final defaultDateStr =
            '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
        final resolvedDateStr = appointmentDate != null && appointmentDate.isNotEmpty
            ? appointmentDate.replaceAll('-', '/')
            : defaultDateStr;

        // 3. 用户未确认时，返回预览数据供核对
        if (!confirmed) {
          return McpToolResult.json({
            'success': true,
            'needConfirmation': true,
            'preview': {
              'catalog': matchedCatalog.title,
              'department': matchedCatalog.department,
              'title': resolvedTitle,
              'location': location.isNotEmpty ? location : '(未特别指定)',
              'description': description,
              'appointmentDate': resolvedDateStr,
              'appointmentTime': appointmentTime ?? '默认维修时段',
              'phone': phone ?? '(使用学号绑定手机号)',
              'hasImage': validImageFiles.isNotEmpty,
              'imageCount': validImageFiles.length,
              'imageFiles': validImageFiles.map((f) => f.path).toList(),
            },
            'message':
                '报修工单已整理就绪。请向用户展示上述预览信息（包括报修分类、故障地点、问题描述、预约时间及图片）。'
                '经用户明确确认同意后，将 confirmed 设为 true 再次调用以正式提交。',
          });
        }

        // 4. 正式提交
        try {
          final session = await repairService.loadForm(matchedCatalog);

          // 4.1 上传图片并记录
          RepairField? uploadField;
          for (final f in session.fields) {
            if (f.isUpload || f.name == 'scwttp') {
              uploadField = f;
              break;
            }
          }

          int uploadedCount = 0;
          if (uploadField != null && validImageFiles.isNotEmpty) {
            for (final imgFile in validImageFiles) {
              await repairService.uploadAttachment(
                session,
                uploadField,
                imgFile,
              );
              uploadedCount++;
            }
          }

          // 4.2 构造提交字段
          final values = <String, dynamic>{};

          for (final field in session.fields) {
            if (field.hidden || field.readonly) continue;

            if (field.isUpload || field.name == 'scwttp') {
              values[field.name] = uploadedCount;
              continue;
            }

            if (field.isDate || field.name == 'yyrq') {
              values[field.name] =
                  RepairService.parseDateToTimestamp(resolvedDateStr) ??
                      resolvedDateStr;
              continue;
            }

            // 预约时间段匹配
            if (field.name == 'yywxsj') {
              if (appointmentTime != null && appointmentTime.isNotEmpty) {
                values[field.name] = appointmentTime;
              } else {
                // 默认选择上午时段或第一个可用时段
                final choices = await repairService.lookup(
                  field.referenceType ??
                      '3965f192-b6ed-11eb-8b80-af0eafc5dd38',
                );
                if (choices.isNotEmpty) {
                  values[field.name] = choices.first.id;
                } else {
                  values[field.name] = '14_15';
                }
              }
              continue;
            }

            // 手机号
            if (field.name == 'sjhm' ||
                field.label.contains('手机') ||
                field.label.contains('电话')) {
              values[field.name] = phone?.isNotEmpty == true
                  ? phone!
                  : (session.initialValues[field.name] ??
                      repairService.auth.username ??
                      '');
              continue;
            }

            // 姓名
            if (field.name == 'xm' || field.label.contains('姓名')) {
              values[field.name] = session.initialValues[field.name] ??
                  repairService.auth.realName ??
                  '';
              continue;
            }

            // 详细位置 / 房间号
            if (field.name == 'xxwzhfjy' ||
                field.label.contains('详细位置') ||
                field.label.contains('房间号')) {
              values[field.name] = location.isNotEmpty ? location : description;
              continue;
            }

            // 问题描述
            if (field.name == 'wtmsh' ||
                field.name == 'bchshm' ||
                field.label.contains('问题描述') ||
                field.label.contains('补充说明')) {
              values[field.name] = description;
              continue;
            }

            // 工单标题
            if (field.name == 'title' || field.label.contains('标题')) {
              values[field.name] = resolvedTitle;
              continue;
            }

            // 常见选择器（区域、楼栋、项目、设施等）
            if (field.isChoice) {
              try {
                List<RepairChoice> choices = [];
                if (field.reference != null) {
                  choices =
                      await repairService.references(field.reference!);
                } else if (field.referenceType != null) {
                  choices = await repairService.lookup(field.referenceType!);
                }

                if (choices.isNotEmpty) {
                  // 尝试根据地点或描述关键词模糊匹配
                  RepairChoice? matchedChoice;
                  final searchContext = '$location $description';
                  for (final c in choices) {
                    if (searchContext.contains(c.label) ||
                        c.label.contains(location)) {
                      matchedChoice = c;
                      break;
                    }
                  }
                  values[field.name] = (matchedChoice ?? choices.first).id;
                }
              } catch (_) {}
            }
          }

          // 4.3 提交工单
          await repairService.submit(session, values, isDraft: false);

          // 清理当前会话图片缓存
          lastChatImagePath = null;

          return McpToolResult.json({
            'success': true,
            'message': '报修工单已成功提交！',
            'catalog': matchedCatalog.title,
            'title': resolvedTitle,
            'instanceId': session.instanceId,
            'uploadedImages': uploadedCount,
          });
        } catch (e) {
          return McpToolResult.error('提交报修工单失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 取消报修工单 (cancel_repair_order)
class RepairCancelTool {
  static const String toolName = 'cancel_repair_order';

  static McpTool create({RepairService? service, String toolName = toolName}) {
    final repairService = _resolveService(service);

    return McpTool(
      name: toolName,
      description:
          '取消指定的报修工单。安全原则：必须先以 confirmed=false 调用此工具向用户展示待取消工单详情并征得用户明确同意；获得用户同意后，再以 confirmed=true 调用此工具正式执行取消。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'order_id': {
            'type': 'string',
            'description': '待取消的报修工单编号或工单ID（例如“WX202609230001”或数字ID）。',
          },
          'confirmed': {
            'type': 'boolean',
            'description': '用户是否已明确同意取消此工单。首次调用传 false，待用户明确确认后再传 true。',
            'default': false,
          },
        },
        'required': ['order_id'],
      },
      handler: (arguments) async {
        final orderId = (arguments['order_id'] as String?)?.trim() ?? '';
        if (orderId.isEmpty) {
          return McpToolResult.error('参数错误: 请提供需要取消的工单编号 (order_id)');
        }

        final confirmed = arguments['confirmed'] == true;

        try {
          if (repairService.auth.status != AuthStatus.authenticated) {
            return McpToolResult.error('未登录智慧后勤报修平台，无法取消工单。请先登录。');
          }

          // 1. 获取工单最新详情以读取 actions 和 canCancel 属性
          final order = await repairService.fetchOrderDetailById(orderId);

          // 2. 检查工单当前节点是否允许取消
          if (!order.canCancel) {
            final orderLabel = order.code.isNotEmpty ? order.code : orderId;
            final statusLabel = order.status.isNotEmpty ? order.status : '当前状态';
            return McpToolResult.error(
                '工单 $orderLabel ($statusLabel) 当前不支持取消。只有在派工处理前的工单方可取消。');
          }

          // 3. 两阶段确认模式
          if (!confirmed) {
            return McpToolResult.json({
              'status': 'confirmation_required',
              'requires_confirmation': true,
              'message':
                  '取消工单是不可逆操作。请向用户展示以下待取消工单的信息，并询问是否确认取消。在用户明确确认后，再次调用此工具并将 confirmed 设为 true。',
              'order': _formatOrder(order),
            });
          }

          // 4. 正式取消
          final success = await repairService.cancelOrder(order);
          if (success) {
            return McpToolResult.json({
              'success': true,
              'message': '工单 ${order.code.isNotEmpty ? order.code : orderId} 已成功取消。',
              'order': _formatOrder(order),
            });
          } else {
            return McpToolResult.error('取消工单失败，平台未返回成功状态。');
          }
        } catch (e) {
          return McpToolResult.error('取消工单失败: $e');
        }
      },
    );
  }
}

