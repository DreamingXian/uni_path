import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/event_model.dart';
import '../../providers/user_provider.dart';

class TicketKeyCodeScreen extends StatefulWidget {
  final EventModel event;
  final String passCode;
  final List<String> formattedSchedules;

  const TicketKeyCodeScreen({
    super.key,
    required this.event,
    required this.passCode,
    required this.formattedSchedules,
  });

  @override
  State<TicketKeyCodeScreen> createState() => _TicketKeyCodeScreenState();
}

class _TicketKeyCodeScreenState extends State<TicketKeyCodeScreen> {
  String _selectedTab = 'QR Code';

  @override
  Widget build(BuildContext context) {
    // Extract passcode prefix before "-"
    final codeDisplay = widget.passCode.contains('-')
        ? widget.passCode.split('-').first
        : widget.passCode;

    final user = Provider.of<UserProvider>(context, listen: false).currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C), // Premium dark background
      appBar: AppBar(
        title: const Text('Show Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        children: [
                          // ── Upper part: Event info ──────────────────
                          Container(
                            color: const Color(0xFFF8F9FA),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(
                                  widget.event.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (widget.formattedSchedules.isNotEmpty)
                                  ...widget.formattedSchedules.map((s) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.access_time, size: 16, color: Color(0xFF6A1B9A)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                s,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                if (widget.event.locationName != null && widget.event.locationName!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF6A1B9A)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.event.locationName!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // ── Ticket Divider ──────────────────────────
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 1,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final dashWidth = 5.0;
                                    final dashCount = (constraints.constrainWidth() / (2 * dashWidth)).floor();
                                    return Flex(
                                      children: List.generate(dashCount, (_) {
                                        return SizedBox(
                                          width: dashWidth,
                                          height: 1,
                                          child: const DecoratedBox(decoration: BoxDecoration(color: Colors.grey)),
                                        );
                                      }),
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      direction: Axis.horizontal,
                                    );
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1E1E2C),
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 16,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1E1E2C),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // ── Lower part: QR code & Student info ──────
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(32),
                            width: double.infinity,
                            child: Column(
                              children: [
                                if (_selectedTab == 'QR Code') ...[
                                  // QR Code
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade200),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: QrImageView(
                                      data: widget.passCode,
                                      version: QrVersions.auto,
                                      size: 200.0,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    codeDisplay.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                      color: Color(0xFF1A237E),
                                    ),
                                  ),
                                ] else ...[
                                  Container(
                                    height: 250,
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.nfc, size: 80, color: Colors.grey.shade300),
                                        const SizedBox(height: 16),
                                        const Text('NFC Scanning', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                                        const Text('(Coming Soon)', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 32),
                                const Divider(),
                                const SizedBox(height: 24),
                                // User info
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Student Name', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                    Text(user?.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Student ID', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                    Text(user?.studentId ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Bottom Tab row ────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 'QR Code'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedTab == 'QR Code' ? const Color(0xFF6A1B9A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'QR Code',
                          style: TextStyle(
                            color: _selectedTab == 'QR Code' ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 'NFC'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedTab == 'NFC' ? const Color(0xFF6A1B9A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'NFC',
                          style: TextStyle(
                            color: _selectedTab == 'NFC' ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
