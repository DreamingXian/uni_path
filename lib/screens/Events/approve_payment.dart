import 'package:flutter/material.dart';
import '../../services/payment_dashboard_service.dart';

class ApprovePaymentScreen extends StatefulWidget {
  final PaymentDashboardItem item;

  const ApprovePaymentScreen({super.key, required this.item});

  @override
  State<ApprovePaymentScreen> createState() => _ApprovePaymentScreenState();
}

class _ApprovePaymentScreenState extends State<ApprovePaymentScreen> {
  final PaymentDashboardService _service = PaymentDashboardService();
  bool _isProcessing = false;

  // ── REJECT FLOW ─────────────────────────────────────────────────────────────
  Future<void> _showRejectDialog() async {
    final noteController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection. This will be recorded and the applicant will be notified.'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Invalid receipt, incorrect amount...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final reason = noteController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.')),
                );
                return;
              }
              Navigator.pop(ctx); // Close dialog
              await _performAction(isApprove: false, rejectionNote: reason);
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  // ── APPROVE FLOW ─────────────────────────────────────────────────────────────
  Future<void> _showApproveDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Approve Payment'),
          ],
        ),
        content: Text(
          'Approve payment of RM ${widget.item.payment.amount.toStringAsFixed(2)} from ${widget.item.payerName}?\n\nThis will activate their ticket immediately.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performAction(isApprove: true);
    }
  }

  // ── SHARED ACTION ─────────────────────────────────────────────────────────────
  Future<void> _performAction({required bool isApprove, String? rejectionNote}) async {
    setState(() => _isProcessing = true);
    try {
      if (isApprove) {
        await _service.approvePayment(
          widget.item.payment.id!,
          widget.item.ticketId,
        );
      } else {
        await _service.rejectPayment(
          widget.item.payment.id!,
          widget.item.ticketId,
          rejectionNote!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApprove ? 'Payment approved. Ticket is now active!' : 'Payment rejected.'),
            backgroundColor: isApprove ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context); // Back to dashboard, which will refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isPending = item.payment.status == 'pending';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Review Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Event info header ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6A1B9A).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Event', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(item.eventTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Applicant', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(item.payerName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            'RM ${item.payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Payment Proof ──────────────────────────────────────
            const Text('Payment Proof', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.payment.proofUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 150,
                    color: Colors.grey[100],
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 48)),
                  ),
                ),
              ),
            ),

            // ── Rejection note (if already rejected) ──────────────
            if (item.payment.adminNote != null && item.payment.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 20),
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
                    const Text('Rejection Reason', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(item.payment.adminNote!, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 100), // Space for bottom buttons
          ],
        ),
      ),

      // ── Bottom Action Buttons (only show if still pending) ────────
      bottomSheet: isPending
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -3))],
              ),
              child: _isProcessing
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
                  : Row(
                      children: [
                        // Reject Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showRejectDialog,
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                            label: const Text('Reject', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Approve Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showApproveDialog,
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                            label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
            )
          : null,
    );
  }
}
