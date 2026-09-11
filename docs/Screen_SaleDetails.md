# Screen: Sale Details

## Purpose
The **Sale Details Screen** shows comprehensive data for a completed sale.

## Widgets

- **Bill Info**: Number, Date, Payment Method.
- **Customer Info**: Name, Phone, Balance (if linked to a registered customer).
- **Items Table**: List of sold books, quantities, and prices.
- **Financials**: Subtotal, Discount, and Total.
- **Actions**: Print, Share, Delete.

## Interactions

- **Print / Share**: Output the receipt.
- **Delete**:
  - Reverts the sale (restocking items, updating customer balance).
  - Checks for "Sales Returns" dependencies before allowing deletion.

## Screenshots
![SCREENSHOT: Sale details showing bill info and items]()
