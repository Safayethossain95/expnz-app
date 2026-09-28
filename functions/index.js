const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid");

admin.initializeApp();
const db = admin.firestore();

const TIMEZONE = process.env.DEFAULT_TIMEZONE || "Asia/Dhaka";
const GOOGLE_MAPS_WEATHER_API_KEY = process.env.GOOGLE_MAPS_WEATHER_API_KEY;
const DEFAULT_LAT = parseFloat(process.env.DEFAULT_LATITUDE || "23.8103");
const DEFAULT_LNG = parseFloat(process.env.DEFAULT_LONGITUDE || "90.4125");

/**
 * 1. 7:00 AM Daily Job:
 * Inserts 2 commute expenses (CNG vara ৳80 & Metro vara ৳36) for all enabled users
 */
exports.dailyCommuteInsert = onSchedule(
  {
    schedule: "0 7 * * *",
    timeZone: TIMEZONE,
    retryCount: 3,
  },
  async (event) => {
    logger.info("Executing dailyCommuteInsert at 7:00 AM...");
    await processCommuteInsertion();
  }
);

/**
 * 2. 9:00 AM Daily Job:
 * Sends Daily Weather Push Notification (Rain prediction with times & Temperature range)
 */
exports.dailyWeatherNotify = onSchedule(
  {
    schedule: "0 9 * * *",
    timeZone: TIMEZONE,
    retryCount: 3,
  },
  async (event) => {
    logger.info("Executing dailyWeatherNotify at 9:00 AM...");
    await processWeatherNotification();
  }
);

/**
 * 3. 9:30 AM Daily Job:
 * Sends Push Notification to all users who had commute entries inserted
 */
exports.dailyCommuteNotify = onSchedule(
  {
    schedule: "30 9 * * *",
    timeZone: TIMEZONE,
    retryCount: 3,
  },
  async (event) => {
    logger.info("Executing dailyCommuteNotify at 9:30 AM...");
    await processCommuteNotification();
  }
);

/**
 * 4. Manual HTTPS Trigger for instant commute testing from browser or curl
 * GET https://<region>-<project-id>.cloudfunctions.net/triggerCommuteManual?action=insert|notify|weather|both
 */
exports.triggerCommuteManual = onRequest(async (req, res) => {
  const action = req.query.action || "both";
  const results = {};

  try {
    if (action === "insert" || action === "both") {
      results.insert = await processCommuteInsertion();
    }
    if (action === "notify" || action === "both") {
      results.notify = await processCommuteNotification();
    }
    if (action === "weather" || action === "both") {
      results.weather = await processWeatherNotification();
    }
    res.json({ success: true, action, results });
  } catch (error) {
    logger.error("Error in triggerCommuteManual:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * 5. Manual HTTPS Trigger for instant 9 AM weather push notification testing
 * GET https://<region>-<project-id>.cloudfunctions.net/triggerWeatherManual
 */
exports.triggerWeatherManual = onRequest(async (req, res) => {
  try {
    const lat = req.query.lat ? parseFloat(req.query.lat) : undefined;
    const lng = req.query.lng ? parseFloat(req.query.lng) : undefined;
    const targetUserId = req.query.userId;
    const result = await processWeatherNotification({ lat, lng, targetUserId });
    res.json({ success: true, ...result });
  } catch (error) {
    logger.error("Error in triggerWeatherManual:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Helper: Insert commute items into Firestore
 */
async function processCommuteInsertion() {
  const now = new Date();
  const todayStr = now.toISOString().split("T")[0]; // YYYY-MM-DD
  const batchId = `commute_${todayStr}`;

  const usersSnapshot = await db.collection("users").get();
  let updatedUsersCount = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;

    // Check user's commute automation settings
    const settingsDoc = await db
      .collection("users")
      .doc(userId)
      .collection("settings")
      .doc("commute_automation")
      .get();

    // Default items
    let enabled = true;
    let items = [
      { category: "travel", description: "cng vara", amount: 80.0 },
      { category: "travel", description: "metro vara", amount: 36.0 },
    ];

    if (settingsDoc.exists) {
      const config = settingsDoc.data();
      if (config.enabled === false) continue;
      if (config.lastInsertedDate === todayStr) {
        logger.info(`User ${userId} already has commute entries for ${todayStr}. Skipping.`);
        continue;
      }
      if (Array.isArray(config.items) && config.items.length > 0) {
        items = config.items;
      }
    }

    // Read current expenses document
    const expensesRef = db.collection("users").doc(userId).collection("data").doc("expenses");
    const expensesDoc = await expensesRef.get();

    let currentItems = [];
    if (expensesDoc.exists && expensesDoc.data() && Array.isArray(expensesDoc.data().items)) {
      currentItems = expensesDoc.data().items;
    }

    // Avoid duplicate insertions for the same batch
    const alreadyExists = currentItems.some((e) => e.batchId === batchId);
    if (alreadyExists) {
      continue;
    }

    // Prepare 2 new expense items
    const newItems = items.map((t) => ({
      id: uuidv4(),
      date: now.toISOString(),
      category: t.category || "travel",
      description: t.description || "commute",
      amount: Number(t.amount) || 0,
      isPlaceholder: false,
      createdAt: now.toISOString(),
      batchId: batchId,
    }));

    // Insert before placeholders if any
    const firstPlaceholderIndex = currentItems.findIndex((e) => e.isPlaceholder === true);
    if (firstPlaceholderIndex !== -1) {
      currentItems.splice(firstPlaceholderIndex, 0, ...newItems);
    } else {
      currentItems.push(...newItems);
    }

    // Write back to Firestore
    await expensesRef.set(
      {
        items: currentItems,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Update settings with lastInsertedDate & pendingReviewBatchId
    await db
      .collection("users")
      .doc(userId)
      .collection("settings")
      .doc("commute_automation")
      .set(
        {
          enabled: true,
          lastInsertedDate: todayStr,
          pendingReviewBatchId: batchId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    updatedUsersCount++;
  }

  logger.info(`Inserted commute entries for ${updatedUsersCount} user(s).`);
  return { updatedUsersCount, batchId, todayStr };
}

/**
 * Helper: Send Push Notification via Firebase Cloud Messaging (FCM)
 */
async function processCommuteNotification() {
  const now = new Date();
  const todayStr = now.toISOString().split("T")[0];
  const batchId = `commute_${todayStr}`;

  const usersSnapshot = await db.collection("users").get();
  let notificationsSent = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();

    const fcmToken = userData.fcmToken;
    if (!fcmToken) {
      logger.info(`User ${userId} does not have an FCM token registered.`);
      continue;
    }

    // Check if this user has pending commute review
    const settingsDoc = await db
      .collection("users")
      .doc(userId)
      .collection("settings")
      .doc("commute_automation")
      .get();

    if (settingsDoc.exists) {
      const config = settingsDoc.data();
      if (config.enabled === false) continue;
      if (config.pendingReviewBatchId !== batchId) {
        // Already reviewed or not inserted
        continue;
      }
    }

    // Send FCM Push Notification
    const message = {
      token: fcmToken,
      notification: {
        title: "Daily Commute Entries Added",
        body: "Data entry successful: CNG (৳80) & Metro (৳36) added for today. Tap to review.",
      },
      data: {
        type: "commute_review",
        batchId: batchId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "commute_channel",
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
    };

    try {
      await admin.messaging().send(message);
      notificationsSent++;
      logger.info(`FCM notification sent successfully to user ${userId}`);
    } catch (err) {
      logger.error(`Failed to send FCM to user ${userId}:`, err);
    }
  }

  return { notificationsSent, batchId };
}

/**
 * Helper: Fetch 24-hour weather forecast from Google Maps Weather API
 */
async function fetchWeatherForecast(lat, lng, apiKey) {
  const key = apiKey || GOOGLE_MAPS_WEATHER_API_KEY;
  if (!key) {
    throw new Error(
      "Google Maps Weather API key is not configured in environment (GOOGLE_MAPS_WEATHER_API_KEY)"
    );
  }

  const url = `https://weather.googleapis.com/v1/forecast/hours:lookup?key=${key}&location.latitude=${lat}&location.longitude=${lng}&hours=24`;
  const response = await fetch(url);
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Google Maps Weather API error (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  return data.forecastHours || [];
}

/**
 * Helper: Format human-friendly weather summary highlighting rain times and temperatures
 */
function formatWeatherSummary(hours) {
  if (!hours || hours.length === 0) {
    return {
      title: "⛅ Today's Weather Update",
      body: "Weather information is currently unavailable.",
      minTemp: null,
      maxTemp: null,
      hasRain: false,
    };
  }

  let minTemp = Infinity;
  let maxTemp = -Infinity;
  let peakHour = null;
  const rainSlots = [];

  function formatTime(h) {
    const period = h >= 12 ? "PM" : "AM";
    const hour12 = h % 12 === 0 ? 12 : h % 12;
    return `${hour12}:00 ${period}`;
  }

  for (const h of hours) {
    const hourNum = h.displayDateTime?.hours ?? 0;
    const temp = Math.round(h.temperature?.degrees ?? 0);
    const rainProb = h.precipitation?.probability?.percent ?? 0;
    const desc = (h.weatherCondition?.description?.text || "").toLowerCase();

    if (temp > maxTemp) {
      maxTemp = temp;
      peakHour = hourNum;
    }
    if (temp < minTemp) {
      minTemp = temp;
    }

    if (
      rainProb >= 25 ||
      desc.includes("rain") ||
      desc.includes("shower") ||
      desc.includes("thunder") ||
      desc.includes("drizzle")
    ) {
      rainSlots.push({
        hour: hourNum,
        prob: rainProb,
        condition: h.weatherCondition?.description?.text || "Rain",
      });
    }
  }

  let rainSummary = "";
  const hasRain = rainSlots.length > 0;
  if (hasRain) {
    const maxRain = rainSlots.reduce(
      (prev, curr) => (curr.prob > prev.prob ? curr : prev),
      rainSlots[0]
    );
    const times = rainSlots.slice(0, 3).map((r) => formatTime(r.hour)).join(", ");
    rainSummary = `🌧️ Rain expected around ${times} (up to ${maxRain.prob}% at ${formatTime(maxRain.hour)}).`;
  } else {
    rainSummary = "☀️ No rain expected today.";
  }

  const peakText = peakHour !== null ? ` (Peak ${maxTemp}°C at ${formatTime(peakHour)})` : "";
  const tempSummary = `🌡️ ${minTemp}°C - ${maxTemp}°C${peakText}.`;

  const title = "⛅ Today's Weather (9 AM Forecast)";
  const body = `${rainSummary} ${tempSummary}`;

  return {
    title,
    body,
    minTemp,
    maxTemp,
    peakHour,
    hasRain,
    rainSlots,
  };
}

/**
 * Helper: Process and send Daily 9:00 AM Weather Push Notification to users via FCM
 */
async function processWeatherNotification(options = {}) {
  const { lat = DEFAULT_LAT, lng = DEFAULT_LNG, targetUserId = null } = options;

  logger.info(`Fetching weather forecast for lat: ${lat}, lng: ${lng}...`);
  const hours = await fetchWeatherForecast(lat, lng);
  const summary = formatWeatherSummary(hours);

  logger.info(`Weather Summary generated: "${summary.title}" - "${summary.body}"`);

  let usersQuery = db.collection("users");
  if (targetUserId) {
    usersQuery = usersQuery.where(admin.firestore.FieldPath.documentId(), "==", targetUserId);
  }

  const usersSnapshot = await usersQuery.get();
  let notificationsSent = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      logger.info(`User ${userId} does not have an FCM token registered.`);
      continue;
    }

    // Check if user disabled weather notifications specifically
    const weatherSettingsDoc = await db
      .collection("users")
      .doc(userId)
      .collection("settings")
      .doc("weather_automation")
      .get();

    if (weatherSettingsDoc.exists) {
      const wConfig = weatherSettingsDoc.data();
      if (wConfig.enabled === false) {
        logger.info(`Weather notification disabled for user ${userId}. Skipping.`);
        continue;
      }
    }

    const message = {
      token: fcmToken,
      notification: {
        title: summary.title,
        body: summary.body,
      },
      data: {
        type: "weather",
        minTemp: String(summary.minTemp),
        maxTemp: String(summary.maxTemp),
        hasRain: String(summary.hasRain),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "weather_channel",
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
    };

    try {
      await admin.messaging().send(message);
      notificationsSent++;
      logger.info(`Weather FCM notification sent successfully to user ${userId}`);
    } catch (err) {
      logger.error(`Failed to send Weather FCM to user ${userId}:`, err);
    }
  }

  return {
    notificationsSent,
    weatherSummary: summary,
    coordinates: { lat, lng },
  };
}

