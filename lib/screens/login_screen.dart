import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final AppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _connectionTimeout = Duration(seconds: 15);
  final urlController = TextEditingController(text: '');
  final tokenController = TextEditingController();
  bool loading = false;
  bool obscure = true;
  bool urlEdited = false;

  @override
  void initState() {
    super.initState();
    urlController.text =
        widget.state.savedUrl ?? 'http://homeassistant.local:8123';
    urlController.addListener(_markUrlEdited);
  }

  void _markUrlEdited() => urlEdited = true;

  @override
  void dispose() {
    urlController.removeListener(_markUrlEdited);
    urlController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    final url = urlController.text.trim();
    final token = tokenController.text.trim();
    if (url.isEmpty || token.isEmpty) {
      _showError('Enter your Home Assistant address and access token.');
      return;
    }
    if (!_isValidHomeAssistantUrl(url)) {
      _showError(
        'Enter a valid Home Assistant URL, including http:// or https://.',
      );
      return;
    }
    setState(() => loading = true);
    try {
      await widget.state
          .login(url, token)
          .timeout(
            _connectionTimeout,
            onTimeout: () => throw Exception('Connection timed out.'),
          );
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        _showError(
          message == 'That access token was not accepted.' ||
                  message == 'Connected, but no vacuum entities were found.'
              ? message
              : 'Connection error. Check Home Assistant and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _isValidHomeAssistantUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void toggleTokenVisibility() => setState(() => obscure = !obscure);

  @override
  Widget build(BuildContext context) {
    final restoredUrl = widget.state.savedUrl;
    if (widget.state.isInitialized &&
        !urlEdited &&
        restoredUrl != null &&
        urlController.text != restoredUrl) {
      urlController.value = TextEditingValue(
        text: restoredUrl,
        selection: TextSelection.collapsed(offset: restoredUrl.length),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: _LoginBackdrop()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 840;
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: wide
                            ? Row(
                                children: [
                                  const Expanded(child: _WelcomeCopy()),
                                  const SizedBox(width: 72),
                                  SizedBox(
                                    width: 440,
                                    child: _LoginCard(parent: this),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  const _WelcomeCopy(compact: true),
                                  const SizedBox(height: 36),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 480,
                                    ),
                                    child: _LoginCard(parent: this),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: fern,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cleaning_services_rounded,
                color: mint,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'SCRUBBY',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.2),
            ),
          ],
        ),
        SizedBox(height: compact ? 28 : 52),
        Text(
          'A cleaner home,\nwithout the fuss.',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: compact ? 42 : 64,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Your robot vacuums, beautifully organised\nand powered by Home Assistant.',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.parent});
  final _LoginScreenState parent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 50,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect your home',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Use a long-lived access token from your Home Assistant profile.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (parent.widget.state.restoreError case final error?) ...[
            const SizedBox(height: 14),
            Text(error, style: const TextStyle(color: coral)),
          ],
          const SizedBox(height: 26),
          const Text('HOME ASSISTANT URL', style: _labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: parent.urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://home.example.com',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 18),
          const Text('LONG-LIVED ACCESS TOKEN', style: _labelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: parent.tokenController,
            obscureText: parent.obscure,
            decoration: InputDecoration(
              hintText: 'Paste your token',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                onPressed: parent.toggleTokenVisibility,
                icon: Icon(
                  parent.obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: parent.loading ? null : parent.connect,
              style: FilledButton.styleFrom(
                backgroundColor: fern,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: parent.loading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Connect Home Assistant'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: parent.widget.state.startDemo,
              child: const Text('Explore with demo home'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: ink.withValues(alpha: .45),
              ),
              const SizedBox(width: 6),
              Text(
                'Credentials stay on this device',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _labelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.1,
  color: fern,
);

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BackdropPainter());
  }
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ink);
    final glow = Paint()..color = fern;
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .88),
      size.width * .34,
      glow,
    );
    canvas.drawCircle(
      Offset(size.width * .8, -size.height * .1),
      size.width * .28,
      Paint()..color = const Color(0xFF2B644F),
    );
    final line = Paint()
      ..color = mint.withValues(alpha: .1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 7; i++) {
      canvas.drawCircle(
        Offset(size.width * .1, size.height * .85),
        70.0 + i * 44,
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
