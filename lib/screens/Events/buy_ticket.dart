import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/event_model.dart';
import '../../models/payment_model.dart';
import '../../models/ticket_model.dart';
import '../../providers/user_provider.dart';
import '../../services/payment_service.dart';
import '../../services/ticket_service.dart';

class BuyTicketScreen extends StatefulWidget {
  final EventModel event;

  const BuyTicketScreen({super.key, required this.event});

  @override
  State<BuyTicketScreen> createState() => _BuyTicketScreenState();
}

class _BuyTicketScreenState extends State<BuyTicketScreen> {
  File? _proofImage;
  bool _isSubmitting = false;

  final PaymentService _paymentService = PaymentService();
  final TicketService _ticketService = TicketService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProofImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile != null && mounted) {
      setState(() {
        _proofImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPayment() async {
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload your payment proof.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) throw Exception("User is not logged in.");

      // 1. Upload the image to storage
      final proofUrl = await _paymentService.uploadPaymentProof(_proofImage!);

      // 2. Create the pending Ticket first — DB auto-generates pass_code as UUID
      final ticket = TicketModel(
        userId: user.id!,
        eventId: widget.event.id!,
        status: 'pending',
      );
      final newTicketId = await _ticketService.bookTicket(ticket);

      // 3. Create the Payment record referencing the new ticket
      final payment = PaymentModel(
        userId: user.id!,
        ticketId: newTicketId,
        amount: widget.event.fees ?? 0.0,
        proofUrl: proofUrl,
        status: 'pending',
      );
      await _paymentService.submitPayment(payment);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Payment Submitted'),
              ],
            ),
            content: const Text(
                'Your payment proof has been successfully submitted! It is currently under review by the event organizer. Please allow 1 - 2 working days for your ticket to be approved.'),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Go back to event details
                },
                child: const Text('Back to Event'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit payment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Purchase Ticket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Event Title and Fees
            const Text("Event Subtotal", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(widget.event.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
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
                  const Text("Total Payable:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text("RM ${widget.event.fees?.toStringAsFixed(2) ?? '0.00'}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Instructions & QR Code
            const Text("Payment Instructions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Payment Society QR display
            if (widget.event.paymentQrUrl != null && widget.event.paymentQrUrl!.isNotEmpty)...[
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(10),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(15),
                   border: Border.all(color: Colors.grey.shade300),
                   boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                 ),
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(10),
                   child: Image.network(widget.event.paymentQrUrl!, height: 250, fit: BoxFit.contain),
                 ),
               ),
               const SizedBox(height: 20),
            ] else ...[
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                 child: const Text("The organizer has not provided a payment QR code.", style: TextStyle(color: Colors.red)),
               ),
               const SizedBox(height: 20),
            ],

            // Step-by-step instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("1. Scan or save the official Society Payment QR Code above.", style: TextStyle(fontSize: 14, height: 1.5)),
                  SizedBox(height: 8),
                  Text("2. Transfer the exact 'Total Payable' amount using your preferred banking app or e-wallet (e.g., TNG, MAE).", style: TextStyle(fontSize: 14, height: 1.5)),
                  SizedBox(height: 8),
                  Text("3. Capture a clear screenshot of the successful transaction receipt displaying the reference number.", style: TextStyle(fontSize: 14, height: 1.5)),
                  SizedBox(height: 8),
                  Text("4. Upload the screenshot below and submit. Please allow 1 to 2 working days for the society to verify and approve your ticket.", style: TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Proof Upload Section
            const Text("Upload Payment Proof", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF6A1B9A)),
                          title: const Text('Choose from Gallery'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _pickProofImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                ),
                child: _proofImage != null
                    ? Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_proofImage!, width: double.infinity, height: 160, fit: BoxFit.contain),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => setState(() => _proofImage = null),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, size: 40, color: Color(0xFF6A1B9A)),
                          SizedBox(height: 10),
                          Text("Tap to upload screenshot (JPG/PNG)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                          Text("Required *", style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),

            // Submit Button
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
                  onPressed: _submitPayment,
                  child: const Text('SUBMIT PAYMENT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
