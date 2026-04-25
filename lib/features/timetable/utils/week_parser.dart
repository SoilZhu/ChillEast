/// 周次解析工具类
class WeekParser {
  /// 解析周次字符串为周次列表
  /// 
  /// 支持的格式：
  /// - "1-10(周)" → [1,2,3,4,5,6,7,8,9,10]
  /// - "1,3,5,7,9(周)" → [1,3,5,7,9]
  /// - "1-10,12-14(周)" → [1,2,3,4,5,6,7,8,9,10,12,13,14]
  /// - "1(周)" → [1]
  /// - "1-10,13(周)" → [1,2,3,4,5,6,7,8,9,10,13]
  /// - "1-8,10,12(周)" → [1,2,3,4,5,6,7,8,10,12]
  static List<int> parseWeeks(String weekString) {
    if (weekString.isEmpty) return [];
    
    // 移除 "(周)" 后缀和空格
    String cleaned = weekString.replaceAll('(周)', '').replaceAll(' ', '').trim();
    
    if (cleaned.isEmpty) return [];
    
    List<int> weeks = [];
    
    // 按逗号分割
    List<String> parts = cleaned.split(',');
    
    for (String part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;
      
      if (part.contains('-')) {
        // 范围格式：1-10
        List<String> range = part.split('-');
        if (range.length == 2) {
          try {
            int start = int.parse(range[0]);
            int end = int.parse(range[1]);
            
            // 确保 start <= end
            if (start > end) {
              final temp = start;
              start = end;
              end = temp;
            }
            
            for (int i = start; i <= end; i++) {
              weeks.add(i);
            }
          } catch (e) {
            // 解析失败，跳过
            continue;
          }
        }
      } else {
        // 单个周次：1 或 13
        try {
          weeks.add(int.parse(part));
        } catch (e) {
          // 解析失败，跳过
          continue;
        }
      }
    }
    
    // 去重并排序
    weeks = weeks.toSet().toList()..sort();
    
    return weeks;
  }
  
  /// 将周次列表格式化为显示字符串
  static String formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) return '';
    
    if (weeks.length == 1) {
      return '第${weeks[0]}周';
    }
    
    // 尝试合并连续周次
    List<String> parts = [];
    int i = 0;
    
    while (i < weeks.length) {
      int start = weeks[i];
      int end = start;
      
      // 查找连续序列
      while (i + 1 < weeks.length && weeks[i + 1] == end + 1) {
        i++;
        end = weeks[i];
      }
      
      if (start == end) {
        parts.add('$start');
      } else {
        parts.add('$start-$end');
      }
      
      i++;
    }
    
    return '第${parts.join(',')}周';
  }
}
