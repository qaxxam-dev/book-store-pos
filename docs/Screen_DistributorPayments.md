# Screen: Distributor Payments

## Section 1: Payment History
**Screen**: `DistributorPaymentHistoryScreen`
**Purpose**: View log of payments made to the distributor, with full edit and delete management.
- **Header**: Live Current Outstanding Balance card that updates reactively.
- **List**: Cards with Amount, Date & Time, Mode, Notes.
- **Interactions**:
  - **3-Dot Menu**: Directly access "Edit" and "Delete" for any payment.
  - **Card Tap**: Opens action bottom sheet with "Edit Payment" and "Delete Payment".
  - **Edit Payment**: Opens `AddDistributorPaymentScreen` in edit mode with pre-populated values.
  - **Delete Payment**: Shows confirmation dialog detailing the payment amount and the balance restoration impact before deleting.

## Section 2: Add / Edit Payment
**Screen**: `AddDistributorPaymentScreen`
**Purpose**: Record a payment made to reduce debt or edit an existing payment.
**Widgets**:
- **Current Balance**: Display of outstanding debt.
- **Amount**: Payment value to record or update.
- **Payment Mode**: Method of payment (`Cash`, `Card`, `UPI`, `Bank Transfer`).
- **Date & Time Picker**: Customizable payment timestamp with date and time picker.
- **Notes**: Optional remarks.

## Interactions
- **Save / Update**: Updates distributor balance (calculating delta if editing) and records/updates transaction in database.

## Screenshots
![SCREENSHOT: Distributor payment screens]()
