class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.icon,
  });

  final String id;
  final String userId;
  final String name;
  final String type;
  final String icon;

  bool get isDefault => userId.isEmpty;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'Chi',
        icon: json['icon']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'type': type,
        'icon': icon,
      };
}
