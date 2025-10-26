# User Information in Scheduling Feature

## Date: October 19, 2025

## Overview
Added user information fields (name and email) to the scheduling dialog with Firestore integration for data persistence.

## Features Implemented:

### 1. **User Information Form**
- ✅ Two required text fields: Name and Email
- ✅ Form validation for both fields
- ✅ Email format validation with regex
- ✅ Visual indication that fields are required
- ✅ Professional UI with icons and proper styling

### 2. **Firestore Integration**
- ✅ Automatic data loading on dialog open
- ✅ Retrieves user data from `users` collection indexed by UUID
- ✅ Falls back to Firebase Auth email if no Firestore document exists
- ✅ Auto-saves updated name/email to Firestore when scheduling
- ✅ Loading indicator while fetching user data

### 3. **Validation Rules**

#### **Name Field:**
- Required field
- Cannot be empty or whitespace only
- Error message: "Name is required"

#### **Email Field:**
- Required field
- Must be valid email format
- Regex validation: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
- Error messages:
  - "Email is required" (if empty)
  - "Please enter a valid email address" (if invalid format)

### 4. **User Experience Flow**

1. **Dialog Opens:**
   - Shows loading indicator
   - Fetches user data from Firestore (`users/{uid}`)
   - Pre-fills name and email if exists
   - Falls back to Firebase Auth email

2. **User Fills Form:**
   - Name and email fields are editable
   - Real-time validation on submit
   - Clear error messages displayed below fields

3. **User Clicks Schedule:**
   - Form validation runs
   - If validation fails, shows error messages
   - If validation passes:
     - Saves name/email to Firestore
     - Shows confirmation dialog with email
     - Closes scheduling dialog

### 5. **Firestore Data Structure**

```javascript
users/{userId} {
  name: string,          // User's full name
  email: string,         // User's email address
  updatedAt: timestamp   // Server timestamp of last update
}
```

**Note:** Uses `SetOptions(merge: true)` to avoid overwriting other user data fields.

## UI Layout (Top to Bottom):

1. Cat photo + Schedule Appointment header
2. **Divider**
3. **"Your Information" section** (NEW)
   - Section title
   - "Required to schedule an appointment" subtitle
   - Name text field with person icon
   - Email text field with email icon
4. **Divider**
5. Date picker
6. Available time slots list
7. Cancel / Schedule buttons

## Code Changes:

### **New Imports:**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
```

### **New State Variables:**
```dart
final TextEditingController _nameController = TextEditingController();
final TextEditingController _emailController = TextEditingController();
final _formKey = GlobalKey<FormState>();
bool _isLoadingUserData = true;
String? _userId;
```

### **New Methods:**
- `_loadUserData()` - Fetches user data from Firestore on init
- `_saveUserData()` - Saves name/email to Firestore
- `_isValidEmail(String)` - Validates email format with regex

### **Modified Methods:**
- `initState()` - Calls `_loadUserData()`
- `dispose()` - Disposes text controllers
- `build()` - Wrapped in Form widget, shows loading state

## Validation Behavior:

### **Visual Feedback:**
- ✅ Red error text appears below invalid fields
- ✅ Border color changes to red when error
- ✅ Border color is primary color when focused
- ✅ Schedule button is disabled if no time slot selected
- ✅ Validation runs on Schedule button press

### **Error Prevention:**
- User cannot submit without:
  1. Valid name (non-empty)
  2. Valid email (correct format)
  3. Selected time slot
  4. Selected date

## Firebase Auth Integration:

### **Logged In User:**
1. Gets UUID from `FirebaseAuth.instance.currentUser.uid`
2. Queries Firestore: `users/{uid}`
3. Pre-fills name and email
4. Saves changes back to same document

### **Not Logged In:**
- Still shows form (empty)
- Data not saved to Firestore (no UUID)
- Allows scheduling as guest with manual entry

## Example User Flow:

```
User taps Schedule icon on cat detail
↓
Dialog opens with loading indicator
↓
System fetches user data from Firestore
↓
Name: "John Doe" (pre-filled)
Email: "john@example.com" (pre-filled)
↓
User selects date: "Saturday, October 25, 2025"
User selects time: "10:00 AM - 10:30 AM"
↓
User taps "Schedule" button
↓
Form validates (✓ name valid, ✓ email valid)
↓
System saves name/email to Firestore
↓
Confirmation dialog shows:
"Your appointment to meet Fluffy on October 25 at 10:00 AM 
has been requested.

Confirmation will be sent to john@example.com."
↓
User taps "OK"
↓
Both dialogs close
```

## Next Steps (Future Enhancements):

1. **Phone Number Field** - Optional contact number
2. **Notes Field** - Special requests or questions
3. **SMS Confirmation** - Text message reminders
4. **Calendar Export** - Add to user's calendar
5. **Email Templates** - Automated confirmation emails
6. **Admin Dashboard** - View/manage appointment requests







