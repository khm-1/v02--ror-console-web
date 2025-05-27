# Session Management Features for Console

The console now supports multiple concurrent sessions with isolated variables and history.

## New Routes Added:

- `POST /console/new_session` - Create a new console session
- `GET /console/session_list` - List all console sessions
- `PUT /console/select_session/:session_id` - Switch to a different session
- `DELETE /console/close_session/:session_id` - Close a session

## Features:

1. **New Session**: Create multiple console sessions with custom names
2. **Session List**: View all sessions with their status (active/inactive), command count, variable count
3. **Select Session**: Switch between different sessions to work in isolated environments  
4. **Close Session**: Close sessions when no longer needed (cannot close the last session)

## Session Isolation:

- Each session maintains its own variable scope
- Command history is isolated per session
- Variables set in one session are not accessible in others
- The `vars` helper shows variables for the current session only
- `clear_history` only affects the current session

## Usage Examples:

```javascript
// Create a new session
POST /console/new_session
{
  "name": "My Debug Session"
}

// List all sessions
GET /console/session_list

// Switch to a session
PUT /console/select_session/abc123

// Close a session  
DELETE /console/close_session/abc123
```

## Implementation Status:

✅ Routes added
✅ New session creation
✅ Session listing
✅ Session switching
✅ Session closing
✅ Variable isolation
⚠️  Variable persistence (debugging in progress)

## Current Issue:

There's an issue with variable persistence where variables are being stored correctly but not retrieved properly when switching between sessions. This is being debugged.

## Next Steps:

1. Fix variable persistence issue
2. Add session management UI components
3. Add session persistence across browser restarts
4. Add session import/export functionality
