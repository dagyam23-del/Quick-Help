# QuickHelp - Micro-Volunteering App

A Flutter mobile app for students to post quick help requests and volunteer to help others. Built with Flutter and Supabase backend.

## 📱 Features

- **Authentication**: Email/password sign up and login
- **Post Requests**: Create help requests (e.g., borrow calculator, need notes)
- **View Requests**: Browse all open requests on the home screen with real-time updates
- **Volunteer**: Click "I Can Help" to volunteer for a request
- **Real-time Chat**: Chat with requester/helper once a request is taken
- **Status Tracking**: Track request status (open, taken, completed)

## 🚀 Setup Instructions

### Prerequisites

- Flutter SDK (latest stable version)
- Supabase account (free tier works)
- Android Studio / VS Code with Flutter extensions

### Step 1: Supabase Setup

1. **Create a Supabase Project**
   - Go to [supabase.com](https://supabase.com)
   - Create a new project
   - Wait for the project to be ready

2. **Run Database Setup**
   - In Supabase Dashboard, go to **SQL Editor**
   - Copy and paste the contents of `supabase_setup.sql`
   - Click **Run** to execute the SQL

3. **Enable Authentication**
   - Go to **Authentication > Providers > Email**
   - Enable **Email** provider
   - **IMPORTANT for Development**: Disable **"Confirm email"** checkbox
     - This allows users to sign up without email confirmation
     - Essential for localhost development
   - Configure email templates if needed (optional)

4. **Enable Realtime (for chat)**
   - Go to **Database > Replication** in Supabase Dashboard
   - Enable replication for `messages` table (required for real-time chat)
   - Enable replication for `requests` table (optional, for real-time request updates)

5. **Get Your API Keys**
   - Go to **Settings > API**
   - Copy your **Project URL** and **anon/public key**

### Step 2: Flutter Setup

1. **Clone/Download this project**

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Open `lib/main.dart`
   - Replace `YOUR_SUPABASE_URL` with your Supabase Project URL
   - Replace `YOUR_SUPABASE_ANON_KEY` with your Supabase anon key

   ```dart
   const supabaseUrl = 'https://your-project.supabase.co';
   const supabaseAnonKey = 'your-anon-key-here';
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

   For web:
   ```bash
   flutter run -d chrome
   ```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point and configuration
├── models/
│   ├── request.dart         # Request data model
│   └── message.dart         # Message data model
├── services/
│   ├── auth_service.dart    # Authentication service
│   ├── request_service.dart # Request CRUD operations
│   └── message_service.dart # Chat message operations
└── screens/
    ├── auth_screen.dart     # Login/Signup screen
    ├── home_screen.dart     # List of requests
    ├── create_request_screen.dart  # Create new request
    └── request_detail_screen.dart   # Request details + chat
```

## 🗄️ Database Schema

### `requests` Table
- `id` (UUID, Primary Key)
- `title` (Text)
- `description` (Text)
- `status` (Text: 'open', 'taken', 'completed')
- `requester_id` (UUID → auth.users)
- `helper_id` (UUID → auth.users, nullable)
- `created_at` (Timestamp)

### `messages` Table
- `id` (UUID, Primary Key)
- `request_id` (UUID → requests.id)
- `sender_id` (UUID → auth.users)
- `message` (Text)
- `created_at` (Timestamp)

## 🔒 Security (RLS Policies)

- **Requests**: 
  - Anyone can create requests
  - Anyone can view open requests
  - Only requester and helper can view taken/completed requests
  - Only requester can update their own requests
  - Anyone can volunteer (update helper_id and status to 'taken')
  - Requester or helper can mark request as completed

- **Messages**: 
  - Only requester and helper can read/send messages for a request
  - Messages can only be sent once a request is taken (has a helper)

## 🎨 App Flow

1. **Sign Up/Login**: User creates account or logs in
2. **Home Screen**: Displays all open requests with real-time updates
3. **Create Request**: User can post a new help request
4. **View Details**: Tap a request to see details
5. **Volunteer**: Click "I Can Help" to volunteer
6. **Chat**: Once taken, requester and helper can chat in real-time
7. **Complete**: Either party can mark the request as completed

## 🛠️ Technologies Used

- **Flutter**: UI framework
- **Supabase**: Backend (Auth, Database, Real-time)
- **Provider**: State management
- **Material Design**: UI components

## 📝 Notes

- The app uses Supabase's real-time subscriptions for live chat updates
- User names are stored in Supabase auth metadata
- All database operations are secured with Row Level Security (RLS)
- The app is designed to be simple and school-project friendly
- Email confirmation is disabled by default for easier development

## 🐛 Troubleshooting

**Issue**: "Failed to initialize Supabase"
- **Solution**: Make sure you've updated the URL and anon key in `main.dart`

**Issue**: "Authentication failed"
- **Solution**: Check that Email provider is enabled in Supabase Dashboard

**Issue**: "Permission denied" errors
- **Solution**: Verify that RLS policies were created correctly in Supabase

**Issue**: Real-time updates not working
- **Solution**: Ensure Supabase Realtime is enabled for your tables in Dashboard

**Issue**: Users not saving after signup
- **Solution**: Disable email confirmation in Supabase (Authentication > Providers > Email)

## 📚 Learning Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/flutter)
- [Supabase RLS Guide](https://supabase.com/docs/guides/auth/row-level-security)

## 🎓 For School Projects

This app demonstrates:
- Full-stack mobile app development
- Authentication and authorization
- Real-time database operations
- RESTful API usage
- State management
- Material Design UI
- Database security (RLS policies)

## 📄 License

This project is created for educational purposes.
