const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

// Initialize with your service account JSON file
const serviceAccount = require('./fypsavr-firebase-adminsdk-fbsvc-b55639dcbc.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// ========== MAIN NOTIFICATION FUNCTION ==========
exports.sendNotification = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  cors(req, res, async () => {
    try {
      console.log('📱 Cloud Function: sendNotification called');
      
      const { userId, title, body, data } = req.body;
      
      // Validate input
      if (!userId || !title || !body) {
        console.error('❌ Missing required fields');
        return res.status(400).json({ 
          success: false, 
          error: 'Missing userId, title, or body' 
        });
      }
      
      console.log(`📱 Sending to user: ${userId}`);
      console.log(`📱 Title: ${title}`);
      console.log(`📱 Body: ${body}`);
      
      // 1. Get user's FCM tokens from Firestore
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
      
      if (!userDoc.exists) {
        console.error(`❌ User ${userId} not found`);
        return res.status(404).json({ 
          success: false, 
          error: 'User not found' 
        });
      }
      
      const userData = userDoc.data();
      const tokens = userData.fcmTokens || [];
      
      if (tokens.length === 0) {
        console.error(`❌ No FCM tokens for user ${userId}`);
        return res.status(400).json({ 
          success: false, 
          error: 'No FCM tokens found' 
        });
      }
      
      console.log(`✅ Found ${tokens.length} token(s) for user ${userId}`);
      
      // 2. Prepare notification message
      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: data || {},
        android: {
          priority: 'high',
          notification: {
            channelId: 'order_notifications',
            sound: 'default',
            icon: 'ic_notification',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };
      
      // 3. Send to each token
      const results = [];
      for (const token of tokens) {
        try {
          const result = await admin.messaging().send({
            ...message,
            token: token,
          });
          results.push({ 
            token: token.substring(0, 30) + '...', 
            success: true,
            messageId: result 
          });
          console.log(`✅ Sent to token: ${token.substring(0, 30)}...`);
        } catch (error) {
          console.error(`❌ Failed for token: ${error.message}`);
          results.push({ 
            token: token.substring(0, 30) + '...', 
            success: false, 
            error: error.message 
          });
        }
      }
      
      const successful = results.filter(r => r.success).length;
      const failed = results.filter(r => !r.success).length;
      
      console.log(`📊 Results: ${successful} successful, ${failed} failed`);
      
      // 4. Return response
      return res.status(200).json({
        success: true,
        sent: successful,
        failed: failed,
        totalTokens: tokens.length,
        results: results,
      });
      
    } catch (error) {
      console.error('❌ Cloud Function Error:', error);
      return res.status(500).json({ 
        success: false, 
        error: error.message 
      });
    }
  });
});

// ========== AUTOMATIC ORDER NOTIFICATIONS ==========

// Trigger when new order is created
exports.onNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snapshot, context) => {
    try {
      const order = snapshot.data();
      const orderId = context.params.orderId;
      
      console.log(`🆕 New order created: ${orderId}`);
      
      // Get merchant ID from restaurant
      const restaurantId = order.restaurantId;
      const restaurantDoc = await admin.firestore()
        .collection('restaurants')
        .doc(restaurantId)
        .get();
      
      const restaurantData = restaurantDoc.data();
      const merchantId = restaurantData.merchantId;
      
      if (!merchantId) {
        console.error(`❌ No merchantId for restaurant ${restaurantId}`);
        return;
      }
      
      console.log(`📱 Notifying merchant: ${merchantId}`);
      
      // Send notification via HTTP call to our own function
      const message = {
        userId: merchantId,
        title: '📦 New Order Received!',
        body: `Order #${order.orderNumber.substring(0, 8)} from ${order.customerName} - RM${order.totalAmount}`,
        data: {
          type: 'new_order',
          orderId: orderId,
          restaurantId: restaurantId,
          customerName: order.customerName,
          totalAmount: order.totalAmount.toString(),
          orderNumber: order.orderNumber,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };
      
      // Call our own function
      await exports.sendNotification(
        { body: JSON.stringify(message) },
        { json: (data) => console.log('Auto-notification sent:', data) }
      );
      
    } catch (error) {
      console.error('❌ Error in onNewOrder:', error);
    }
  });

// Trigger when order status is updated
exports.onOrderStatusUpdate = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const orderId = context.params.orderId;
      
      // Only if status changed
      if (before.status === after.status) return;
      
      console.log(`🔄 Order ${orderId} status: ${before.status} → ${after.status}`);
      
      // Status messages
      const statusMessages = {
        'confirmed': { title: '✅ Order Confirmed', body: 'Restaurant has confirmed your order' },
        'preparing': { title: '👨‍🍳 Order Preparing', body: 'Your order is being prepared' },
        'ready': { title: '🚀 Order Ready!', body: 'Your order is ready for pickup' },
        'completed': { title: '🎉 Order Completed', body: 'Thank you for your order!' },
        'cancelled': { title: '❌ Order Cancelled', body: 'Your order has been cancelled' },
        'picked_up_by_customer': { title: '📱 Pickup Confirmed', body: 'Customer confirmed pickup' },
      };
      
      const messageInfo = statusMessages[after.status] || {
        title: 'Order Updated',
        body: `Status: ${after.status}`
      };
      
      // Determine who to notify
      let userId = '';
      let additionalData = {};
      
      if (['confirmed', 'preparing', 'ready', 'completed', 'cancelled'].includes(after.status)) {
        // Notify customer
        userId = after.customerId;
        additionalData = {
          type: 'order_status_update',
          orderId: orderId,
          oldStatus: before.status,
          newStatus: after.status,
          orderNumber: after.orderNumber,
        };
      } else if (after.status === 'picked_up_by_customer') {
        // Notify merchant
        userId = after.restaurantId; // Actually need merchantId
        const restaurantDoc = await admin.firestore()
          .collection('restaurants')
          .doc(after.restaurantId)
          .get();
        userId = restaurantDoc.data().merchantId;
        
        additionalData = {
          type: 'customer_pickup_confirmation',
          orderId: orderId,
          customerName: after.customerName,
          orderNumber: after.orderNumber,
        };
      }
      
      if (!userId) return;
      
      // Send notification
      const message = {
        userId: userId,
        title: messageInfo.title,
        body: `${messageInfo.body} - Order #${after.orderNumber.substring(0, 8)}`,
        data: {
          ...additionalData,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };
      
      // Call our own function
      await exports.sendNotification(
        { body: JSON.stringify(message) },
        { json: (data) => console.log('Status notification sent:', data) }
      );
      
    } catch (error) {
      console.error('❌ Error in onOrderStatusUpdate:', error);
    }
  });