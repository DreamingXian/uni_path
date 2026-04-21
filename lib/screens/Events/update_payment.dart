import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/event_model.dart';
import '../../models/payment_model.dart';
import '../../services/payment_service.dart';
import '../../services/ticket_service.dart';
import '../../services/user_service.dart';

class UpdatePaymentScreen extends StatefulWidget {
  final EventModel event;
  final int ticketId;
  final PaymentModel currentPayment; // The rejected payment

  const UpdatePaymentScreen({
    super.key,
    required this.event,
    required this.ticketId,
    required this.currentPayment,
  });

  @override
  State<UpdatePaymentScreen> createState() => _UpdatePaymentScreenState();
}

class _UpdatePaymentScreenState extends State<UpdatePaymentScreen> {
  File? _newProofImage;
  bool _isSubmitting = false;

  final PaymentService _paymentService = PaymentService();
  final TicketService _ticketService = TicketService();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile != null && mounted) {
      setState(() => _newProofImage = File(pickedFile.path));
    }
  }

  Future<void> _confirmAndResubmit() async {
    if (_newProofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a new payment proof before resubmitting.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Resubmission'),
        content: const Text(
          'Are you sure you want to resubmit your payment proof? Your submission will be reviewed again within 1 to 2 working days.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resubmit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload new proof image
      final newProofUrl = await _paymentService.uploadPaymentProof(_newProofImage!);

      // 2. Update payment → new proof + status back to 'pending'
      await _paymentService.updatePaymentProofAndReopen(
        widget.currentPayment.id!,
        newProofUrl,
      );

      // 3. Reset ticket status → 'pending'
      await _ticketService.updateTicketStatus(widget.ticketId, 'pending');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment resubmitted successfully! Awaiting review.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Signal caller to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resubmit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final payment = widget.currentPayment;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Resubmit Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Event title + fee ─────────────────────────────────
            const Text('Event', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Text(event.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6A1B9A).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Payable:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(
                    'RM ${event.fees?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Payment QR ────────────────────────────────────────
            if (event.paymentQrUrl != null && event.paymentQrUrl!.isNotEmpty) ...[
              const Text('Payment QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(event.paymentQrUrl!, height: 220, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Previous (rejected) proof ─────────────────────────
            const Text('Previous Proof', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  payment.proofUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.grey[100],
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
                  ),
                ),
              ),
            ),

            // Rejection reason
            if (payment.adminNote != null && payment.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 14),
                        SizedBox(width: 6),
                        Text('Rejection Reason',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(payment.adminNote!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ── New proof upload ──────────────────────────────────
            const Text('Please Resubmit Your Payment Proof',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: _newProofImage != null
                    ? Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_newProofImage!,
                                width: double.infinity, height: 160, fit: BoxFit.contain),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => setState(() => _newProofImage = null),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, size: 40, color: Color(0xFF6A1B9A)),
                          SizedBox(height: 10),
                          Text('Tap to upload new screenshot (JPG/PNG)',
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                          Text('Required *', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),

            // ── Submit button ─────────────────────────────────────
            if (_isSubmitting)
              const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
            else
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _confirmAndResubmit,
                  child: const Text('RESUBMIT PAYMENT',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
