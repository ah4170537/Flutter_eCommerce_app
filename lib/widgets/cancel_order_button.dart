import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/order_service.dart';

/// Shows a "Cancel Order" button with a live countdown of the remaining
/// cancellation window. The button is always visible but only enabled
/// while time remains.
///
/// IMPORTANT: the countdown shown here is for UX only. The actual
/// enforcement of the 30-minute window happens server-side via Firestore
/// Security Rules, which compare Firebase's server clock against the
/// order's `createdAt`. If the device clock is off and this widget
/// thinks time remains when it actually doesn't (or vice versa), the
/// Firestore write will be rejected/accepted based on the real server
/// time — this widget just reflects that outcome to the user.
class CancelOrderButton extends StatefulWidget {
  final String userId;
  final String orderId;
  final Timestamp createdAt;
  final String currentStatus;
  final VoidCallback? onCancelled;

  const CancelOrderButton({
    super.key,
    required this.userId,
    required this.orderId,
    required this.createdAt,
    required this.currentStatus,
    this.onCancelled,
  });

  @override
  State<CancelOrderButton> createState() => _CancelOrderButtonState();
}

class _CancelOrderButtonState extends State<CancelOrderButton> {
  static const Duration _cancelWindow = Duration(minutes: 30);

  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
  }

  void _updateRemaining() {
    final DateTime createdDateTime = widget.createdAt.toDate();
    final Duration elapsed = DateTime.now().difference(createdDateTime);
    final Duration remaining = _cancelWindow - elapsed;

    if (!mounted) return;

    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
    });

    if (_remaining == Duration.zero) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _confirmAndCancel() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text(
          'Are you sure you want to cancel this order? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep Order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isCancelling = true);

    try {
      await OrderService.instance.cancelOrder(
        userId: widget.userId,
        orderId: widget.orderId,
      );

      widget.onCancelled?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully.')),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final String message = e.code == 'permission-denied'
            ? 'The 30-minute cancellation window has expired.'
            : 'Failed to cancel order. Please try again.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Already cancelled — nothing to show.
    if (widget.currentStatus == 'cancelled') {
      return const SizedBox.shrink();
    }

    final bool isWithinWindow = _remaining > Duration.zero;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: (isWithinWindow && !_isCancelling) ? _confirmAndCancel : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: isWithinWindow ? Colors.red : Colors.grey,
          side: BorderSide(
            color: isWithinWindow ? Colors.red : Colors.grey.shade300,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isCancelling
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                isWithinWindow
                    ? 'Cancel Order (${_formatDuration(_remaining)} left)'
                    : 'Cancellation window expired',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}