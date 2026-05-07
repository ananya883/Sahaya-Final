import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

async function testSMTPVariations() {
  console.log('🔍 Testing SMTP Configurations...\n');

  const configs = [
    {
      name: 'Current (secure: false, port 587)',
      config: {
        host: process.env.EMAIL_HOST,
        port: 587,
        secure: false,
      }
    },
    {
      name: 'Alternative (secure: true, port 465)',
      config: {
        host: process.env.EMAIL_HOST,
        port: 465,
        secure: true,
      }
    },
    {
      name: 'Alternative (secure: true, port 587)',
      config: {
        host: process.env.EMAIL_HOST,
        port: 587,
        secure: true,
        requireTLS: true,
      }
    },
    {
      name: 'Alternative (no secure, port 25)',
      config: {
        host: process.env.EMAIL_HOST,
        port: 25,
        secure: false,
      }
    }
  ];

  for (const test of configs) {
    console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`📌 Testing: ${test.name}`);
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);

    const transporter = nodemailer.createTransport({
      ...test.config,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
      connectionTimeout: 5000,
      socketTimeout: 5000,
    });

    try {
      const verified = await transporter.verify();
      if (verified) {
        console.log('✅ Connection successful!');
      }
    } catch (error) {
      console.error('❌ Failed:', error.message);
    }
  }

  // Also test with different credentials format
  console.log(`\n\n🔐 Testing different credential formats...\n`);

  // Try using just the domain for login (sometimes Brevo requires this)
  const credentialTests = [
    {
      name: 'Current format',
      user: process.env.EMAIL_USER,
      pass: process.env.EMAIL_PASS,
    },
    {
      name: 'Without @smtp-brevo.com',
      user: process.env.EMAIL_USER.replace('@smtp-brevo.com', ''),
      pass: process.env.EMAIL_PASS,
    }
  ];

  for (const cred of credentialTests) {
    console.log(`\n📝 Testing credentials: ${cred.user}`);
    
    const transporter = nodemailer.createTransport({
      host: process.env.EMAIL_HOST,
      port: 587,
      secure: false,
      auth: {
        user: cred.user,
        pass: cred.pass,
      },
      connectionTimeout: 5000,
      socketTimeout: 5000,
    });

    try {
      const verified = await transporter.verify();
      if (verified) {
        console.log('✅ Credentials work!');
      }
    } catch (error) {
      console.error('❌ Failed:', error.message);
    }
  }

  console.log('\n\n💡 Recommendation:');
  console.log('If all tests fail, check:');
  console.log('1. Brevo account status (login to Brevo dashboard)');
  console.log('2. SMTP credentials are correct in Brevo account settings');
  console.log('3. Your IP might be blocked - check Brevo security settings');
  
  process.exit(0);
}

testSMTPVariations();
