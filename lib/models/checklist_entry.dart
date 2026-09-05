import 'checklist_item.dart';

class ChecklistEntry {
  final String id;
  final DateTime date;
  final String inspectorName;
  final List<ChecklistItem> items;

  ChecklistEntry({
    required this.id,
    required this.date,
    required this.inspectorName,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'inspectorName': inspectorName,
        'items': items.map((item) => item.toJson()).toList(),
      };

  factory ChecklistEntry.fromJson(Map<String, dynamic> json) => ChecklistEntry(
        id: json['id'],
        date: DateTime.parse(json['date']),
        inspectorName: json['inspectorName'],
        items: (json['items'] as List)
            .map((item) => ChecklistItem.fromJson(item))
            .toList(),
      );
}
