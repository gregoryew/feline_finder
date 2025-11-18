# How to Connect to an Existing GitHub Repository on a New Computer

## Scenario 1: Clone the Repository Fresh

If you don't have the repository on this computer yet:

```bash
# Navigate to where you want the project
cd ~/Projects  # or wherever you keep projects

# Clone the repository
git clone https://github.com/gregoryew/feline_finder.git
cd feline_finder
```

## Scenario 2: Repository Already Exists (Your Current Situation)

You already have the repository. You just need to set up authentication.

## Authentication Methods

### Method 1: Personal Access Token (HTTPS) - Recommended for Beginners

1. **Create a Personal Access Token on GitHub:**
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token (classic)"
   - Give it a name like "MacBook Air Development"
   - Select expiration (90 days, 1 year, or no expiration)
   - Check the `repo` scope (gives full access to repositories)
   - Click "Generate token"
   - **COPY THE TOKEN IMMEDIATELY** (you won't see it again!)

2. **Use the token when pushing:**
   ```bash
   git push
   # When prompted:
   # Username: gregoryew
   # Password: <paste your token here>
   ```

3. **Store credentials (optional but recommended):**
   ```bash
   git config --global credential.helper osxkeychain
   ```
   This will save your credentials in macOS Keychain so you don't have to enter them every time.

### Method 2: SSH Keys (More Secure, Better for Long-term)

1. **Check if you already have SSH keys:**
   ```bash
   ls -la ~/.ssh/id_*.pub
   ```

2. **If no keys exist, generate one:**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   # Press Enter to accept default location
   # Optionally set a passphrase (recommended)
   ```

3. **Copy your public key:**
   ```bash
   cat ~/.ssh/id_ed25519.pub
   # Copy the entire output
   ```

4. **Add the key to GitHub:**
   - Go to: https://github.com/settings/keys
   - Click "New SSH key"
   - Title: "MacBook Air" (or whatever describes this computer)
   - Key: Paste your public key
   - Click "Add SSH key"

5. **Switch repository to use SSH:**
   ```bash
   git remote set-url origin git@github.com:gregoryew/feline_finder.git
   ```

6. **Test the connection:**
   ```bash
   ssh -T git@github.com
   # Should see: "Hi gregoryew! You've successfully authenticated..."
   ```

7. **Now you can push without entering credentials:**
   ```bash
   git push
   ```

### Method 3: GitHub CLI (gh) - Easiest if Available

1. **Install GitHub CLI:**
   ```bash
   brew install gh
   ```

2. **Authenticate:**
   ```bash
   gh auth login
   # Follow the prompts to authenticate
   ```

3. **Push:**
   ```bash
   git push
   ```

## Verify Your Setup

```bash
# Check remote URL
git remote -v

# Check git user configuration
git config user.name
git config user.email

# Test connection (for SSH)
ssh -T git@github.com

# Or test by fetching
git fetch origin
```

## Common Issues

### "Permission denied (publickey)"
- Your SSH key isn't added to GitHub
- Or you're using HTTPS but need to use a token instead of password

### "fatal: could not read Username"
- You need to authenticate
- Use a Personal Access Token for HTTPS
- Or set up SSH keys

### "Repository not found"
- Check the repository URL is correct
- Verify you have access to the repository
- Make sure you're authenticated

## Quick Setup Checklist

- [ ] Repository cloned or already exists locally
- [ ] Git user name configured: `git config --global user.name "Your Name"`
- [ ] Git user email configured: `git config --global user.email "your.email@example.com"`
- [ ] Remote URL is correct: `git remote -v`
- [ ] Authentication method chosen (Token, SSH, or GitHub CLI)
- [ ] Credentials configured and tested
- [ ] Can successfully push: `git push`

