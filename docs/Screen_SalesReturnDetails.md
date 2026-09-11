# Screen: Sales Return Details

## Purpose
The **Sales Return Details Screen** views a past customer return record.

## Widgets

- **Header**: Link to Original Sale Bill Number.
- **Customer**: Name (or Guest) and Balance.
- **Items Table**: Returned items and refund calculations.
- **Financials**: Total Refund Amount.

## Interactions

- **View Original**: Link back to the Sale Details.
- **Print/Share**: Refund receipt.
- **Delete**:
  - Reverts the return (Decreases stock, Re-bills customer).
  - blocked if dependencies exist (though returns usually are leaves in the dependency tree).

## Screenshots
![SCREENSHOT: Sales return details viewer]()
