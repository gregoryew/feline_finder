const express = require('express');
const cors = require('cors');
const postmark = require('postmark');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Postmark client setup
const client = new postmark.ServerClient(process.env.POSTMARK_SERVER_TOKEN);

// Middleware
app.use(cors());
app.use(express.json());

// Rate limiting to prevent abuse
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    service: 'Feline Finder Email Service',
    timestamp: new Date().toISOString()
  });
});

// Email sending endpoint
app.post('/api/send-email', async (req, res) => {
  try {
    const { to, subject, body, fromName, fromEmail, catName, userName, userEmail, userPhone, message } = req.body;

    // Validation
    if (!to || !subject || !body) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: to, subject, body' 
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(to)) {
      return res.status(400).json({ 
        success: false, 
        error: 'Invalid email address format' 
      });
    }

    // Create email template for cat inquiries
    let emailBody = body;
    if (catName && userName && userEmail) {
      emailBody = createCatInquiryTemplate({
        catName,
        userName,
        userEmail,
        userPhone,
        message: message || 'I am interested in adopting this cat from Feline Finder app.'
      });
    }

    // Send email via Postmark
    const response = await client.sendEmail({
      From: `${fromName || 'Feline Finder'} <${fromEmail || process.env.POSTMARK_FROM_EMAIL}>`,
      To: to,
      Subject: subject,
      HtmlBody: emailBody,
      TextBody: stripHtml(emailBody),
      MessageStream: 'outbound'
    });

    console.log('Email sent successfully:', response.MessageID);

    res.json({
      success: true,
      messageId: response.MessageID,
      message: 'Email sent successfully'
    });

  } catch (error) {
    console.error('Error sending email:', error);
    
    // Handle specific Postmark errors
    if (error.code === 406) {
      return res.status(400).json({
        success: false,
        error: 'Invalid email address or sender not verified'
      });
    }
    
    if (error.code === 422) {
      return res.status(400).json({
        success: false,
        error: 'Email content validation failed'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to send email',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Appointment confirmation endpoint
app.post('/api/send-appointment-confirmation', async (req, res) => {
  try {
    const { 
      organizationEmail, 
      organizationName,
      userName, 
      userEmail, 
      userPhone,
      catName,
      appointmentDate,
      timeSlot,
      catImageUrl 
    } = req.body;

    // Validation
    if (!organizationEmail || !userName || !userEmail || !catName || !appointmentDate || !timeSlot) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required fields' 
      });
    }

    const subject = `New Appointment Request - ${catName}`;
    const emailBody = createAppointmentEmailTemplate({
      organizationName,
      userName,
      userEmail,
      userPhone,
      catName,
      appointmentDate,
      timeSlot,
      catImageUrl
    });

    // Send email via Postmark
    const response = await client.sendEmail({
      From: `Feline Finder <${process.env.POSTMARK_FROM_EMAIL}>`,
      To: organizationEmail,
      Subject: subject,
      HtmlBody: emailBody,
      TextBody: stripHtml(emailBody),
      MessageStream: 'outbound'
    });

    console.log('Appointment email sent successfully:', response.MessageID);

    res.json({
      success: true,
      messageId: response.MessageID,
      message: 'Appointment confirmation sent successfully'
    });

  } catch (error) {
    console.error('Error sending appointment email:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to send appointment email',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Cat inquiry endpoint (simplified)
app.post('/api/send-cat-inquiry', async (req, res) => {
  try {
    const { shelterEmail, catName, userName, userEmail, userPhone, message } = req.body;

    // Validation
    if (!shelterEmail || !catName || !userName || !userEmail) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: shelterEmail, catName, userName, userEmail' 
      });
    }

    const subject = `Inquiry about ${catName} from Feline Finder`;
    const emailBody = createCatInquiryTemplate({
      catName,
      userName,
      userEmail,
      userPhone,
      message: message || 'I am interested in adopting this cat from Feline Finder app.'
    });

    // Send email via Postmark
    const response = await client.sendEmail({
      From: `Feline Finder <${process.env.POSTMARK_FROM_EMAIL}>`,
      To: shelterEmail,
      Subject: subject,
      HtmlBody: emailBody,
      TextBody: stripHtml(emailBody),
      MessageStream: 'outbound'
    });

    console.log('Cat inquiry sent successfully:', response.MessageID);

    res.json({
      success: true,
      messageId: response.MessageID,
      message: 'Cat inquiry sent successfully'
    });

  } catch (error) {
    console.error('Error sending cat inquiry:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to send cat inquiry',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// Helper function to create cat inquiry email template
function createCatInquiryTemplate({ catName, userName, userEmail, userPhone, message }) {
  const phoneText = userPhone ? `<p><strong>Phone:</strong> ${userPhone}</p>` : '';
  
  return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Feline Finder Inquiry</title>
        <style>
            body { 
                font-family: Arial, sans-serif; 
                line-height: 1.6; 
                color: #333; 
                max-width: 600px; 
                margin: 0 auto; 
                padding: 20px;
            }
            .header { 
                background: linear-gradient(135deg, #4CAF50, #45a049); 
                color: white; 
                padding: 30px; 
                text-align: center; 
                border-radius: 10px 10px 0 0;
            }
            .content { 
                padding: 30px; 
                background-color: #f9f9f9; 
                border-radius: 0 0 10px 10px;
            }
            .cat-info {
                background-color: #e8f5e8;
                padding: 20px;
                border-radius: 8px;
                margin: 20px 0;
                border-left: 4px solid #4CAF50;
            }
            .contact-info {
                background-color: #f0f8ff;
                padding: 20px;
                border-radius: 8px;
                margin: 20px 0;
                border-left: 4px solid #2196F3;
            }
            .footer { 
                padding: 20px; 
                text-align: center; 
                font-size: 12px; 
                color: #666; 
                margin-top: 20px;
            }
            h1 { margin: 0; }
            h2 { color: #4CAF50; }
            .emoji { font-size: 1.2em; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1><span class="emoji">🐱</span> Feline Finder</h1>
            <p>Cat Adoption Inquiry</p>
        </div>
        
        <div class="content">
            <h2>Hello!</h2>
            
            <p>I am interested in adopting <strong>${catName}</strong> that I found through the Feline Finder app.</p>
            
            <div class="cat-info">
                <h3><span class="emoji">🐾</span> Cat Information</h3>
                <p><strong>Cat Name:</strong> ${catName}</p>
                <p><strong>Found via:</strong> Feline Finder Mobile App</p>
            </div>
            
            <div class="contact-info">
                <h3><span class="emoji">📞</span> My Contact Information</h3>
                <p><strong>Name:</strong> ${userName}</p>
                <p><strong>Email:</strong> ${userEmail}</p>
                ${phoneText}
            </div>
            
            <h3><span class="emoji">💬</span> Message</h3>
            <p>${message}</p>
            
            <p>Please let me know if <strong>${catName}</strong> is still available and what the next steps would be for adoption.</p>
            
            <p>Thank you for your time!</p>
            
            <p>Best regards,<br>
            <strong>${userName}</strong></p>
        </div>
        
        <div class="footer">
            <p>This email was sent through the Feline Finder app</p>
            <p>© ${new Date().getFullYear()} Feline Finder - Connecting cats with loving homes</p>
        </div>
    </body>
    </html>
  `;
}

// Helper function to create appointment email template
function createAppointmentEmailTemplate({ 
  organizationName, 
  userName, 
  userEmail, 
  userPhone, 
  catName, 
  appointmentDate, 
  timeSlot,
  catImageUrl 
}) {
  const phoneText = userPhone ? `<p><strong>Phone:</strong> ${userPhone}</p>` : '';
  
  return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>New Appointment - Feline Finder</title>
        <style>
            body { 
                font-family: Arial, sans-serif; 
                line-height: 1.6; 
                color: #333; 
                max-width: 600px; 
                margin: 0 auto; 
                padding: 20px;
            }
            .header { 
                background: linear-gradient(135deg, #2196F3, #21CBF3); 
                color: white; 
                padding: 30px; 
                text-align: center; 
                border-radius: 10px 10px 0 0;
            }
            .content { 
                padding: 30px; 
                background-color: #f9f9f9; 
                border-radius: 0 0 10px 10px;
            }
            .appointment-info {
                background-color: #e3f2fd;
                padding: 20px;
                border-radius: 8px;
                margin: 20px 0;
                border-left: 4px solid #2196F3;
            }
            .visitor-info {
                background-color: #e8f5e9;
                padding: 20px;
                border-radius: 8px;
                margin: 20px 0;
                border-left: 4px solid #4CAF50;
            }
            .footer { 
                padding: 20px; 
                text-align: center; 
                font-size: 12px; 
                color: #666; 
                margin-top: 20px;
            }
            h1 { margin: 0; }
            h2 { color: #2196F3; }
            .emoji { font-size: 1.2em; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1><span class="emoji">🐱</span> New Appointment Request</h1>
            <p>Feline Finder</p>
        </div>
        
        <div class="content">
            <h2>Hello ${organizationName}!</h2>
            
            <p>You have received a new appointment request for <strong>${catName}</strong>.</p>
            
            <div class="appointment-info">
                <h3><span class="emoji">📅</span> Appointment Details</h3>
                <p><strong>Date:</strong> ${appointmentDate}</p>
                <p><strong>Time:</strong> ${timeSlot}</p>
                <p><strong>Cat:</strong> ${catName}</p>
            </div>
            
            <div class="visitor-info">
                <h3><span class="emoji">👤</span> Visitor Information</h3>
                <p><strong>Name:</strong> ${userName}</p>
                <p><strong>Email:</strong> ${userEmail}</p>
                ${phoneText}
            </div>
            
            <p>Please review this request and contact the visitor to confirm availability.</p>
            
            <p>Thank you for being a partner with Feline Finder!</p>
        </div>
        
        <div class="footer">
            <p>This email was sent through the Feline Finder app</p>
            <p>© ${new Date().getFullYear()} Feline Finder - Connecting cats with loving homes</p>
        </div>
    </body>
    </html>
  `;
}

// Helper function to strip HTML tags for text version
function stripHtml(html) {
  return html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🐱 Feline Finder Email Service running on port ${PORT}`);
  console.log(`📧 Postmark configured with server token: ${process.env.POSTMARK_SERVER_TOKEN ? 'Yes' : 'No'}`);
  console.log(`📮 From email: ${process.env.POSTMARK_FROM_EMAIL || 'Not configured'}`);
});

module.exports = app;
