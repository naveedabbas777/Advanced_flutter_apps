const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Send notification on group invitation
exports.sendGroupInvitationNotification = functions.firestore
  .document("group_invitations/{invitationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const invitedUserId = data.invitedUserId;
    const groupName = data.groupName;

    // Get the invited user's FCM token
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(invitedUserId)
      .get();
    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return null;

    const payload = {
      notification: {
        title: "Group Invitation",
        body: `You have been invited to join "${groupName}"`,
      },
      data: {
        type: "invitation",
        groupId: data.groupId,
      },
    };

    return admin.messaging().sendToDevice(fcmToken, payload);
  });

// Send notification on new group message
exports.sendNewGroupMessageNotification = functions.firestore
  .document("groups/{groupId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const groupId = context.params.groupId;
    const senderId = data.senderId;
    const messageText = data.text || "You have a new message";

    // Get group members except sender
    const groupDoc = await admin
      .firestore()
      .collection("groups")
      .doc(groupId)
      .get();
    const memberIds = groupDoc.data().memberIds || [];
    const recipients = memberIds.filter((uid) => uid !== senderId);

    // Fetch FCM tokens for all recipients
    const tokens = [];
    for (const uid of recipients) {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(uid)
        .get();
      if (userDoc.exists && userDoc.data().fcmToken) {
        tokens.push(userDoc.data().fcmToken);
      }
    }
    if (tokens.length === 0) return null;

    const payload = {
      notification: {
        title: "New Group Message",
        body: messageText,
      },
      data: {
        type: "group_message",
        groupId: groupId,
      },
    };

    return admin.messaging().sendToDevice(tokens, payload);
  });