# Screen: Splash Screen

## Purpose
The **Splash Screen** is the first screen visible when the application launches. It serves as a branding introduction and performs a brief loading pause before navigating to the authentication flow.

## Widgets

- **Launcher Icon**: Displays the application's logo in the center of the screen.
- **App Name**: Displays "Book Shop Pos" in bold, large text below the icon.
- **Footer Text**: Displays "Powered By ALQA Tech" at the bottom of the visible content.

## Interactions

- **Auto-Navigation**: The screen automatically waits for 2 seconds after initialization and then navigates to the `AuthWrapper` (which determines if the user should go to Login or Home) using `Navigator.pushReplacement`.

## Screenshots
![SCREENSHOT: Splash screen with logo and app name]()
