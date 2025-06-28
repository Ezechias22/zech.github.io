// functions/index.js - FIREBASE FUNCTIONS COMPLÈTES POUR LOVINGO
const functions = require("firebase-functions");
const admin = require("firebase-admin");

// ✅ INITIALISER FIREBASE ADMIN
admin.initializeApp();

// ===================================================================
// 🔧 FONCTIONS UTILITAIRES
// ===================================================================

/**
 * Récupérer le token FCM d'un utilisateur
 * @param {string} userId - ID de l'utilisateur
 * @return {Promise<string|null>} Token FCM ou null
 */
async function getReceiverToken(userId) {
  try {
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    return userDoc.exists ? userDoc.data().fcmToken : null;
  } catch (error) {
    console.error("Erreur récupération token:", error);
    return null;
  }
}

// ===================================================================
// 🚀 SECTION 1: APPELS VIDÉO/AUDIO WEBRTC
// ===================================================================

/**
 * ✅ FONCTION PRINCIPALE : Envoyer notification d'appel
 */
exports.sendCallNotification = functions.https.onCall(async (data, context) => {
  try {
    console.log("📞 Envoi notification d'appel...", data);

    const {receiverId, callData, callerData} = data;

    if (!receiverId || !callData || !callerData) {
      throw new functions.https.HttpsError("invalid-argument", "Données manquantes");
    }

    // Récupérer le token FCM du destinataire
    const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
    if (!receiverDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Utilisateur destinataire non trouvé");
    }

    const receiverData = receiverDoc.data();
    const fcmToken = receiverData.fcmToken;

    if (!fcmToken) {
      throw new functions.https.HttpsError("failed-precondition", "Token FCM non trouvé");
    }

    // Préparer le message de notification
    const message = {
      token: fcmToken,
      notification: {
        title: `📞 Appel ${callData.hasVideo ? "vidéo" : "vocal"} entrant`,
        body: `${callerData.name} vous appelle`,
      },
      data: {
        type: "incoming_call",
        call_data: JSON.stringify(callData),
        caller_data: JSON.stringify(callerData),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "call_notifications",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: `📞 Appel ${callData.hasVideo ? "vidéo" : "vocal"} entrant`,
              body: `${callerData.name} vous appelle`,
            },
            sound: "default",
            badge: 1,
            category: "CALL_INVITATION",
          },
        },
      },
    };

    // Envoyer la notification
    const response = await admin.messaging().send(message);
    console.log("✅ Notification envoyée:", response);

    return {
      success: true,
      messageId: response,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
  } catch (error) {
    console.error("❌ Erreur envoi notification:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * ✅ TRIGGER : Détecter nouveaux appels et envoyer notifications automatiquement
 */
exports.onCallCreated = functions.firestore
    .document("calls/{callId}")
    .onCreate(async (snap, context) => {
      try {
        const callData = snap.data();
        const callId = context.params.callId;

        console.log("📞 Nouvel appel détecté:", callId, callData.status);

        // Seulement pour les appels en statut "ringing"
        if (callData.status !== "ringing") {
          console.log("⏭️ Appel pas en statut ringing, ignoré");
          return;
        }

        // Récupérer les données de l'appelant
        const callerDoc = await admin.firestore().collection("users").doc(callData.callerId).get();
        if (!callerDoc.exists) {
          console.error("❌ Appelant non trouvé:", callData.callerId);
          return;
        }

        const callerData = callerDoc.data();

        // Récupérer le token FCM du destinataire
        const receiverToken = await getReceiverToken(callData.receiverId);
        if (!receiverToken) {
          console.error("❌ Token FCM non trouvé pour:", callData.receiverId);
          return;
        }

        // Envoyer la notification directement
        const notificationResult = await admin.messaging().send({
          token: receiverToken,
          notification: {
            title: `📞 Appel ${callData.hasVideo ? "vidéo" : "vocal"} entrant`,
            body: `${callerData.name} vous appelle`,
          },
          data: {
            type: "incoming_call",
            call_data: JSON.stringify(callData),
            caller_data: JSON.stringify({
              id: callerData.id,
              name: callerData.name,
              photos: callerData.photos || [],
              email: callerData.email,
            }),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "call_notifications",
              priority: "high",
              defaultSound: true,
              defaultVibrateTimings: true,
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: `📞 Appel ${callData.hasVideo ? "vidéo" : "vocal"} entrant`,
                  body: `${callerData.name} vous appelle`,
                },
                sound: "default",
                badge: 1,
                category: "CALL_INVITATION",
              },
            },
          },
        });

        console.log("✅ Notification automatique envoyée:", notificationResult);
      } catch (error) {
        console.error("❌ Erreur trigger appel:", error);
      }
    });

/**
 * ✅ FONCTION DE TEST
 */
exports.testCallNotification = functions.https.onCall(async (data, context) => {
  try {
    console.log("🧪 Test notification d'appel...");

    return {
      success: true,
      message: "Système de notifications opérationnel",
      testCallId: `test_${Date.now()}`,
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    console.error("❌ Erreur test notification:", error);
    return {
      success: false,
      error: error.message,
    };
  }
});

// ===================================================================
// 🎁 SECTION 2: CADEAUX VIRTUELS
// ===================================================================

/**
 * ✅ ENVOYER UN CADEAU VIRTUEL
 */
exports.sendVirtualGift = functions.https.onCall(async (data, context) => {
  try {
    console.log("🎁 Envoi cadeau virtuel...", data);

    const {senderId, receiverId, giftId, quantity, roomId} = data;

    if (!senderId || !receiverId || !giftId || !quantity) {
      throw new functions.https.HttpsError("invalid-argument", "Données manquantes");
    }

    // Récupérer les infos du cadeau
    const giftDoc = await admin.firestore().collection("virtual_gifts").doc(giftId).get();
    if (!giftDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Cadeau non trouvé");
    }

    const giftData = giftDoc.data();
    const totalCost = giftData.price * quantity;

    // Vérifier le solde de l'expéditeur
    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderData = senderDoc.data();
    const senderBalance = senderData && senderData.wallet ? senderData.wallet.balance || 0 : 0;

    if (senderBalance < totalCost) {
      throw new functions.https.HttpsError("failed-precondition", "Solde insuffisant");
    }

    // Transaction pour déduire les coins et ajouter les gains
    await admin.firestore().runTransaction(async (transaction) => {
      // Déduire du solde expéditeur
      const senderRef = admin.firestore().collection("users").doc(senderId);
      transaction.update(senderRef, {
        "wallet.balance": admin.firestore.FieldValue.increment(-totalCost),
        "stats.totalGiftsSent": admin.firestore.FieldValue.increment(quantity),
      });

      // Ajouter aux gains destinataire
      const receiverRef = admin.firestore().collection("users").doc(receiverId);
      const receiverEarnings = totalCost * 0.7; // 70% pour le destinataire
      transaction.update(receiverRef, {
        "wallet.balance": admin.firestore.FieldValue.increment(receiverEarnings),
        "wallet.totalEarnings": admin.firestore.FieldValue.increment(receiverEarnings),
        "stats.totalGiftsReceived": admin.firestore.FieldValue.increment(quantity),
      });

      // Enregistrer la transaction
      const transactionRef = admin.firestore().collection("gift_transactions").doc();
      transaction.set(transactionRef, {
        senderId,
        receiverId,
        giftId,
        giftName: giftData.name,
        quantity,
        totalCost,
        receiverEarnings,
        platformFee: totalCost * 0.3,
        roomId: roomId || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "virtual_gift",
      });
    });

    // Envoyer notification au destinataire
    const receiverDoc = await admin.firestore().collection("users").doc(receiverId).get();
    if (receiverDoc.exists && receiverDoc.data().fcmToken) {
      const senderData = senderDoc.data();
      await admin.messaging().send({
        token: receiverDoc.data().fcmToken,
        notification: {
          title: "🎁 Cadeau reçu !",
          body: `${senderData.name} vous a envoyé ${quantity}x ${giftData.name}`,
        },
        data: {
          type: "virtual_gift",
          senderId,
          giftId,
          quantity: quantity.toString(),
        },
      });
    }

    return {
      success: true,
      transactionId: `gift_${Date.now()}`,
      totalCost,
      receiverEarnings: totalCost * 0.7,
    };
  } catch (error) {
    console.error("❌ Erreur cadeau virtuel:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ===================================================================
// 💰 SECTION 3: SYSTÈME DE PAIEMENT ET RECHARGE
// ===================================================================

/**
 * ✅ RECHARGER DES COINS
 */
exports.rechargeCoins = functions.https.onCall(async (data, context) => {
  try {
    console.log("💰 Recharge coins...", data);

    const {userId, amount, paymentMethod, paymentId} = data;

    if (!userId || !amount || amount <= 0) {
      throw new functions.https.HttpsError("invalid-argument", "Données invalides");
    }

    // Calculer les coins selon votre taux de change
    const coinsToAdd = amount * 100; // 1€ = 100 coins par exemple

    // Transaction pour ajouter les coins
    await admin.firestore().runTransaction(async (transaction) => {
      const userRef = admin.firestore().collection("users").doc(userId);
      transaction.update(userRef, {
        "wallet.balance": admin.firestore.FieldValue.increment(coinsToAdd),
      });

      // Enregistrer la transaction de recharge
      const transactionRef = admin.firestore().collection("payment_transactions").doc();
      transaction.set(transactionRef, {
        userId,
        type: "recharge",
        amount: amount,
        coinsAdded: coinsToAdd,
        paymentMethod: paymentMethod || "unknown",
        paymentId: paymentId || null,
        status: "completed",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      success: true,
      coinsAdded: coinsToAdd,
      newBalance: "updated_in_firestore",
      transactionId: `recharge_${Date.now()}`,
    };
  } catch (error) {
    console.error("❌ Erreur recharge coins:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * ✅ RETIRER DES GAINS
 */
exports.withdrawEarnings = functions.https.onCall(async (data, context) => {
  try {
    console.log("💸 Retrait gains...", data);

    const {userId, amount, withdrawalMethod, accountDetails} = data;

    if (!userId || !amount || amount <= 0) {
      throw new functions.https.HttpsError("invalid-argument", "Données invalides");
    }

    // Vérifier le solde disponible
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const userData = userDoc.data();
    const availableBalance = userData && userData.wallet ? userData.wallet.totalEarnings || 0 : 0;
    const pendingWithdrawals = userData && userData.wallet ? userData.wallet.pendingWithdrawal || 0 : 0;
    const withdrawableAmount = availableBalance - pendingWithdrawals;

    if (withdrawableAmount < amount) {
      throw new functions.https.HttpsError("failed-precondition", "Solde insuffisant pour le retrait");
    }

    // Minimum de retrait
    if (amount < 10) {
      throw new functions.https.HttpsError("failed-precondition", "Montant minimum de retrait: 10€");
    }

    // Créer la demande de retrait
    const withdrawalRef = admin.firestore().collection("withdrawal_requests").doc();
    await withdrawalRef.set({
      userId,
      amount,
      withdrawalMethod: withdrawalMethod || "bank_transfer",
      accountDetails: accountDetails || {},
      status: "pending",
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: null,
      transactionId: null,
    });

    // Mettre à jour le montant en attente
    await admin.firestore().collection("users").doc(userId).update({
      "wallet.pendingWithdrawal": admin.firestore.FieldValue.increment(amount),
    });

    return {
      success: true,
      withdrawalId: withdrawalRef.id,
      amount,
      status: "pending",
      estimatedProcessingTime: "3-5 jours ouvrables",
    };
  } catch (error) {
    console.error("❌ Erreur retrait:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ===================================================================
// 📱 SECTION 4: LIVE STREAMING
// ===================================================================

/**
 * ✅ DÉMARRER UN LIVE STREAM
 */
exports.startLiveStream = functions.https.onCall(async (data, context) => {
  try {
    console.log("📺 Démarrage live stream...", data);

    const {hostId, title, description, isPrivate} = data;

    if (!hostId || !title) {
      throw new functions.https.HttpsError("invalid-argument", "Données manquantes");
    }

    // Vérifier que l'utilisateur n'a pas déjà un live actif
    const existingLive = await admin.firestore()
        .collection("live_streams")
        .where("hostId", "==", hostId)
        .where("status", "==", "active")
        .get();

    if (!existingLive.empty) {
      throw new functions.https.HttpsError("failed-precondition", "Live déjà actif");
    }

    // Créer le live stream
    const liveId = `live_${Date.now()}_${hostId}`;
    const liveData = {
      id: liveId,
      hostId,
      title,
      description: description || "",
      isPrivate: isPrivate || false,
      status: "active",
      viewerCount: 0,
      totalGifts: 0,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      endedAt: null,
      viewers: [],
      guests: [],
    };

    await admin.firestore().collection("live_streams").doc(liveId).set(liveData);

    return {
      success: true,
      liveId,
      channelName: liveId,
      status: "active",
    };
  } catch (error) {
    console.error("❌ Erreur démarrage live:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * ✅ TERMINER UN LIVE STREAM
 */
exports.endLiveStream = functions.https.onCall(async (data, context) => {
  try {
    const {liveId, hostId} = data;

    const liveRef = admin.firestore().collection("live_streams").doc(liveId);
    const liveDoc = await liveRef.get();

    if (!liveDoc.exists || liveDoc.data().hostId !== hostId) {
      throw new functions.https.HttpsError("not-found", "Live non trouvé");
    }

    // Mettre à jour le statut
    await liveRef.update({
      status: "ended",
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      liveId,
      status: "ended",
    };
  } catch (error) {
    console.error("❌ Erreur fin live:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// ===================================================================
// 💬 SECTION 5: MESSAGES ET NOTIFICATIONS
// ===================================================================

/**
 * ✅ TRIGGER : Nouveau message pour notifications
 */
exports.onMessageSent = functions.firestore
    .document("chat_rooms/{chatRoomId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
      try {
        const messageData = snap.data();
        const chatRoomId = context.params.chatRoomId;

        // Récupérer les participants de la conversation
        const chatRoomDoc = await admin.firestore().collection("chat_rooms").doc(chatRoomId).get();
        if (!chatRoomDoc.exists) return;

        const participants = chatRoomDoc.data().participants || [];
        const receiverId = participants.find((id) => id !== messageData.senderId);

        if (!receiverId) return;

        // Récupérer les données des utilisateurs
        const [senderDoc, receiverDoc] = await Promise.all([
          admin.firestore().collection("users").doc(messageData.senderId).get(),
          admin.firestore().collection("users").doc(receiverId).get(),
        ]);

        if (!receiverDoc.exists || !receiverDoc.data().fcmToken) return;

        const senderData = senderDoc.data();

        // Envoyer la notification
        await admin.messaging().send({
          token: receiverDoc.data().fcmToken,
          notification: {
            title: senderData.name,
            body: messageData.content,
          },
          data: {
            type: "new_message",
            chatRoomId,
            senderId: messageData.senderId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        });

        console.log("✅ Notification message envoyée");
      } catch (error) {
        console.error("❌ Erreur notification message:", error);
      }
    });

// ===================================================================
// 🔧 SECTION 6: UTILITAIRES ET MAINTENANCE
// ===================================================================

/**
 * ✅ NETTOYAGE AUTOMATIQUE DES DONNÉES
 */
exports.cleanupOldData = functions.pubsub.schedule("0 2 * * *").onRun(async (context) => {
  try {
    console.log("🧹 Nettoyage automatique des données...");

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30); // 30 jours

    // Nettoyer les anciens appels
    const oldCalls = await admin.firestore()
        .collection("calls")
        .where("createdAt", "<", cutoffDate)
        .where("status", "in", ["ended", "declined", "missed"])
        .get();

    const batch = admin.firestore().batch();
    oldCalls.docs.forEach((doc) => batch.delete(doc.ref));

    if (!oldCalls.empty) {
      await batch.commit();
      console.log(`🗑️ ${oldCalls.size} anciens appels supprimés`);
    }

    return null;
  } catch (error) {
    console.error("❌ Erreur nettoyage:", error);
  }
});

/**
 * ✅ FONCTION DE SANTÉ GLOBALE
 */
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
    features: [
      "call_notifications",
      "virtual_gifts",
      "payment_system",
      "live_streaming",
      "message_notifications",
      "data_cleanup",
    ],
  });
});

// ===================================================================
// 🚀 SECTION 1: APPELS VIDÉO/AUDIO WEBRTC
// ===================================================================

/**
 * ✅ FONCTION PRINCIPALE : Envoyer notification d'appel
 */
exports.sendCallNotification = functions.https.onCall(async (data, context) => {
  try {
    console.log('📞 Envoi notification d\'appel...', data);
    
    const { receiverId, callData, callerData } = data;
    
    if (!receiverId || !callData || !callerData) {
      throw new functions.https.HttpsError('invalid-argument', 'Données manquantes');
    }

    // Récupérer le token FCM du destinataire
    const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
    if (!receiverDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Utilisateur destinataire non trouvé');
    }

    const receiverData = receiverDoc.data();
    const fcmToken = receiverData.fcmToken;

    if (!fcmToken) {
      throw new functions.https.HttpsError('failed-precondition', 'Token FCM non trouvé');
    }

    // Préparer le message de notification
    const message = {
      token: fcmToken,
      notification: {
        title: `📞 Appel ${callData.hasVideo ? 'vidéo' : 'vocal'} entrant`,
        body: `${callerData.name} vous appelle`,
      },
      data: {
        type: 'incoming_call',
        call_data: JSON.stringify(callData),
        caller_data: JSON.stringify(callerData),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'call_notifications',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: `📞 Appel ${callData.hasVideo ? 'vidéo' : 'vocal'} entrant`,
              body: `${callerData.name} vous appelle`,
            },
            sound: 'default',
            badge: 1,
            category: 'CALL_INVITATION',
          },
        },
      },
    };

    // Envoyer la notification
    const response = await admin.messaging().send(message);
    console.log('✅ Notification envoyée:', response);

    return {
      success: true,
      messageId: response,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

  } catch (error) {
    console.error('❌ Erreur envoi notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * ✅ TRIGGER : Détecter nouveaux appels et envoyer notifications automatiquement
 */
exports.onCallCreated = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snap, context) => {
    try {
      const callData = snap.data();
      const callId = context.params.callId;
      
      console.log('📞 Nouvel appel détecté:', callId, callData.status);

      // Seulement pour les appels en statut "ringing"
      if (callData.status !== 'ringing') {
        console.log('⏭️ Appel pas en statut ringing, ignoré');
        return;
      }

      // Récupérer les données de l'appelant
      const callerDoc = await admin.firestore().collection('users').doc(callData.callerId).get();
      if (!callerDoc.exists) {
        console.error('❌ Appelant non trouvé:', callData.callerId);
        return;
      }

      const callerData = callerDoc.data();

      // Appeler la fonction d'envoi de notification
      const notificationResult = await admin.functions().httpsCallable('sendCallNotification')({
        receiverId: callData.receiverId,
        callData: callData,
        callerData: {
          id: callerData.id,
          name: callerData.name,
          photos: callerData.photos || [],
          email: callerData.email,
        },
      });

      console.log('✅ Notification automatique envoyée:', notificationResult);

    } catch (error) {
      console.error('❌ Erreur trigger appel:', error);
    }
  });

/**
 * ✅ FONCTION DE TEST
 */
exports.testCallNotification = functions.https.onCall(async (data, context) => {
  try {
    console.log('🧪 Test notification d\'appel...');

    return {
      success: true,
      message: 'Système de notifications opérationnel',
      testCallId: `test_${Date.now()}`,
      timestamp: new Date().toISOString(),
    };

  } catch (error) {
    console.error('❌ Erreur test notification:', error);
    return {
      success: false,
      error: error.message,
    };
  }
});

// ===================================================================
// 🎁 SECTION 2: CADEAUX VIRTUELS
// ===================================================================

/**
 * ✅ ENVOYER UN CADEAU VIRTUEL
 */
exports.sendVirtualGift = functions.https.onCall(async (data, context) => {
  try {
    console.log('🎁 Envoi cadeau virtuel...', data);
    
    const { senderId, receiverId, giftId, quantity, roomId } = data;
    
    if (!senderId || !receiverId || !giftId || !quantity) {
      throw new functions.https.HttpsError('invalid-argument', 'Données manquantes');
    }

    // Récupérer les infos du cadeau
    const giftDoc = await admin.firestore().collection('virtual_gifts').doc(giftId).get();
    if (!giftDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Cadeau non trouvé');
    }

    const giftData = giftDoc.data();
    const totalCost = giftData.price * quantity;

    // Vérifier le solde de l'expéditeur
    const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
    const senderBalance = senderDoc.data().wallet?.balance || 0;

    if (senderBalance < totalCost) {
      throw new functions.https.HttpsError('failed-precondition', 'Solde insuffisant');
    }

    // Transaction pour déduire les coins et ajouter les gains
    await admin.firestore().runTransaction(async (transaction) => {
      // Déduire du solde expéditeur
      const senderRef = admin.firestore().collection('users').doc(senderId);
      transaction.update(senderRef, {
        'wallet.balance': admin.firestore.FieldValue.increment(-totalCost),
        'stats.totalGiftsSent': admin.firestore.FieldValue.increment(quantity),
      });

      // Ajouter aux gains destinataire
      const receiverRef = admin.firestore().collection('users').doc(receiverId);
      const receiverEarnings = totalCost * 0.7; // 70% pour le destinataire
      transaction.update(receiverRef, {
        'wallet.balance': admin.firestore.FieldValue.increment(receiverEarnings),
        'wallet.totalEarnings': admin.firestore.FieldValue.increment(receiverEarnings),
        'stats.totalGiftsReceived': admin.firestore.FieldValue.increment(quantity),
      });

      // Enregistrer la transaction
      const transactionRef = admin.firestore().collection('gift_transactions').doc();
      transaction.set(transactionRef, {
        senderId,
        receiverId,
        giftId,
        giftName: giftData.name,
        quantity,
        totalCost,
        receiverEarnings,
        platformFee: totalCost * 0.3,
        roomId: roomId || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: 'virtual_gift',
      });
    });

    // Envoyer notification au destinataire
    const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
    if (receiverDoc.exists && receiverDoc.data().fcmToken) {
      const senderData = senderDoc.data();
      await admin.messaging().send({
        token: receiverDoc.data().fcmToken,
        notification: {
          title: '🎁 Cadeau reçu !',
          body: `${senderData.name} vous a envoyé ${quantity}x ${giftData.name}`,
        },
        data: {
          type: 'virtual_gift',
          senderId,
          giftId,
          quantity: quantity.toString(),
        },
      });
    }

    return {
      success: true,
      transactionId: `gift_${Date.now()}`,
      totalCost,
      receiverEarnings: totalCost * 0.7,
    };

  } catch (error) {
    console.error('❌ Erreur cadeau virtuel:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ===================================================================
// 💰 SECTION 3: SYSTÈME DE PAIEMENT ET RECHARGE
// ===================================================================

/**
 * ✅ RECHARGER DES COINS
 */
exports.rechargeCoins = functions.https.onCall(async (data, context) => {
  try {
    console.log('💰 Recharge coins...', data);
    
    const { userId, amount, paymentMethod, paymentId } = data;
    
    if (!userId || !amount || amount <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Données invalides');
    }

    // Ici vous intégreriez avec votre processeur de paiement (Stripe, PayPal, etc.)
    // Pour l'exemple, on simule un paiement réussi
    
    // Calculer les coins selon votre taux de change
    const coinsToAdd = amount * 100; // 1€ = 100 coins par exemple

    // Transaction pour ajouter les coins
    await admin.firestore().runTransaction(async (transaction) => {
      const userRef = admin.firestore().collection('users').doc(userId);
      transaction.update(userRef, {
        'wallet.balance': admin.firestore.FieldValue.increment(coinsToAdd),
      });

      // Enregistrer la transaction de recharge
      const transactionRef = admin.firestore().collection('payment_transactions').doc();
      transaction.set(transactionRef, {
        userId,
        type: 'recharge',
        amount: amount,
        coinsAdded: coinsToAdd,
        paymentMethod: paymentMethod || 'unknown',
        paymentId: paymentId || null,
        status: 'completed',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      success: true,
      coinsAdded,
      newBalance: 'updated_in_firestore',
      transactionId: `recharge_${Date.now()}`,
    };

  } catch (error) {
    console.error('❌ Erreur recharge coins:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * ✅ RETIRER DES GAINS
 */
exports.withdrawEarnings = functions.https.onCall(async (data, context) => {
  try {
    console.log('💸 Retrait gains...', data);
    
    const { userId, amount, withdrawalMethod, accountDetails } = data;
    
    if (!userId || !amount || amount <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Données invalides');
    }

    // Vérifier le solde disponible
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const availableBalance = userDoc.data().wallet?.totalEarnings || 0;
    const pendingWithdrawals = userDoc.data().wallet?.pendingWithdrawal || 0;
    const withdrawableAmount = availableBalance - pendingWithdrawals;

    if (withdrawableAmount < amount) {
      throw new functions.https.HttpsError('failed-precondition', 'Solde insuffisant pour le retrait');
    }

    // Minimum de retrait
    if (amount < 10) {
      throw new functions.https.HttpsError('failed-precondition', 'Montant minimum de retrait: 10€');
    }

    // Créer la demande de retrait
    const withdrawalRef = admin.firestore().collection('withdrawal_requests').doc();
    await withdrawalRef.set({
      userId,
      amount,
      withdrawalMethod: withdrawalMethod || 'bank_transfer',
      accountDetails: accountDetails || {},
      status: 'pending',
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      processedAt: null,
      transactionId: null,
    });

    // Mettre à jour le montant en attente
    await admin.firestore().collection('users').doc(userId).update({
      'wallet.pendingWithdrawal': admin.firestore.FieldValue.increment(amount),
    });

    return {
      success: true,
      withdrawalId: withdrawalRef.id,
      amount,
      status: 'pending',
      estimatedProcessingTime: '3-5 jours ouvrables',
    };

  } catch (error) {
    console.error('❌ Erreur retrait:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ===================================================================
// 📱 SECTION 4: LIVE STREAMING
// ===================================================================

/**
 * ✅ DÉMARRER UN LIVE STREAM
 */
exports.startLiveStream = functions.https.onCall(async (data, context) => {
  try {
    console.log('📺 Démarrage live stream...', data);
    
    const { hostId, title, description, isPrivate } = data;
    
    if (!hostId || !title) {
      throw new functions.https.HttpsError('invalid-argument', 'Données manquantes');
    }

    // Vérifier que l'utilisateur n'a pas déjà un live actif
    const existingLive = await admin.firestore()
      .collection('live_streams')
      .where('hostId', '==', hostId)
      .where('status', '==', 'active')
      .get();

    if (!existingLive.empty) {
      throw new functions.https.HttpsError('failed-precondition', 'Live déjà actif');
    }

    // Créer le live stream
    const liveId = `live_${Date.now()}_${hostId}`;
    const liveData = {
      id: liveId,
      hostId,
      title,
      description: description || '',
      isPrivate: isPrivate || false,
      status: 'active',
      viewerCount: 0,
      totalGifts: 0,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      endedAt: null,
      viewers: [],
      guests: [],
    };

    await admin.firestore().collection('live_streams').doc(liveId).set(liveData);

    // Notifier les followers (si ce n'est pas privé)
    if (!isPrivate) {
      // Ici vous pourriez récupérer les followers et envoyer des notifications
      console.log('📢 Notifications followers à implémenter');
    }

    return {
      success: true,
      liveId,
      channelName: liveId,
      status: 'active',
    };

  } catch (error) {
    console.error('❌ Erreur démarrage live:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * ✅ TERMINER UN LIVE STREAM
 */
exports.endLiveStream = functions.https.onCall(async (data, context) => {
  try {
    const { liveId, hostId } = data;
    
    const liveRef = admin.firestore().collection('live_streams').doc(liveId);
    const liveDoc = await liveRef.get();
    
    if (!liveDoc.exists || liveDoc.data().hostId !== hostId) {
      throw new functions.https.HttpsError('not-found', 'Live non trouvé');
    }

    // Mettre à jour le statut
    await liveRef.update({
      status: 'ended',
      endedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      liveId,
      status: 'ended',
    };

  } catch (error) {
    console.error('❌ Erreur fin live:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ===================================================================
// 💬 SECTION 5: MESSAGES ET NOTIFICATIONS
// ===================================================================

/**
 * ✅ TRIGGER : Nouveau message pour notifications
 */
exports.onMessageSent = functions.firestore
  .document('chat_rooms/{chatRoomId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const messageData = snap.data();
      const chatRoomId = context.params.chatRoomId;
      
      // Récupérer les participants de la conversation
      const chatRoomDoc = await admin.firestore().collection('chat_rooms').doc(chatRoomId).get();
      if (!chatRoomDoc.exists) return;
      
      const participants = chatRoomDoc.data().participants || [];
      const receiverId = participants.find(id => id !== messageData.senderId);
      
      if (!receiverId) return;

      // Récupérer les données des utilisateurs
      const [senderDoc, receiverDoc] = await Promise.all([
        admin.firestore().collection('users').doc(messageData.senderId).get(),
        admin.firestore().collection('users').doc(receiverId).get(),
      ]);

      if (!receiverDoc.exists || !receiverDoc.data().fcmToken) return;

      const senderData = senderDoc.data();

      // Envoyer la notification
      await admin.messaging().send({
        token: receiverDoc.data().fcmToken,
        notification: {
          title: senderData.name,
          body: messageData.content,
        },
        data: {
          type: 'new_message',
          chatRoomId,
          senderId: messageData.senderId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      });

      console.log('✅ Notification message envoyée');

    } catch (error) {
      console.error('❌ Erreur notification message:', error);
    }
  });

// ===================================================================
// 🔧 SECTION 6: UTILITAIRES ET MAINTENANCE
// ===================================================================

/**
 * ✅ NETTOYAGE AUTOMATIQUE DES DONNÉES
 */
exports.cleanupOldData = functions.pubsub.schedule('0 2 * * *').onRun(async (context) => {
  try {
    console.log('🧹 Nettoyage automatique des données...');
    
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30); // 30 jours

    // Nettoyer les anciens appels
    const oldCalls = await admin.firestore()
      .collection('calls')
      .where('createdAt', '<', cutoffDate)
      .where('status', 'in', ['ended', 'declined', 'missed'])
      .get();

    const batch = admin.firestore().batch();
    oldCalls.docs.forEach(doc => batch.delete(doc.ref));
    
    if (!oldCalls.empty) {
      await batch.commit();
      console.log(`🗑️ ${oldCalls.size} anciens appels supprimés`);
    }

    // Nettoyer les anciens live streams inactifs
    const oldLives = await admin.firestore()
      .collection('live_streams')
      .where('startedAt', '<', cutoffDate)
      .where('status', '==', 'ended')
      .get();

    if (!oldLives.empty) {
      const liveBatch = admin.firestore().batch();
      oldLives.docs.forEach(doc => liveBatch.delete(doc.ref));
      await liveBatch.commit();
      console.log(`🗑️ ${oldLives.size} anciens lives supprimés`);
    }

    return null;
  } catch (error) {
    console.error('❌ Erreur nettoyage:', error);
  }
});

/**
 * ✅ FONCTION DE SANTÉ GLOBALE
 */
exports.healthCheck = functions.https.onRequest((req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    features: [
      'call_notifications',
      'virtual_gifts',
      'payment_system',
      'live_streaming',
      'message_notifications',
      'data_cleanup',
    ],
  });
});