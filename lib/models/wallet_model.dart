class WalletModel {
  const WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
  });

  final String id;
  final String userId;
  final String name;
  final String type;
  final double balance;

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'Cash',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'type': type,
        'balance': balance,
      };
}
