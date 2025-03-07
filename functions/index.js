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
    // Verify user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'You must be logged in to send feedback.'
        );
    }

    try {
        const mailOptions = {
            from: "zafir.ali05@gmail.com", // Your email
            to: "zafir.ali05@gmail.com", // Where to receive feedback
            subject: `Chrono Feedback from ${data.name}`,
            text: `
User: ${data.name}
Email: ${data.email}
Message: ${data.message}
User ID: ${context.auth.uid}
            `.trim(),
        };

        await transporter.sendMail(mailOptions);
        return { success: true };
    } catch (error) {
        console.error("Error sending feedback email:", error);
        throw new functions.https.HttpsError(
            'internal',
            'Error sending feedback email.'
        );
    }
});

