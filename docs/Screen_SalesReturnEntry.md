# Screen: Sales Return Entry

## Purpose
The **Sales Return Entry** flow handles customer refunds. It links returns to specific sales to ensure accurate pricing and inventory management.

## Step 1: Find Sale
**Screen**: `SalesReturnEntryScreen`
- **Search Book**: Find the product being returned.
- **Select Sale**: List shows all sales containing that book (with Customer Name/Guest info).
- **Tap**: Select the specific sale to return against.

## Step 2: Confirm Return
**Screen**: `SalesReturnEntryDetailsScreen`
- **Customer Info**: Shows who bought the items.
- **Items List**:
  - **Return Qty**: Input quantity to restock/refund.
  - Validates against original sold quantity.
- **Summary**: Total Refund calculation (accounting for original discounts).
- **Confirm**:
  - Restocks items (Increments stock).
  - Deducts from customer balance (if Credit) or records refund.

## Interactions

1.  **Search & Select**: Locate the original transaction.
2.  **Input Return Qty**: Define what is coming back.
3.  **Process**: Tap **Confirm Return**.
    - Success dialog enables Printing or WhatsApp sharing of the Credit Note/Refund Receipt.

## Screenshots
![SCREENSHOT: Sales return entry flow]()
