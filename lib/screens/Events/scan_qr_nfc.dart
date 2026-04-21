import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import '../../services/event_service.dart';
import 'event_details.dart';

class ScanQRNFCScreen extends StatefulWidget {
  const ScanQRNFCScreen({super.key});

  @override
  State<ScanQRNFCScreen> createState() => _ScanQRNFCScreenState();
}

class _ScanQRNFCScreenState extends State<ScanQRNFCScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  
  final EventService _eventService = EventService();
  bool _isProcessing = false;
  String _selectedTab = 'Scan QR';
  bool _nfcSupported = true;

  @override
  void initState() {
    super.initState();
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
        if (record.typeNameFormat == TypeNameFormat.wellKnown) {
          final typeStr = String.fromCharCodes(record.type);
          if (typeStr == 'U') { // URI Record
            final payload = record.payload;
            if (payload.isNotEmpty) {
               int prefixByte = payload[0];
               String prefixStr = '';
               if (prefixByte == 0x01) prefixStr = 'http://www.';
               else if (prefixByte == 0x02) prefixStr = 'https://www.';
               else if (prefixByte == 0x03) prefixStr = 'http://';
               else if (prefixByte == 0x04) prefixStr = 'https://';
               
               String rest = String.fromCharCodes(payload.sublist(1));
               code = prefixStr + rest;
               break;
            }
          }
        }
      }

      if (code.isEmpty) {
        _showInvalidDialog();
        return;
      }

      _processScannedURI(code);
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
    _processScannedURI(code);
  }

  Future<void> _processScannedURI(String code) async {
    try {
      Uri uri = Uri.parse(code);
      
      // Expected structure: unipath://unipath.com/event/<eventId>
      // OR https://unipath.com/event/<eventId>
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'event') {
         if (uri.pathSegments.length > 1) {
            String eventIdStr = uri.pathSegments[1];
            int? eventId = int.tryParse(eventIdStr);
            if (eventId != null) {
               // Show loading overlay
               showDialog(
                 context: context,
                 barrierDismissible: false,
                 builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A))),
               );

               final matchedEvent = await _eventService.getEventById(eventId);
               
               if (mounted) {
                 Navigator.pop(context); // remove loading
               }

               if (matchedEvent != null) {
                 _navigateToEvent(matchedEvent);
                 return;
               }
            }
         }
      }
      
      // If we fall through to here, the link was completely wrong or didn't exist
      _showInvalidDialog();
    } catch (e) {
      _showInvalidDialog();
    }
  }

  Future<void> _navigateToEvent(matchedEvent) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(event: matchedEvent),
      ),
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
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
                  'Invalid Event Link',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This QR code or NFC tag does not contain a valid UniPath event link.',
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

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
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
        title: const Text('Scan Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
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
                          'Align Event QR Code within the frame',
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
                  ? '(Approach an NFC Event Tag)'
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
