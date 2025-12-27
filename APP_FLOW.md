# QuickHelp App Flow Explanation

## 📱 Application Architecture

### Overview
QuickHelp is a micro-volunteering app that connects students who need help with students who can provide help. The app uses Supabase as the backend for authentication, database, and real-time features.

---

## 🔄 User Flow

### 1. Authentication Flow

**Sign Up:**
1. User enters name, email, and password
2. `AuthService.signUp()` creates account in Supabase
3. User is automatically signed in (if email confirmation is disabled)
4. User is redirected to Home Screen

**Sign In:**
1. User enters email and password
2. `AuthService.signIn()` authenticates with Supabase
3. On success, user is redirected to Home Screen

**Sign Out:**
1. User clicks logout button
2. `AuthService.signOut()` clears session
3. User is redirected to Auth Screen

---

### 2. Request Creation Flow

1. User clicks "New Request" button on Home Screen
2. Navigates to `CreateRequestScreen`
3. User fills in title and description
4. `RequestService.createRequest()` inserts new request into database
5. Request is created with status 'open'
6. User is redirected back to Home Screen
7. New request appears in the list (real-time update)

---

### 3. Viewing Requests Flow

1. Home Screen displays all open requests
2. Uses `RequestService.watchOpenRequests()` stream
3. Real-time updates when new requests are created
4. Each request shows:
   - Title
   - Description
   - Requester name
5. User can tap a request to see details

---

### 4. Volunteering Flow

1. User taps on an open request
2. Navigates to `RequestDetailScreen`
3. User sees "I Can Help" button
4. User clicks button
5. `RequestService.volunteerForRequest()` updates:
   - `status`: 'open' → 'taken'
   - `helper_id`: current user's ID
6. Request disappears from home screen (status changed)
7. Chat section becomes available

---

### 5. Chat Flow

1. Once a request is taken (has helper), chat becomes available
2. Both requester and helper can see chat section
3. Uses `MessageService.watchMessages()` for real-time updates
4. User types message and clicks send
5. `MessageService.sendMessage()` inserts message into database
6. Message appears in real-time for both users
7. Messages are scoped to the specific request

---

### 6. Completion Flow

1. After helping, either requester or helper can mark request complete
2. User clicks "Mark as Completed" button
3. `RequestService.completeRequest()` updates status to 'completed'
4. Request is no longer visible in open requests list

---

## 🗄️ Database Operations

### Requests Table
- **Create**: Anyone can create (INSERT with RLS)
- **Read**: Anyone can read open requests; only requester/helper can read taken/completed
- **Update**: 
  - Requester can update their own requests
  - Anyone can volunteer (update helper_id and status)
  - Requester/helper can mark as completed

### Messages Table
- **Create**: Only requester/helper can send messages (INSERT with RLS)
- **Read**: Only requester/helper can read messages (SELECT with RLS)
- Messages are tied to a specific request_id

---

## 🔐 Security Model

### Row Level Security (RLS)
All tables have RLS enabled with policies that:
- Allow public creation of requests
- Restrict message access to requester/helper only
- Prevent users from modifying other users' data
- Ensure only authorized users can volunteer

### Authentication
- Users must be authenticated to create requests
- Users must be authenticated to volunteer
- Users must be authenticated to send messages
- Session is managed by Supabase Auth

---

## 📡 Real-time Features

### Request Updates
- Home screen uses `watchOpenRequests()` stream
- Automatically updates when:
  - New requests are created
  - Requests are taken (status changes)
  - Requests are completed

### Chat Updates
- Chat uses `watchMessages()` stream
- Automatically updates when:
  - New messages are sent
  - Messages are received in real-time

---

## 🎨 UI Components

### Screens
1. **AuthScreen**: Login/Signup form
2. **HomeScreen**: List of open requests with FAB
3. **CreateRequestScreen**: Form to create new request
4. **RequestDetailScreen**: Request details + chat interface

### State Management
- Uses Provider for dependency injection
- Services are provided at app level
- Screens access services via Provider

---

## 🔧 Key Services

### AuthService
- Handles user authentication
- Manages user sessions
- Provides user information

### RequestService
- CRUD operations for requests
- Real-time request streams
- Volunteer functionality

### MessageService
- Send messages
- Real-time message streams
- Message history

---

## 📊 Data Flow Example

**Creating a Request:**
```
User Input → CreateRequestScreen
  → RequestService.createRequest()
    → Supabase INSERT
      → RLS Policy Check
        → Database Insert
          → Real-time Event
            → HomeScreen Stream Update
              → UI Refresh
```

**Sending a Message:**
```
User Input → RequestDetailScreen
  → MessageService.sendMessage()
    → Supabase INSERT
      → RLS Policy Check
        → Database Insert
          → Real-time Event
            → Chat Stream Update
              → UI Refresh (both users)
```

---

## 🎯 Key Features Implementation

### Real-time Updates
- Uses Supabase `.stream()` for real-time subscriptions
- Automatically updates UI when data changes
- No manual refresh needed

### Security
- All operations go through RLS policies
- Users can only access their own data
- Prevents unauthorized access

### User Experience
- Clean Material Design UI
- Loading states for async operations
- Error handling with user-friendly messages
- Real-time feedback

---

## 🚀 Deployment Considerations

### For Production:
1. Enable email confirmation in Supabase
2. Configure proper redirect URLs
3. Set up email service
4. Review and test RLS policies
5. Enable proper logging
6. Set up error monitoring

### Performance:
- Indexes are created for common queries
- Real-time subscriptions are efficient
- Minimal data transfer with selective queries

---

This architecture ensures a secure, scalable, and user-friendly micro-volunteering platform.

