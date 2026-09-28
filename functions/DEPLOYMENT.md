# Firebase Cloud Functions Deployment Guide

This project includes scheduled cloud functions for automated daily data entry, weather forecasts, and push notifications:
- **`dailyCommuteInsert`**: Runs everyday at **7:00 AM** (`Asia/Dhaka`). Inserts **CNG (৳80.00)** and **Metro (৳36.00)** into Firestore.
- **`dailyWeatherNotify`**: Runs everyday at **9:00 AM** (`Asia/Dhaka`). Fetches today's hourly weather forecast via the Google Maps Weather API and dispatches an FCM Push Notification highlighting rain prediction (with timings/probabilities) and daytime temperature range.
- **`dailyCommuteNotify`**: Runs everyday at **9:30 AM** (`Asia/Dhaka`). Dispatches FCM Push Notification (`"Data Entry Successful"`).
- **`triggerCommuteManual`**: HTTP endpoint for instant on-demand testing of commute insert / notify / weather.
- **`triggerWeatherManual`**: HTTP endpoint for instant on-demand testing of the 9:00 AM Weather Push Notification.

---

## 1. Environment Configuration (.env)
The Google Maps Weather API key is configured inside `functions/.env` (and root `.env`):
```env
GOOGLE_MAPS_WEATHER_API_KEY=AIzaSyDL74SeFRnARBeIT_wmqeHMDk8PlI4_oNY
DEFAULT_LATITUDE=23.8103
DEFAULT_LONGITUDE=90.4125
DEFAULT_TIMEZONE=Asia/Dhaka
```
Firebase Functions v2 automatically deploys and reads secrets/environment variables from `functions/.env`.

---

## 2. Deploy Functions
From the project root:
```bash
firebase use expnz-123
cd functions
npm install
cd ..
firebase deploy --only functions
```

---

## 3. Instant Manual Testing
Once deployed, you can trigger notifications anytime using the HTTPS endpoints:
```bash
# 1. Trigger 9:00 AM Weather Notification immediately
curl https://<region>-expnz-123.cloudfunctions.net/triggerWeatherManual

# 2. Trigger Commute Insert and Notification
curl https://<region>-expnz-123.cloudfunctions.net/triggerCommuteManual?action=both

# 3. Trigger all (commute + weather)
curl "https://<region>-expnz-123.cloudfunctions.net/triggerCommuteManual?action=both&weather=true"
```

