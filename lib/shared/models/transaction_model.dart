import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { credit, debit, topup, withdrawal }

class TransactionModel {
  final String id;
  final TransactionType type;
  final String uid;
  final int amount; // in rupees
  final String? relatedId; // campaign ID, post ID, etc.
  final String? note;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.uid,
    required this.amount,
    this.relatedId,
    this.note,
    required this.createdAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      type: _parseType(data['type']),
      uid: data['uid'] ?? '',
      amount: (data['amount'] ?? 0) as int,
      relatedId: data['relatedId'],
      note: data['note'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'uid': uid,
      'amount': amount,
      'relatedId': relatedId,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static TransactionType _parseType(String? s) {
    switch (s) {
      case 'credit':
        return TransactionType.credit;
      case 'debit':
        return TransactionType.debit;
      case 'topup':
        return TransactionType.topup;
      case 'withdrawal':
        return TransactionType.withdrawal;
      default:
        return TransactionType.credit;
    }
  }

  bool get isCredit =>
      type == TransactionType.credit || type == TransactionType.topup;

  String get typeLabel {
    switch (type) {
      case TransactionType.credit:
        return 'Views Credit';
      case TransactionType.debit:
        return 'Deducted';
      case TransactionType.topup:
        return 'Wallet Top-up';
      case TransactionType.withdrawal:
        return 'Withdrawal';
    }
  }
}

enum WithdrawalStatus { pending, processing, completed, rejected }

class WithdrawalRequestModel {
  final String id;
  final String creatorUid;
  final int amount; // in rupees
  final String? upiId;
  final String? bankAccount;
  final String? bankIfsc;
  final String? bankHolderName;
  final WithdrawalStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? creatorName;

  const WithdrawalRequestModel({
    required this.id,
    required this.creatorUid,
    required this.amount,
    this.upiId,
    this.bankAccount,
    this.bankIfsc,
    this.bankHolderName,
    this.status = WithdrawalStatus.pending,
    required this.createdAt,
    this.processedAt,
    this.creatorName,
  });

  factory WithdrawalRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WithdrawalRequestModel(
      id: doc.id,
      creatorUid: data['creatorUid'] ?? '',
      amount: (data['amount'] ?? 0) as int,
      upiId: data['upiId'],
      bankAccount: data['bankAccount'],
      bankIfsc: data['bankIfsc'],
      bankHolderName: data['bankHolderName'],
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      creatorName: data['creatorName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorUid': creatorUid,
      'amount': amount,
      'upiId': upiId,
      'bankAccount': bankAccount,
      'bankIfsc': bankIfsc,
      'bankHolderName': bankHolderName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'creatorName': creatorName,
    };
  }

  WithdrawalRequestModel copyWith({
    WithdrawalStatus? status,
    DateTime? processedAt,
  }) {
    return WithdrawalRequestModel(
      id: id,
      creatorUid: creatorUid,
      amount: amount,
      upiId: upiId,
      bankAccount: bankAccount,
      bankIfsc: bankIfsc,
      bankHolderName: bankHolderName,
      status: status ?? this.status,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
      creatorName: creatorName,
    );
  }

  static WithdrawalStatus _parseStatus(String? s) {
    switch (s) {
      case 'pending':
        return WithdrawalStatus.pending;
      case 'processing':
        return WithdrawalStatus.processing;
      case 'completed':
        return WithdrawalStatus.completed;
      case 'rejected':
        return WithdrawalStatus.rejected;
      default:
        return WithdrawalStatus.pending;
    }
  }

  String get statusLabel {
    switch (status) {
      case WithdrawalStatus.pending:
        return 'Pending';
      case WithdrawalStatus.processing:
        return 'Processing';
      case WithdrawalStatus.completed:
        return 'Completed';
      case WithdrawalStatus.rejected:
        return 'Rejected';
    }
  }

  String get paymentMethod =>
      upiId != null ? 'UPI: $upiId' : 'Bank: $bankAccount';
}
