import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String _category = 'Supplies';
  Uint8List? _receiptBytes;
  String _receiptExt = 'jpg';
  bool _busy = false;

  static const _categories = ['Supplies', 'Books', 'Transport'];

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final name = picked.name.toLowerCase();
    setState(() {
      _receiptBytes = bytes;
      _receiptExt = name.endsWith('.png') ? 'png' : 'jpg';
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (_title.text.isEmpty || amount <= 0) {
      showMsg(context, 'Enter an expense title and amount.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      String? receiptUrl;
      if (_receiptBytes != null) {
        receiptUrl = await state.wallet
            .uploadReceipt(_receiptBytes!, _receiptExt, state.user!.id);
      }
      await state.wallet.submitExpense(ExpenseReport(
        scholarId: state.user!.id,
        title: _title.text.trim(),
        amount: amount,
        category: _category,
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        receiptUrl: receiptUrl,
      ));
      if (mounted) {
        showMsg(context, 'Expense report submitted.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMsg(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Submit Expense Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Expense Title'),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  hintText: 'e.g. Scientific Calculator Purchase'),
            ),
            const SizedBox(height: 16),
            _label('Amount Spent (PHP)'),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0.00'),
            ),
            const SizedBox(height: 16),
            _label('Category'),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Supplies'),
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                builder: (_) => SafeArea(
                  child: Wrap(children: [
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('Take a photo'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library_outlined),
                      title: const Text('Choose from gallery'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ]),
                ),
              ),
              child: Container(
                height: 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: context.colors.border, style: BorderStyle.solid),
                ),
                child: _receiptBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(_receiptBytes!, fit: BoxFit.cover))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_outlined,
                                  color: context.colors.brand),
                              const SizedBox(width: 14),
                              Icon(Icons.image_outlined,
                                  color: context.colors.brand),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Tap to upload receipt image',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.brand)),
                          const SizedBox(height: 4),
                          const Text('JPG, PNG up to 10MB',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            _label('Additional Description'),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Explain the purpose of this academic purchase...'),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary)),
      );
}
