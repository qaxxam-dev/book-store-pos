# Screen: Purchase Details

## Purpose
The **Purchase Details Screen** displays full information about a specific purchase transaction.

## Widgets

- **Header Info**: Bill Number, Date, Payment Method.
- **Distributor Info**: Name, Phone, and Current Balance.
- **Items Table**: List of books purchased with Quantity, Cost, and Total.
- **Financials**: Subtotal, Discount, and Final Total.
- **Action Buttons** (AppBar):
  - **Print**: Print thermal receipt.
  - **Share**: Share via WhatsApp.
  - **Delete**: Revert transaction (updates stock and balance).

## Interactions

- **Print**: Triggers the print job to the default printer.
- **Share**: Generates a text summary and opens WhatsApp.
- **Delete**:
  - Checks if any returns exist for this purchase.
  - **If Returns Exist**: Blocks delete and offers to open the Return record.
  - **If Safe**: Prompts for confirmation and deletes record.

## Screenshots
![SCREENSHOT: Purchase details view with distributor info and items table]()
