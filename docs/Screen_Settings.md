# Screen: Settings Screen

## Purpose
The **Settings Screen** allows users to configure various aspects of the application, including shop details, receipt customization, hardware connections (printers), and data management (backup/restore/import).

## Widgets

### Shop Details
Form fields to edit shop information. In **Demo Mode**, these are read-only.
- **Shop Name**: Name of the business.
- **Email**: Contact email.
- **Phone Number**: Contact phone.
- **Address**: Physical location.

### Receipt Settings
- **Thank You Message**: Custom footer text for receipts.

### AI Integration
- **Gemini API Key**: Input for the AI API key used for features like book scanning. This remains editable even in Demo Mode.

### Printer Settings
- **Printer Configuration**: A list tile that navigates to the `PrinterConfigScreen`.
- **Print Method**: A dropdown to select between `Save as PDF` (system default) and `Thermal Printer` (direct bluetooth/network).

### Feedback Settings
- **Feedback Type**: Dropdown to select interaction feedback (Vibrate, Beep, or None).

### Import / Export
- **Restore Data**: Restore database from a backup file (Disabled in Demo).
- **Import Books from Excel**: Navigates to `ExcelImportScreen` (Disabled in Demo).
- **Export Data to Excel**: Exports current data to an Excel file.
- **Backup Data**: Creates a full backup of the system (Disabled in Demo).

### Logout
- **Logout Button**: Ends the current session and returns to login.

## Interactions

1.  **Modify Details**: Edit text fields. Changes are staged until saved.
2.  **Save Settings**: Tap **Save Settings** button.
    - Persists changes to local storage or API.
    - Shows success/error snackbar.
3.  **Navigate to Sub-screens**:
    - Tap **Printer Configuration** -> Opens Printer Config.
    - Tap **Import Books** -> Opens Excel Import.
4.  **Data Actions**:
    - Tap **Export** -> Generates Excel file and opens share dialog.
    - Tap **Backup** -> Generates backup file and opens share dialog.
    - Tap **Restore** -> Prompts for file selection and confirmation, then replaces data.
5.  **Logout**: Tap **Logout**, confirm dialog -> Redirects to Login.

## Screenshots
![SCREENSHOT: Settings screen with shop details and printer options]()
