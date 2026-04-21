import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/payment_model.dart';
import '../../services/payment_service.dart';

class PaymentReceiptScreen extends StatefulWidget {
  final int ticketId;
  final String eventTitle;

  const PaymentReceiptScreen({
    super.key,
    required this.ticketId,
    required this.eventTitle,
  });

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  final PaymentService _paymentService = PaymentService();
  PaymentModel? _payment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayment();
  }

  Future<void> _loadPayment() async {
    final payments = await _paymentService.getPaymentsForTicket(widget.ticketId);
    if (mounted) {
      setState(() {
        // Take the most recent payment for this ticket
        _payment = payments.isNotEmpty ? payments.first : null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Payment Receipt',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A1B9A)))
          : _payment == null
              ? _buildNoPaymentFound()
              : _buildReceipt(_payment!),
    );
  }

  Widget _buildNoPaymentFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No payment record found\nfor this ticket.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildReceipt(PaymentModel payment) {
    final status = payment.status; // pending / approved / rejected

    // ── Status config ────────────────────────────────────────────
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusMessage = 'Your payment of RM ${payment.amount.toStringAsFixed(2)} is successful.';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top_rounded;
        statusMessage = 'Your payment of RM ${payment.amount.toStringAsFixed(2)} is pending approval.';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusMessage = 'Your payment of RM ${payment.amount.toStringAsFixed(2)} has been rejected.';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        statusMessage = 'Your payment of RM ${payment.amount.toStringAsFixed(2)} is cancelled.';
    }

    final formattedDate = payment.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(payment.createdAt!.toLocal())
        : 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Payment Details Card ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event title
                const Text('Event', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  widget.eventTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const Divider(height: 28),

                // Payment date
                _detailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Payment Date',
                  value: formattedDate,
                ),
                const SizedBox(height: 12),

                // Amount
                _detailRow(
                  icon: Icons.payments_outlined,
                  label: 'Amount',
                  value: 'RM ${payment.amount.toStringAsFixed(2)}',
                  valueStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
                const SizedBox(height: 12),

                // Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    const Text(
                      'Status',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        status[0].toUpperCase() + status.substring(1),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                // Rejection note (if any)
                if (status == 'rejected' &&
                    payment.adminNote != null &&
                    payment.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rejection Reason',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.adminNote!,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Payment Proof Image ───────────────────────────────
          const Text(
            'Payment Proof',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                payment.proofUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            color: const Color(0xFF6A1B9A),
                          ),
                        ),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  color: Colors.grey[100],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Status Banner ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusMessage,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}
