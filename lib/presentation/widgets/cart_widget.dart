import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../providers/cart_provider.dart';

class CartWidget extends StatelessWidget {
  const CartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();

    return Column(
      children: [
        Expanded(
          child: cartProvider.items.isEmpty
              ? const Center(child: Text('Cart is empty'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cartProvider.items.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = cartProvider.items[index];
                    return _CartItemTile(
                      item: item,
                      cartProvider: cartProvider,
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.neutral100,
            border: const Border(top: BorderSide(color: AppTheme.neutral300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Items: ${cartProvider.items.length}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                'Total: ₹${cartProvider.totalAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartItemTile extends StatefulWidget {
  final dynamic item;
  final CartProvider cartProvider;

  const _CartItemTile({
    required this.item,
    required this.cartProvider,
  });

  @override
  State<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<_CartItemTile> {
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _qtyController =
        TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void didUpdateWidget(covariant _CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.quantity.toString() != _qtyController.text) {
      _qtyController.text = widget.item.quantity.toString();
      _qtyController.selection = TextSelection.fromPosition(
          TextPosition(offset: _qtyController.text.length));
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _handleManualInput(String value) {
    final int? newQty = int.tryParse(value);
    if (newQty == null || newQty <= 0) {
      widget.cartProvider.updateQuantity(widget.item.book, 1);
      _qtyController.text = "1";
    } else {
      widget.cartProvider.updateQuantity(widget.item.book, newQty);
    }
  }

  /// Helper widget for the +/- buttons
  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color ?? Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.item.book.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${widget.item.book.price}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // --- New Stepper Design ---
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStepperButton(
                    icon: Icons.remove,
                    onPressed: () {
                      if (widget.item.quantity > 1) {
                        widget.cartProvider.updateQuantity(
                            widget.item.book, widget.item.quantity - 1);
                      } else {
                        widget.cartProvider.removeFromCart(widget.item.book);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 50,
                    height: 32, // Keeps height consistent with your buttons
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors
                              .grey.shade300), // Adds a subtle defined border
                    ),
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical
                          .center, // Forces text to center vertically
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      // We strictly remove all default borders so the Container handles the look
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onSubmitted: _handleManualInput,
                      onTapOutside: (_) {
                        _handleManualInput(_qtyController.text);
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStepperButton(
                    icon: Icons.add,
                    color: Theme.of(context)
                        .primaryColor
                        .withOpacity(0.1), // Optional: tint the add button
                    onPressed: () {
                      widget.cartProvider.updateQuantity(
                          widget.item.book, widget.item.quantity + 1);
                    },
                  ),
                ],
              ),
              // ---------------------------

              const Spacer(),
              Text(
                '₹${widget.item.total.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon:
                    const Icon(Icons.delete_outline, color: AppTheme.errorText),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  widget.cartProvider.removeFromCart(widget.item.book);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
