# Deployment Guide for QuickHelp App

## Prerequisites
- GitHub account
- Vercel account
- Supabase project

## Step 1: Create GitHub Repository

1. Go to [GitHub](https://github.com) and create a new repository
2. Name it `quickhelp-app` (or any name you prefer)
3. **DO NOT** initialize with README, .gitignore, or license (we already have these)
4. Copy the repository URL

## Step 2: Push to GitHub

Run these commands (replace `YOUR_USERNAME` and `REPO_NAME` with your actual values):

```bash
git remote add origin https://github.com/YOUR_USERNAME/REPO_NAME.git
git branch -M main
git push -u origin main
```

## Step 3: Deploy to Vercel

1. Go to [Vercel](https://vercel.com) and sign in
2. Click "Add New Project"
3. Import your GitHub repository
4. Configure the project:
   - **Framework Preset**: Other
   - **Build Command**: `flutter build web --release`
   - **Output Directory**: `build/web`
   - **Install Command**: `flutter pub get`
5. Click "Deploy"

## Step 4: Configure Supabase Redirect URL

**IMPORTANT**: This fixes the password reset redirect issue!

1. Go to your Supabase project dashboard
2. Navigate to **Authentication** > **URL Configuration**
3. Add your Vercel URL to **Redirect URLs**:
   ```
   https://your-app-name.vercel.app/reset-password
   https://your-app-name.vercel.app/**
   ```
4. Also add to **Site URL**:
   ```
   https://your-app-name.vercel.app
   ```
5. Save the changes

## Step 5: Update Code with Your Vercel URL

After deploying to Vercel, update `lib/services/auth_service.dart`:

Replace `quickhelp-app.vercel.app` with your actual Vercel deployment URL in the `_redirectUrl` getter.

## Troubleshooting

### Password Reset Not Working
- Make sure the Supabase redirect URL matches your Vercel deployment URL exactly
- Check that `/reset-password` is included in the redirect URL
- Verify the URL in Supabase settings matches what's in the code

### Build Errors on Vercel
- Make sure Flutter is installed in the build environment
- Check that `vercel.json` is in the root directory
- Verify build command: `flutter build web --release`


