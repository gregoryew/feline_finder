r# Configuration

## API Keys

The app uses a centralized configuration system. All API keys and configuration values are defined in `lib/config.dart`.

### Current Configuration

- **RescueGroups API Key**: `eqXAy6VJ`
- **YouTube API Key**: `AIzaSyBGj_Duj__ivCxJ2ya3ilkVfEzX1ZSRlpE`
- **Google Maps API Key**: `AIzaSyBNEcaJtpfNh1ako5P_XexuILvjnPlscdE`
- **Default Zip Code**: `94043`
- **Default Distance**: `1000` miles

### External Service URLs

- **Wikipedia API**: `https://en.wikipedia.org/w/api.php` (public, no key required)
- **Zippopotam API**: `https://api.zippopotam.us/us` (public, no key required)
- **RescueGroups API**: `https://api.rescuegroups.org/v5/public`
- **YouTube API**: `https://www.googleapis.com/youtube/v3`

### Default Image URLs

- **Default Cat Image**: `https://upload.wikimedia.org/wikipedia/commons/6/65/No-Image-Placeholder.svg`
- **Placeholder Image**: `https://via.placeholder.com/200x90.png?text=Cat+Image+Not+Available`

### How to Update Configuration

1. Edit `lib/config.dart`
2. Update the constants as needed
3. The changes will be applied across all screens that use the API

### Files Using Configuration

- `lib/screens/adoptGrid.dart` - Main pet grid (RescueGroups API)
- `lib/screens/petDetail.dart` - Pet detail page (RescueGroups API)
- `lib/screens/breedDetail.dart` - Breed detail page (RescueGroups API, Wikipedia API)
- `lib/utils/constants.dart` - YouTube API key
- `lib/widgets/toolbar.dart` - Google Maps API key
- `lib/screens/globals.dart` - Zippopotam API for zip code validation

### Migration from .env File

The app previously used `.env` file parsing, but this has been replaced with the centralized configuration system. All API keys and URLs are now defined in code rather than external files.

### Benefits

- **Single Source of Truth**: All API keys and URLs in one place
- **Easy Updates**: Change configuration in one file, affects entire app
- **Version Control Safe**: Configuration is in code, not external files
- **Error Handling**: Graceful fallbacks when services fail
- **Documentation**: Clear instructions for future updates
