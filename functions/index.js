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

