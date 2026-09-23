# Screen: Customer Payments

## Section 1: Payment History
**Screen**: `CustomerPaymentHistoryScreen`
**Purpose**: View ledger of payments received from the customer, with full edit and delete management.
- **Header**: Live Current Outstanding Balance card that updates reactively.
- **List**: Cards showing Amount, Date & Time, Payment Mode, and Notes.
- **Interactions**:
  - **3-Dot Menu**: Directly access "Edit" and "Delete" for any payment.
  - **Card Tap**: Opens action bottom sheet with "Edit Payment" and "Delete Payment".
  - **Edit Payment**: Opens `AddCustomerPaymentScreen` in edit mode with pre-populated values.
  - **Delete Payment**: Shows confirmation dialog detailing the payment amount and the balance restoration impact before deleting.

## Section 2: Add / Edit Payment
**Screen**: `AddCustomerPaymentScreen`
**Purpose**: Record a new payment or edit an existing payment.
**Widgets**:
- **Current Balance**: Prominent display of what is owed/owned.
- **Amount Input**: Value to record or update.
- **Payment Mode**: Dropdown (`Cash`, `Card`, `UPI`, `Bank Transfer`).
- **Date & Time Picker**: Customizable payment timestamp with date and time picker.
- **Notes**: Optional remarks.

## Interactions
- **Save / Update Payment**: Updates customer balance (calculating delta if editing) and records/updates transaction in database.

## Screenshots
![SCREENSHOT: Customer payment history and add payment form]()
