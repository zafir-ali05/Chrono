/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

require('dotenv').config();

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {onCall} = require("firebase-functions/v2/https");
// For v1 functions, just use the base firebase-functions import

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Configure email transporter with Gmail
const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_APP_PASSWORD
    }
});

// Cloud Function to send feedback
exports.sendFeedback = functions.https.onCall(async (data, context) => {
    console.log("Function called with data:", data);
    console.log("Auth context:", context.auth);
    
    // Verify user is authenticated
    if (!context.auth) {
        console.error("Authentication failed - user not logged in");
        throw new functions.https.HttpsError(
            'unauthenticated',
            'You must be logged in to send feedback.'
        );
    }

    // Validate required fields
    if (!data.name || !data.email || !data.message) {
        console.error("Missing required fields in request");
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Missing required fields: name, email, or message.'
        );
    }

    try {
        const mailOptions = {
            from: process.env.GMAIL_USER,
            to: process.env.GMAIL_USER, // Where to receive feedback
            subject: `Chrono Feedback from ${data.name}`,
            text: `
                User: ${data.name}
                Email: ${data.email}
                Message: ${data.message}
                User ID: ${context.auth.uid}
            `.trim(),
        };

        console.log("Sending email with options:", {
            to: process.env.GMAIL_USER,
            subject: mailOptions.subject
        });

        await transporter.sendMail(mailOptions);
        console.log("Email sent successfully");
        return { success: true };
    } catch (error) {
        console.error("Error sending feedback email:", error);
        throw new functions.https.HttpsError(
            'internal',
            'Error sending feedback email: ' + error.message
        );
    }
});

// Configure the email transport
const mailTransport = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'zafir.ali05@gmail.com', // Replace with your email
    pass: 'fvre pizz pssq pwek',    // Replace with your app password
  }
});

// Set your email address
const SENDER_EMAIL = 'zafir.ali05@gmail.com'; // Replace with your email
const APP_NAME = 'Chrono';

// Listens for new feedback using v1 syntax instead of v2
// Correct v1 syntax for Firestore triggers
exports.sendFeedbackEmail = functions.firestore
  .document('feedback/{feedbackId}')
  .onCreate(async (snapshot, context) => {
    // No need to check event.data - the data is directly in snapshot
    const feedback = snapshot.data();
    
    const userName = feedback.name || 'Anonymous User';
    const userEmail = feedback.email || 'No email provided';
    const message = feedback.message;
    const timestamp = feedback.timestamp ? new Date(feedback.timestamp.toDate()) : new Date();
    
    const mailOptions = {
      from: `${APP_NAME} <${SENDER_EMAIL}>`,
      to: SENDER_EMAIL, // Send to yourself
      subject: `[${APP_NAME} Feedback] from ${userName}`,
      text: 
        `You received feedback from a Chrono user:
        
        Name: ${userName}
        Email: ${userEmail}
        Time: ${timestamp}
        
        Message:
        ${message}
        
        ---
        This is an automated email from your Chrono app.`,
      html: 
        `<h2>You received feedback from a Chrono user</h2>
        <p><strong>Name:</strong> ${userName}</p>
        <p><strong>Email:</strong> ${userEmail}</p>
        <p><strong>Time:</strong> ${timestamp}</p>
        <h3>Message:</h3>
        <p>${message.replace(/\n/g, '<br>')}</p>
        <hr>
        <p><small>This is an automated email from your Chrono app.</small></p>`,
    };

    try {
      await mailTransport.sendMail(mailOptions);
      console.log('Feedback email sent to admin');
      
      // Also send a confirmation to the user if they provided an email
      if (userEmail && userEmail !== 'No email provided') {
        const userMailOptions = {
          from: `${APP_NAME} <${SENDER_EMAIL}>`,
          to: userEmail,
          subject: `Your feedback to ${APP_NAME}`,
          text: 
            `Thank you for your feedback to ${APP_NAME}!
            
            We've received your message and will review it shortly. Below is a copy of your feedback:
            
            "${message}"
            
            Thank you for helping us improve ${APP_NAME}.
            
            ---
            This is an automated email. Please do not reply.`,
          html:
            `<h2>Thank you for your feedback to ${APP_NAME}!</h2>
            <p>We've received your message and will review it shortly. Below is a copy of your feedback:</p>
            <blockquote>${message.replace(/\n/g, '<br>')}</blockquote>
            <p>Thank you for helping us improve ${APP_NAME}.</p>
            <hr>
            <p><small>This is an automated email. Please do not reply.</small></p>`,
        };
        
        await mailTransport.sendMail(userMailOptions);
        console.log('Confirmation email sent to user');
      }
      
      return null;
    } catch(error) {
      console.error('There was an error sending the feedback email:', error);
      throw new Error('Error sending feedback email: ' + error.message);
    }
  });

