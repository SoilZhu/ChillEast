class ClassroomModel {
  final String jsmc;
  final String zws;

  ClassroomModel({required this.jsmc, required this.zws});

  factory ClassroomModel.fromJson(Map<String, dynamic> json) {
    return ClassroomModel(
      jsmc: json['JSMC'] ?? '',
      zws: json['ZWS'] ?? '0',
    );
  }
}

class ClassroomInquiryOptions {
  final List<String> buildings;
  final List<String> sections;
  final List<String> weeks;
  final List<Map<String, String>> days; // label, value

  ClassroomInquiryOptions({
    required this.buildings,
    required this.sections,
    required this.weeks,
    required this.days,
  });
}
