# Web Image Loading Issue (CORS)

## Problem

When running the Flutter app on Chrome (web), cat images from RescueGroups CDN fail to load with:

```
HTTP request failed, statusCode: 0
https://cdn.rescuegroups.org/.../pictures/...
```

## Root Cause

**CORS (Cross-Origin Resource Sharing)** - The RescueGroups CDN server doesn't include the necessary CORS headers to allow images to be loaded from web browsers on different domains.

- ✅ **Works on:** iOS, Android (native mobile apps)
- ❌ **Fails on:** Web browsers (Chrome, Firefox, Safari, etc.)

## Why This Happens

1. Web browsers enforce Same-Origin Policy for security
2. To load images from `cdn.rescuegroups.org`, the CDN must send CORS headers:
   - `Access-Control-Allow-Origin: *` (or specific domain)
3. RescueGroups CDN does not send these headers
4. Browser blocks the image load

## Solutions

### Option 1: Proxy Images Through Your Server (Recommended)
Create a backend proxy that fetches images and serves them with proper CORS headers:

```typescript
// Firebase Function
export const proxyImage = functions.https.onRequest(async (req, res) => {
  const imageUrl = req.query.url;
  
  // Fetch image from RescueGroups
  const response = await fetch(imageUrl);
  const buffer = await response.buffer();
  
  // Serve with CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Content-Type', response.headers.get('content-type'));
  res.send(buffer);
});
```

Then change image URLs:
```dart
// From:
imageUrl: 'https://cdn.rescuegroups.org/...'

// To:
imageUrl: 'https://your-domain.com/proxyImage?url=https://cdn.rescuegroups.org/...'
```

### Option 2: Use CachedNetworkImage with Headers
This doesn't solve CORS but handles errors better:

```dart
CachedNetworkImage(
  imageUrl: widget.catImageUrl!,
  httpHeaders: const {
    'User-Agent': 'FelineFinder/1.0',
  },
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.pets),
)
```

### Option 3: Contact RescueGroups
Request that they add CORS headers to their CDN:
- `Access-Control-Allow-Origin: *`
- This would fix it for all web apps

### Option 4: Platform-Specific Image Widget
Show different widgets for web vs mobile:

```dart
import 'package:flutter/foundation.dart';

Widget buildImage(String? url) {
  if (kIsWeb) {
    // On web, show placeholder or use proxy
    return Icon(Icons.pets);
  } else {
    // On mobile, load normally
    return Image.network(url ?? '');
  }
}
```

### Option 5: Use Base64 Encoded Images
Fetch image on backend, encode to base64, send to frontend:

```dart
Image.memory(base64Decode(imageData))
```

## Current Workaround

The `errorBuilder` in the scheduling dialog already handles this gracefully:

```dart
errorBuilder: (context, error, stackTrace) {
  return Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      Icons.pets,
      color: Colors.grey[600],
      size: 30,
    ),
  );
}
```

So on web, users see a pet icon instead of the cat photo. **This is not a bug in your code** - it's a limitation of web security and the CDN configuration.

## Testing

- ✅ **To test mobile behavior:** Use iOS or Android emulator/device
- ⚠️ **On Chrome:** Images will show fallback icons (expected behavior)

## Recommendation

For production web deployment:
1. Implement **Option 1** (image proxy) for best user experience
2. Cache proxied images to reduce backend load
3. Keep current error handling as fallback

## Impact

- **Mobile apps:** No impact (images load fine)
- **Web app:** Shows placeholder icons instead of cat photos
- **Scheduling dialog:** Falls back to pet icon gracefully
- **User experience:** Acceptable with fallback, optimal with proxy

## Files Affected

- `lib/widgets/schedule_appointment.dart` - Has error handling ✅
- `lib/screens/petDetail.dart` - Uses CachedNetworkImage ✅
- `lib/screens/adoptGrid.dart` - Uses NetworkImage ⚠️

All image loading already has error handling, so the app won't crash on web.







