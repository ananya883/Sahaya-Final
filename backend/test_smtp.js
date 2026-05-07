import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

async function testSMTPConnection() {
  console.log('🔍 Testing SMTP Connection...\n');
  console.log('📋 Configuration:');
  console.log(`  Host: ${process.env.EMAIL_HOST}`);
  console.log(`  Port: ${process.env.EMAIL_PORT}`);
  console.log(`  User: ${process.env.EMAIL_USER}`);
  console.log(`  Secure (TLS): false\n`);

  const transporter = nodemailer.createTransport({
    host: process.env.EMAIL_HOST || "smtp-relay.brevo.com",
    port: process.env.EMAIL_PORT || 587,
    secure: false,
    auth: {
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
    logger: true,
    debug: true,
  });

  try {
    // Verify connection
    console.log('🔗 Attempting to connect to SMTP server...');
    const verified = await transporter.verify();
    
    if (verified) {
      console.log('✅ SMTP Connection Successful!\n');
      
      // Try sending a test email
      console.log('📧 Sending test email...');
      const info = await transporter.sendMail({
        from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
        to: 'ananyams@gmail.com',
        subject: 'Sahaya SMTP Test',
        text: 'This is a test email from your Sahaya application.',
        html: '<p>This is a test email from your Sahaya application.</p>'
      });
      
      console.log('✅ Test email sent successfully!');
      console.log('Message ID:', info.messageId);
    }
  } catch (error) {
    console.error('❌ SMTP Connection Failed!\n');
    console.error('Error Type:', error.name);
    console.error('Error Code:', error.code);
    console.error('Error Message:', error.message);
    console.error('\n📝 Troubleshooting:');
    
    if (error.message.includes('Invalid login') || error.message.includes('535')) {
      console.error('  → Authentication failed. Check EMAIL_USER and EMAIL_PASS');
    } else if (error.message.includes('ECONNREFUSED') || error.message.includes('ETIMEDOUT')) {
      console.error('  → Connection refused. Check HOST and PORT, firewall may be blocking');
    } else if (error.message.includes('STARTTLS')) {
      console.error('  → STARTTLS error. Try enabling secure mode or changing port');
    } else {
      console.error('  → Unknown error. See details above');
    }
  }
  
  process.exit(0);
}

testSMTPConnection();
