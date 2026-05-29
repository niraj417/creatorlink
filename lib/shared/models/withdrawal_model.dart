import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawalRequestModel {
  final String id;
  final String creatorUid;
  final String? creatorName;
  final int amount; // in rupees
  final String? upiId;
  final String? bankAccount;
  final String? bankIfsc;
  final String? bankHolderName;
  final String status; // pending | processed | rejected
  final DateTime createdAt;
  final DateTime? processedAt;

  const WithdrawalRequestModel({
    required this.id,
    required this.creatorUid,
    this.creatorName,
    required this.amount,
    this.upiId,
    this.bankAccount,
    this.bankIfsc,
    this.bankHolderName,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  factory WithdrawalRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WithdrawalRequestModel(
      id: doc.id,
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'],
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      upiId: data['upiId'],
      bankAccount: data['bankAccount'],
      bankIfsc: data['bankIfsc'],
      bankHolderName: data['bankHolderName'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'amount': amount,
      'upiId': upiId,
      'bankAccount': bankAccount,
      'bankIfsc': bankIfsc,
      'bankHolderName': bankHolderName,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
    };
  }

  bool get isPending => status == 'pending';
  bool get isProcessed => status == 'processed';
  bool get isRejected => status == 'rejected';

  String get payoutMethod {
    if (upiId != null) return 'UPI: $upiId';
    if (bankAccount != null) return 'Bank: $bankAccount';
    return 'Unknown';
  }
}
