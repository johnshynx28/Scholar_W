// Data models shared across the app.
// All map to Supabase Postgres tables.

enum UserRole { scholar, admin }

class AppUser {
  final String id; // Firebase UID == Supabase profiles.id
  final String fullName;
  final String email;
  final UserRole role;
  final String? studentNumber;
  final String? university;
  final String? program;
  final String? yearLevel;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.role = UserRole.scholar,
    this.studentNumber,
    this.university,
    this.program,
    this.yearLevel,
  });

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        fullName: (m['full_name'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        role: m['role'] == 'admin' ? UserRole.admin : UserRole.scholar,
        studentNumber: m['student_number'] as String?,
        university: m['university'] as String?,
        program: m['program'] as String?,
        yearLevel: m['year_level'] as String?,
      );
}

enum TxType { credit, debit }

enum TxStatus { completed, pending, rejected }

class WalletTransaction {
  final String id;
  final String title;
  final String subtitle; // e.g. "Disbursed • Nov 15"
  final double amount; // negative = debit
  final TxType type;
  final TxStatus status;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> m) =>
      WalletTransaction(
        id: m['id'].toString(),
        title: (m['title'] ?? '') as String,
        subtitle: (m['subtitle'] ?? '') as String,
        amount: (m['amount'] as num).toDouble(),
        type: m['type'] == 'credit' ? TxType.credit : TxType.debit,
        status: TxStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => TxStatus.completed,
        ),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

enum WithdrawalStatus { pending, approved, rejected }

class WithdrawalRequest {
  final String id;
  final String scholarId;
  final String scholarName;
  final String accountName;
  final String accountNumber;
  final String paymentMethod; // GCash, PayMaya, Bank Transfer
  final double amount;
  final String? notes;
  final WithdrawalStatus status;
  final DateTime createdAt;

  WithdrawalRequest({
    required this.id,
    required this.scholarId,
    required this.scholarName,
    required this.accountName,
    required this.accountNumber,
    required this.paymentMethod,
    required this.amount,
    this.notes,
    this.status = WithdrawalStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toInsert() => {
        'scholar_id': scholarId,
        'account_name': accountName,
        'account_number': accountNumber,
        'payment_method': paymentMethod,
        'amount': amount,
        'notes': notes,
        'status': status.name,
      };

  factory WithdrawalRequest.fromMap(Map<String, dynamic> m) =>
      WithdrawalRequest(
        id: m['id'].toString(),
        scholarId: (m['scholar_id'] ?? '') as String,
        scholarName: (m['scholar_name'] ?? '') as String,
        accountName: (m['account_name'] ?? '') as String,
        accountNumber: (m['account_number'] ?? '') as String,
        paymentMethod: (m['payment_method'] ?? '') as String,
        amount: (m['amount'] as num).toDouble(),
        notes: m['notes'] as String?,
        status: WithdrawalStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => WithdrawalStatus.pending,
        ),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class ExpenseReport {
  final String? id;
  final String scholarId;
  final String title;
  final double amount;
  final String category; // Supplies, Books, Transport
  final String? description;
  final String? receiptUrl; // Supabase Storage public URL
  final TxStatus status; // pending | completed (= approved) | rejected
  final String scholarName; // filled when read by the admin
  final DateTime? createdAt;

  ExpenseReport({
    this.id,
    required this.scholarId,
    required this.title,
    required this.amount,
    required this.category,
    this.description,
    this.receiptUrl,
    this.status = TxStatus.pending,
    this.scholarName = '',
    this.createdAt,
  });

  factory ExpenseReport.fromMap(Map<String, dynamic> m) {
    final profile = m['profiles'];
    final raw = m['status'];
    return ExpenseReport(
      id: m['id']?.toString(),
      scholarId: (m['scholar_id'] ?? '') as String,
      title: (m['title'] ?? '') as String,
      amount: ((m['amount'] ?? 0) as num).toDouble(),
      category: (m['category'] ?? '') as String,
      description: m['description'] as String?,
      receiptUrl: m['receipt_url'] as String?,
      status: raw == 'approved'
          ? TxStatus.completed
          : TxStatus.values.firstWhere(
              (s) => s.name == raw,
              orElse: () => TxStatus.pending,
            ),
      scholarName: profile is Map
          ? ((profile['full_name'] ?? 'Scholar') as String)
          : 'Scholar',
      createdAt: m['created_at'] is String
          ? DateTime.tryParse(m['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsert() => {
        'scholar_id': scholarId,
        'title': title,
        'amount': amount,
        'category': category,
        'description': description,
        'receipt_url': receiptUrl,
        'status': status.name,
      };
}

class Scholar {
  final String id; // profile id
  final String studentId; // e.g. "2021-0482"
  final String name;
  final double balance;
  bool active; // FR-23: deactivated scholars receive no allowance
  bool selected;

  Scholar({
    required this.id,
    required this.studentId,
    required this.name,
    required this.balance,
    this.active = true,
    this.selected = false,
  });

  factory Scholar.fromMap(Map<String, dynamic> m) => Scholar(
        id: m['id'] as String,
        studentId: (m['student_number'] ?? m['student_id'] ?? '') as String,
        name: (m['full_name'] ?? '') as String,
        balance: ((m['balance'] ?? 0) as num).toDouble(),
        active: (m['is_active'] as bool?) ?? true,
      );
}

/// One row in the admin "System Activities" feed (built from real data).
class ActivityItem {
  final String title;
  final String subtitle;
  final String status; // completed | approved | pending | rejected | new
  final DateTime time;

  ActivityItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.time,
  });
}
