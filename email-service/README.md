# Feline Finder Email Service Setup Guide

## Overview
This guide will help you set up a web portal email service using Postmark for your Feline Finder app. The service runs as a separate backend that your Flutter app can call to send emails.

## Prerequisites
- Node.js (version 16 or higher)
- Postmark account
- Domain name (optional but recommended)

## Step 1: Postmark Account Setup

### 1.1 Create Postmark Account
1. Go to [https://postmarkapp.com/](https://postmarkapp.com/)
2. Sign up for a free account
3. Verify your email address

### 1.2 Create a Server
1. In Postmark dashboard, go to "Servers"
2. Click "Create Server"
3. Choose "Web API" as server type
4. Enter server name: "Feline Finder Email Service"
5. Click "Create Server"

### 1.3 Get Server Token
1. After creating the server, you'll see the "Server Token"
2. Copy this token - you'll need it for configuration
3. Example: `12345678-1234-1234-1234-123456789012`

### 1.4 Verify Sender Email
1. Go to "Sender Signatures" in your server
2. Click "Add Sender Signature"
3. Enter your email address (e.g., `noreply@yourdomain.com`)
4. Check your email and click the verification link

## Step 2: Deploy Email Service

### 2.1 Local Development Setup
1. Navigate to the email-service directory:
   ```bash
   cd email-service
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Copy environment file:
   ```bash
   cp env.example .env
   ```

4. Edit `.env` file with your Postmark credentials:
   ```
   PORT=3000
   NODE_ENV=development
   POSTMARK_SERVER_TOKEN=your_actual_server_token_here
   POSTMARK_FROM_EMAIL=your_verified_email@yourdomain.com
   ```

5. Start the service:
   ```bash
   npm run dev
   ```

### 2.2 Production Deployment Options

#### Option A: Heroku (Recommended for beginners)
1. Install Heroku CLI
2. Create Heroku app:
   ```bash
   heroku create feline-finder-email-service
   ```
3. Set environment variables:
   ```bash
   heroku config:set POSTMARK_SERVER_TOKEN=your_token
   heroku config:set POSTMARK_FROM_EMAIL=your_email
   heroku config:set NODE_ENV=production
   ```
4. Deploy:
   ```bash
   git add .
   git commit -m "Initial email service"
   git push heroku main
   ```

#### Option B: Railway
1. Connect your GitHub repository to Railway
2. Set environment variables in Railway dashboard
3. Deploy automatically

#### Option C: DigitalOcean App Platform
1. Create new app in DigitalOcean
2. Connect GitHub repository
3. Set environment variables
4. Deploy

#### Option D: AWS EC2
1. Launch EC2 instance
2. Install Node.js and PM2
3. Clone repository and install dependencies
4. Set up PM2 for process management
5. Configure reverse proxy with Nginx

## Step 3: Test the Email Service

### 3.1 Health Check
Test if the service is running:
```bash
curl https://your-service-url.com/health
```

Expected response:
```json
{
  "status": "OK",
  "service": "Feline Finder Email Service",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

### 3.2 Test Email Sending
Send a test email:
```bash
curl -X POST https://your-service-url.com/api/send-email \
  -H "Content-Type: application/json" \
  -d '{
    "to": "test@example.com",
    "subject": "Test Email",
    "body": "This is a test email from Feline Finder!"
  }'
```

### 3.3 Test Cat Inquiry
Send a cat inquiry email:
```bash
curl -X POST https://your-service-url.com/api/send-cat-inquiry \
  -H "Content-Type: application/json" \
  -d '{
    "shelterEmail": "shelter@example.com",
    "catName": "Whiskers",
    "userName": "John Doe",
    "userEmail": "john@example.com",
    "userPhone": "555-1234",
    "message": "I am interested in adopting Whiskers!"
  }'
```

## Step 4: Update Flutter App

### 4.1 Add HTTP Dependency
Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
```

### 4.2 Update Configuration
Add your email service URL to `lib/config.dart`:
```dart
class AppConfig {
  // ... existing config ...
  
  // Email Service Configuration
  static const String emailServiceUrl = 'https://your-service-url.com';
}
```

### 4.3 Create Email Service Class
Create `lib/services/email_service.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class EmailService {
  static const String _baseUrl = AppConfig.emailServiceUrl;
  
  static Future<bool> sendCatInquiry({
    required String shelterEmail,
    required String catName,
    required String userEmail,
    required String userName,
    String? userPhone,
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/send-cat-inquiry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'shelterEmail': shelterEmail,
          'catName': catName,
          'userName': userName,
          'userEmail': userEmail,
          'userPhone': userPhone,
          'message': message,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }
}
```

### 4.4 Update Toolbar
Update the email function in `lib/widgets/toolbar.dart` to use the new service.

## Step 5: Security Considerations

### 5.1 Rate Limiting
The service includes rate limiting (100 requests per 15 minutes per IP).

### 5.2 Input Validation
All inputs are validated before processing.

### 5.3 Error Handling
Comprehensive error handling with appropriate HTTP status codes.

### 5.4 Environment Variables
Never commit `.env` files to version control.

## Step 6: Monitoring and Maintenance

### 6.1 Logs
Monitor server logs for errors and performance.

### 6.2 Postmark Dashboard
Check Postmark dashboard for:
- Email delivery rates
- Bounce rates
- Spam complaints

### 6.3 Health Monitoring
Set up health checks for your deployed service.

## API Endpoints

### POST /api/send-email
Send a general email.

**Request Body:**
```json
{
  "to": "recipient@example.com",
  "subject": "Email Subject",
  "body": "Email body content",
  "fromName": "Sender Name",
  "fromEmail": "sender@example.com"
}
```

### POST /api/send-cat-inquiry
Send a cat adoption inquiry email.

**Request Body:**
```json
{
  "shelterEmail": "shelter@example.com",
  "catName": "Cat Name",
  "userName": "User Name",
  "userEmail": "user@example.com",
  "userPhone": "555-1234",
  "message": "Custom message"
}
```

### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "OK",
  "service": "Feline Finder Email Service",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

## Troubleshooting

### Common Issues:

1. **"Invalid Server Token"**
   - Verify your Postmark server token is correct
   - Check if the token is properly set in environment variables

2. **"Sender not verified"**
   - Verify your sender email in Postmark dashboard
   - Make sure the email matches POSTMARK_FROM_EMAIL

3. **"Rate limit exceeded"**
   - Check if you're hitting the rate limit
   - Consider increasing the limit if needed

4. **"Email not delivered"**
   - Check Postmark dashboard for delivery status
   - Verify recipient email address is valid

### Debug Mode:
Set `NODE_ENV=development` to get detailed error messages.

## Cost Considerations

### Postmark Pricing:
- **Free Tier**: 100 emails/month
- **Paid Plans**: Starting at $10/month for 10,000 emails

### Hosting Costs:
- **Heroku**: Free tier available, paid plans start at $7/month
- **Railway**: Free tier available, paid plans start at $5/month
- **DigitalOcean**: Starting at $5/month

## Support Resources

- [Postmark Documentation](https://postmarkapp.com/developer)
- [Express.js Documentation](https://expressjs.com/)
- [Heroku Node.js Guide](https://devcenter.heroku.com/articles/getting-started-with-nodejs)
- [Railway Documentation](https://docs.railway.app/)

---

**Note**: This setup provides a secure, scalable email service for your Flutter app. The service handles all email sending logic, keeping your app clean and your credentials secure.
