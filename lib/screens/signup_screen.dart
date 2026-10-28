import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../widgets/widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _yearLevels = [
    '1st Year College',
    '2nd Year College',
    '3rd Year College',
    '4th Year College',
    '5th Year College',
  ];

  final _name = TextEditingController();
  final _studentNo = TextEditingController();
  final _university = TextEditingController();
  final _program = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _yearLevel;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _agreed = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _studentNo.dispose();
    _university.dispose();
    _program.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty ||
        _studentNo.text.trim().isEmpty ||
        _university.text.trim().isEmpty ||
        _program.text.trim().isEmpty ||
        _yearLevel == null ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirm.text.isEmpty) {
      return 'Fill in all fields.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      return 'Please enter a valid email address.';
    }
    if (_password.text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (_password.text != _confirm.text) {
      return 'Passwords do not match.';
    }
    if (!_agreed) {
      return 'Please accept the Terms of Service and Privacy Policy.';
    }
    return null;
  }

  Future<void> _signup() async {
    final error = _validate();
    if (error != null) {
      showMsg(context, error, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final messenger = ScaffoldMessenger.of(context);
      await state.auth.signUp(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        studentNumber: _studentNo.text,
        university: _university.text,
        program: _program.text,
        yearLevel: _yearLevel!,
      );
      // Account is created and signed out -> back to the Login screen.
      if (mounted) {
        Navigator.pop(context);
      }
      messenger.showSnackBar(const SnackBar(
        content: Text('Account created! Please log in.'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) {
        showMsg(context, context.read<AppState>().auth.friendlyError(e),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- UI helpers ---------------------------------------------------------

  TextStyle get _label => GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF3A4556));

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(fontSize: 14, color: const Color(0xFFA3ABB8)),
        prefixIcon: Icon(icon, size: 19, color: AppTheme.textMuted),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(const Color(0xFFE3E8EF)),
        enabledBorder: _border(const Color(0xFFE3E8EF)),
        focusedBorder: _border(AppTheme.primaryBlue, width: 1.5),
      );

  OutlineInputBorder _border(Color c, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: width),
      );

  Widget _field(String label, Widget input) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: _label),
            const SizedBox(height: 8),
            input,
          ],
        ),
      );

  Widget _text(
          String label, TextEditingController c, String hint, IconData icon,
          {TextInputType? type,
          TextCapitalization cap = TextCapitalization.none}) =>
      _field(
        label,
        TextField(
          controller: c,
          keyboardType: type,
          textCapitalization: cap,
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
          decoration: _decoration(hint, icon),
        ),
      );

  Widget _passwordField(String label, TextEditingController c, bool obscure,
          VoidCallback toggle) =>
      _field(
        label,
        TextField(
          controller: c,
          obscureText: obscure,
          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textDark),
          decoration: _decoration(
            '••••••••••••••••',
            Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppTheme.textMuted),
              onPressed: toggle,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: back button + brand title
              Row(
                children: [
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE3E8EF)),
                        ),
                        child: const Icon(Icons.arrow_back,
                            size: 20, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: 'Scholar ',
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryBlue)),
                          TextSpan(
                              text: 'Wallet',
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentGold)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // balance the back button
                ],
              ),
              const SizedBox(height: 24),
              Text('Create Student Account',
                  style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue)),
              const SizedBox(height: 6),
              Text(
                'Register with your academic details to start receiving and tracking your scholarships.',
                style: GoogleFonts.poppins(
                    fontSize: 14, height: 1.5, color: const Color(0xFF4A5568)),
              ),
              const SizedBox(height: 22),

              _text('Full Name', _name, 'John Lloyd Drapiza',
                  Icons.person_outline,
                  cap: TextCapitalization.words),
              _text('Student Number', _studentNo, '2021-100234-MN-0',
                  Icons.badge_outlined),
              _text(
                  'University / College',
                  _university,
                  'Polytechnic University of the Philippines',
                  Icons.account_balance_outlined,
                  cap: TextCapitalization.words),
              _text('Program / Course', _program, 'B.S. Information Technology',
                  Icons.menu_book_outlined,
                  cap: TextCapitalization.words),

              _field(
                'Year Level',
                DropdownButtonFormField<String>(
                  initialValue: _yearLevel,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppTheme.textMuted),
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppTheme.textDark),
                  decoration: _decoration(
                      'Select year level', Icons.workspace_premium_outlined),
                  items: _yearLevels
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) => setState(() => _yearLevel = v),
                ),
              ),

              _text('School Email Address', _email,
                  'jldrapiza@student.pup.edu.ph', Icons.mail_outline,
                  type: TextInputType.emailAddress),
              _passwordField('Password', _password, _obscurePw,
                  () => setState(() => _obscurePw = !_obscurePw)),
              _passwordField('Confirm Password', _confirm, _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm)),

              // Terms
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreed,
                      activeColor: AppTheme.primaryBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            height: 1.5,
                            color: const Color(0xFF4A5568)),
                        children: [
                          const TextSpan(
                              text: 'I agree to the Scholar Wallet '),
                          TextSpan(
                              text: 'Terms of Service',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue)),
                          const TextSpan(text: ' and '),
                          TextSpan(
                              text: 'Privacy Policy',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue)),
                          const TextSpan(text: ' for financial disbursement.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Create Account button (pill with soft shadow)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _busy ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Create Account',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppTheme.textMuted)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('Sign In',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
