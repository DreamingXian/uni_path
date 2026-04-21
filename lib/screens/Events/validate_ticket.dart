import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import '../../models/event_model.dart';
import '../../services/ticket_service.dart';
import 'ticket_details.dart';

class ValidateTicketScreen extends StatefulWidget {
  final EventModel event;

  const ValidateTicketScreen({super.key, required this.event});

  @override
  State<ValidateTicketScreen> createState() => _ValidateTicketScreenState();
}

class _ValidateTicketScreenState extends State<ValidateTicketScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  
  final TicketService _ticketService = TicketService();
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  bool _isProcessing = false; // prevents multiple rapid triggers
  String _selectedTab = 'Scan QR';
  bool _nfcSupported = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _checkNfcSupport();
  }

  Future<void> _checkNfcSupport() async {
    final availability = await NfcManager.instance.checkAvailability();
    if (mounted) {
      setState(() {
        _nfcSupported = availability == NfcAvailability.enabled;
      });
    }
  }

  Future<void> _loadTickets() async {
    final tickets = await _ticketService.getTicketsForValidation(widget.event.id!);
    if (mounted) {
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _stopNfcSession();
    super.dispose();
  }

  void _startNfcSession() {
    if (!_nfcSupported) return;
    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
      
      if (_isProcessing) return;
      _isProcessing = true;
      
      // Stop scanning before pushing new routes or dialogs
      await NfcManager.instance.stopSession();

      Ndef? ndef = Ndef.from(tag);
      if (ndef == null || ndef.cachedMessage == null) {
        _showInvalidDialog();
        return;
      }
      
      String code = '';
      for (var record in ndef.cachedMessage!.records) {
        if (record.typeNameFormat == TypeNameFormat.media) {
           final typeStr = String.fromCharCodes(record.type);
           if (typeStr == 'application/vnd.unipath.ticket') {
              final payload = record.payload;
              if (payload.isNotEmpty) {
                 code = String.fromCharCodes(payload);
                 break;
              }
           }
        } else if (record.typeNameFormat == TypeNameFormat.wellKnown) {
          final payload = record.payload;
          if (payload.isNotEmpty) {
             // NDEF Text Record: 1st byte is status (bit 5-0 is lang code length)
             int langCodeLen = payload[0] & 0x3F;
             if (payload.length > 1 + langCodeLen) {
                code = String.fromCharCodes(payload.sublist(1 + langCodeLen));
                break;
             }
          }
        }
      }

      if (code.isEmpty) {
        _showInvalidDialog();
        return;
      }

      final matchedTicket = _tickets.firstWhere(
        (t) => (t['pass_code'] as String?) == code,
        orElse: () => <String, dynamic>{}, 
      );

      if (matchedTicket.isNotEmpty) {
        _navigateToDetails(matchedTicket);
      } else {
        _showInvalidDialog();
      }
    });
  }

  void _stopNfcSession() {
    if (_nfcSupported) {
      NfcManager.instance.stopSession();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || capture.barcodes.isEmpty) return;
    
    final String? code = capture.barcodes.first.rawValue;
    if (code == null) return;

    _isProcessing = true;

    // Check if the QR code matches any ticket for this event
    final matchedTicket = _tickets.firstWhere(
      (t) => (t['pass_code'] as String?) == code,
      orElse: () => <String, dynamic>{}, // Return empty map if no match
    );

    if (matchedTicket.isNotEmpty) {
      _navigateToDetails(matchedTicket);
    } else {
      _showInvalidDialog();
    }
  }

  Future<void> _navigateToDetails(Map<String, dynamic> ticketData) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailsScreen(
          event: widget.event,
          ticketData: ticketData,
        ),
      ),
    );

    // After returning from details, reload tickets to get freshest statuses and resume scanning
    await _loadTickets();
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      // Restart the NFC poller if we're still on the NFC tab!
      if (_selectedTab == 'Scan NFC') {
        _startNfcSession();
      }
    }
  }

  Future<void> _showInvalidDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 10),
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Invalid QR Code Detected',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This QR code does not match any registered tickets for this event.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Resume scanning after dismissing dialog
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      // Restart the NFC poller if we're still on the NFC tab!
      if (_selectedTab == 'Scan NFC') {
        _startNfcSession();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Validate Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
        : Column(
            children: [
              // ── Scanner Area ──
              Expanded(
                child: _selectedTab == 'Scan QR'
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                        ),
                        // Corner scanner frame
                        CustomerScannerOverlay(overlayColour: Colors.black.withValues(alpha: 0.5)),
                        // Helpful text
                        Positioned(
                          bottom: 50,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Align QR Code within the frame',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildNFCTab(),
              ),

              // ── Bottom Navigation Tab ──
              Container(
                color: const Color(0xFF1E1E2C),
                padding: const EdgeInsets.only(top: 16, bottom: 32, left: 24, right: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedTab = 'Scan QR');
                            _stopNfcSession();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _selectedTab == 'Scan QR' ? const Color(0xFF6A1B9A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Scan QR',
                              style: TextStyle(
                                color: _selectedTab == 'Scan QR' ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedTab = 'Scan NFC');
                            _startNfcSession();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _selectedTab == 'Scan NFC' ? const Color(0xFF6A1B9A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Scan NFC',
                              style: TextStyle(
                                color: _selectedTab == 'Scan NFC' ? Colors.white : Colors.white70,
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
              ),
            ],
          ),
    );
  }

  Widget _buildNFCTab() {
    return Container(
      color: const Color(0xFF1E1E2C), // Match background
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _nfcSupported ? Icons.nfc : Icons.cancel, 
              size: 80, 
              color: _nfcSupported ? Colors.grey.shade600 : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _nfcSupported ? 'NFC Scanning' : 'NFC Unsupported',
              style: TextStyle(
                color: _nfcSupported ? Colors.white : Colors.red, 
                fontSize: 20, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _nfcSupported 
                  ? '(Preparing to scan NFC)'
                  : 'This device is not applicable with NFC functionality.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _nfcSupported ? Colors.white54 : Colors.red.shade300, 
                fontSize: 16
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Overlay for Scanner Corners ──
class CustomerScannerOverlay extends StatelessWidget {
  const CustomerScannerOverlay({super.key, required this.overlayColour});

  final Color overlayColour;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;

      // Ensure the scanner cutout is a square in the center
      final scanAreaSize = width * 0.7; 

      return Stack(
        children: [
          // Semi-transparent overlay with a cutout
          ColorFiltered(
            colorFilter: ColorFilter.mode(overlayColour, BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Positioned(
                  left: (width - scanAreaSize) / 2,
                  top: (height - scanAreaSize) / 2,
                  child: Container(
                    height: scanAreaSize,
                    width: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Corner UI bounds
          Positioned(
            left: (width - scanAreaSize) / 2,
            top: (height - scanAreaSize) / 2,
            child: _CornerBorders(size: scanAreaSize),
          ),
        ],
      );
    });
  }
}

class _CornerBorders extends StatelessWidget {
  final double size;
  const _CornerBorders({required this.size});

  @override
  Widget build(BuildContext context) {
    const double length = 40.0;
    const double thickness = 4.0;
    const double rad = 16.0; // matching the cutout's radius
    const Color colour = Colors.white;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Top Left
          Positioned(
            top: 0, left: 0,
            child: Container(
              width: length,
              height: length,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: colour, width: thickness),
                  left: BorderSide(color: colour, width: thickness),
                ),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(rad)),
              ),
            ),
          ),
          // Top Right
          Positioned(
            top: 0, right: 0,
            child: Container(
              width: length,
              height: length,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: colour, width: thickness),
                  right: BorderSide(color: colour, width: thickness),
                ),
                borderRadius: BorderRadius.only(topRight: Radius.circular(rad)),
              ),
            ),
          ),
          // Bottom Left
          Positioned(
            bottom: 0, left: 0,
            child: Container(
              width: length,
              height: length,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colour, width: thickness),
                  left: BorderSide(color: colour, width: thickness),
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(rad)),
              ),
            ),
          ),
          // Bottom Right
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: length,
              height: length,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colour, width: thickness),
                  right: BorderSide(color: colour, width: thickness),
                ),
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(rad)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
