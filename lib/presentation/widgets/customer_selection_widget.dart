import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';
import '../../data/models/customer.dart';
import '../providers/customer_provider.dart';
import '../screens/customer/add_customer_screen.dart';

class CustomerSelectionWidget extends StatefulWidget {
  final Function(Customer) onCustomerSelected;
  final Function(String) onChanged;
  final TextEditingController? controller;

  const CustomerSelectionWidget({
    super.key,
    required this.onCustomerSelected,
    required this.onChanged,
    this.controller,
  });

  @override
  State<CustomerSelectionWidget> createState() =>
      _CustomerSelectionWidgetState();
}

class _CustomerSelectionWidgetState extends State<CustomerSelectionWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void didUpdateWidget(CustomerSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller &&
        widget.controller != null) {
      _controller = widget.controller!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<Customer>(
      controller: _controller,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: 'Select Customer / Guest Phone',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddCustomerScreen(),
                  ),
                );
              },
            ),
          ),
        );
      },
      suggestionsCallback: (pattern) async {
        final provider = context.read<CustomerProvider>();
        await provider.searchCustomers(pattern);
        return provider.customers;
      },
      itemBuilder: (context, customer) {
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(customer.name),
          subtitle: Text(customer.phone),
        );
      },
      onSelected: (customer) {
        _controller.text = customer.name;
        widget.onCustomerSelected(customer);
        widget.onChanged(customer.name); // Or maybe phone?
      },
      emptyBuilder: (context) {
        return const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('No customer found. Type phone for Guest.'),
        );
      },
    );
  }
}
