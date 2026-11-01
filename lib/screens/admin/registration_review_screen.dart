import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/verification_service.dart';
import '../../widgets/widgets.dart';

class RegistrationReviewScreen extends StatefulWidget {
  const RegistrationReviewScreen({super.key});
  @override
  State<RegistrationReviewScreen> createState() =>
      _RegistrationReviewScreenState();
}

class _RegistrationReviewScreenState extends State<RegistrationReviewScreen> {
  final _service = VerificationService();
  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;
  VerificationStatus? _filter = VerificationStatus.pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _service.registrations();
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load registrations. Check your connection, Firebase integration, and database migration.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(AppUser user) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => _RegistrationDetail(user: user)));
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final users = _users
        .where((u) => _filter == null || u.verificationStatus == _filter)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Registration Verification')),
      body: Column(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Verify existing scholarship beneficiaries against the official roster. Registration is not an application for a new scholarship.')),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              const SizedBox(width: 12),
              ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null)),
              ...VerificationStatus.values.map((s) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                      label: Text(s.label),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s)))),
              const SizedBox(width: 12),
            ])),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_error != null) ...[
                          Text(_error!),
                          TextButton(
                              onPressed: _load, child: const Text('Retry'))
                        ] else if (users.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No registrations in this status.')),
                        ...users.map((u) => Card(
                            child: ListTile(
                                leading:
                                    const Icon(Icons.person_search_outlined),
                                title: Text(u.fullName),
                                subtitle: Text(
                                    '${u.studentNumber ?? "No student number"}\nDeclared scholar: ${u.declaredScholar ? "Yes" : "No"}\n${u.scholarshipName}\n${u.verificationStatus.label}'),
                                isThreeLine: false,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _open(u)))),
                      ],
                    ))),
      ]),
    );
  }
}

class _RegistrationDetail extends StatefulWidget {
  final AppUser user;
  const _RegistrationDetail({required this.user});
  @override
  State<_RegistrationDetail> createState() => _RegistrationDetailState();
}

class _RegistrationDetailState extends State<_RegistrationDetail> {
  final _notes = TextEditingController();
  final _service = VerificationService();
  late Future<List<Map<String, dynamic>>> _history;
  bool _rosterChecked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _history = _service.history(widget.user.id);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _decide(VerificationStatus status) async {
    if (status == VerificationStatus.approved && !_rosterChecked) return;
    if ((status == VerificationStatus.rejected ||
            status == VerificationStatus.needsInfo) &&
        _notes.text.trim().isEmpty) {
      showMsg(context, 'Provide a reason or describe the information required.',
          error: true);
      return;
    }
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(status.label),
              content: Text(
                  '${widget.user.fullName}\n\n${status == VerificationStatus.approved ? "Approve this verified registration and enable payout access" : "Save this registration review"}?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save decision'))
              ],
            ));
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.review(widget.user, status, _notes.text);
      if (mounted) {
        showMsg(context, 'Registration review recorded.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showMsg(context,
            'Review was not saved. The status may have changed; reopen the registration and try again. ($e)',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final undecided = u.verificationStatus != VerificationStatus.approved &&
        u.verificationStatus != VerificationStatus.rejected;
    return Scaffold(
      appBar: AppBar(title: const Text('Review Registration')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(u.fullName, style: Theme.of(context).textTheme.headlineSmall),
        Text(u.verificationStatus.label),
        const SizedBox(height: 16),
        Text('Email: ${u.email}'),
        Text('Student number: ${u.studentNumber ?? "—"}'),
        Text('School: ${u.university ?? "—"}'),
        Text('Program: ${u.program ?? "—"}'),
        Text('Year: ${u.yearLevel ?? "—"}'),
        Text('Declared existing scholar: ${u.declaredScholar ? "Yes" : "No"}'),
        Text(
            'Scholarship: ${u.scholarshipName.isEmpty ? "Not provided" : u.scholarshipName}'),
        Text(
            'Award reference: ${u.scholarshipReference.isEmpty ? "Not provided" : u.scholarshipReference}'),
        if (u.reviewNotes.isNotEmpty)
          Text('Previous feedback: ${u.reviewNotes}'),
        const SizedBox(height: 20),
        if (undecided) ...[
          const Text(
              'Check the school’s official scholarship roster and confirm that these details belong to this student. A declaration alone is not proof.'),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                  'I verified this student against the official scholarship roster'),
              value: _rosterChecked,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _rosterChecked = v ?? false)),
          TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Review notes / reason',
                  helperText:
                      'Required when rejecting or requesting information')),
          const SizedBox(height: 16),
          if (u.verificationStatus == VerificationStatus.pending)
            OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _decide(VerificationStatus.underReview),
                child: const Text('Mark under review')),
          OutlinedButton(
              onPressed:
                  _busy ? null : () => _decide(VerificationStatus.needsInfo),
              child: const Text('Request information')),
          FilledButton(
              onPressed: !_busy &&
                      _rosterChecked &&
                      u.declaredScholar &&
                      u.scholarshipName.isNotEmpty
                  ? () => _decide(VerificationStatus.approved)
                  : null,
              child: const Text('Approve verified scholar')),
          TextButton(
              onPressed:
                  _busy ? null : () => _decide(VerificationStatus.rejected),
              child: const Text('Reject registration')),
        ],
        const SizedBox(height: 24),
        const Text('Review history',
            style: TextStyle(fontWeight: FontWeight.bold)),
        FutureBuilder<List<Map<String, dynamic>>>(
            future: _history,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return const Text('Review history could not be loaded.');
              }
              if (!snap.hasData) return const LinearProgressIndicator();
              if (snap.data!.isEmpty) {
                return const Text('No review recorded yet.');
              }
              return Column(
                  children: snap.data!
                      .map((r) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title:
                              Text(verificationStatusFrom(r['decision']).label),
                          subtitle: Text(
                              '${r["notes"] ?? ""}\n${r["created_at"]}\nReviewer: ${r["reviewer_id"] ?? "Student resubmission"}')))
                      .toList());
            }),
      ]),
    );
  }
}
