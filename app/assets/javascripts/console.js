// Enhanced Console JavaScript
class RailsWebConsole {
  constructor() {
    this.commandHistory = window.initialHistory || [];
    this.historyIndex = this.commandHistory.length;
    this.outputEl = document.getElementById('console-output');
    this.inputEl = document.getElementById('console-input');
    this.currentSession = Date.now();
    this.currentSessionName = null;
    
    this.initializeEventListeners();
    this.focusInput();
    this.loadCurrentSessionInfo();
  }
  
  initializeEventListeners() {
    // Input event listeners
    this.inputEl.addEventListener('keydown', (e) => this.handleKeyDown(e));
    this.inputEl.addEventListener('input', (e) => this.handleInput(e));
    
    // Window event listeners
    window.addEventListener('beforeunload', () => this.saveSession());
    
    // Focus input when clicking on console area
    this.outputEl.addEventListener('click', () => this.focusInput());
  }
  
  handleKeyDown(e) {
    switch(e.key) {
      case 'Enter':
        if (!e.shiftKey) {
          e.preventDefault();
          this.executeCommand();
        }
        break;
      case 'ArrowUp':
        e.preventDefault();
        this.navigateHistory(-1);
        break;
      case 'ArrowDown':
        e.preventDefault();
        this.navigateHistory(1);
        break;
      case 'Tab':
        e.preventDefault();
        this.handleTabCompletion();
        break;
      case 'l':
        if (e.ctrlKey) {
          e.preventDefault();
          this.clearOutput();
        }
        break;
      case 'c':
        if (e.ctrlKey) {
          e.preventDefault();
          this.cancelExecution();
        }
        break;
    }
  }
  
  handleInput(e) {
    // Auto-resize input if needed
    this.inputEl.style.height = 'auto';
    this.inputEl.style.height = this.inputEl.scrollHeight + 'px';
  }
  
  navigateHistory(direction) {
    this.historyIndex += direction;
    
    if (this.historyIndex < 0) {
      this.historyIndex = 0;
    } else if (this.historyIndex > this.commandHistory.length) {
      this.historyIndex = this.commandHistory.length;
    }
    
    if (this.historyIndex === this.commandHistory.length) {
      this.inputEl.value = '';
    } else {
      this.inputEl.value = this.commandHistory[this.historyIndex] || '';
    }
    
    // Move cursor to end
    this.inputEl.setSelectionRange(this.inputEl.value.length, this.inputEl.value.length);
  }
  
  handleTabCompletion() {
    const input = this.inputEl.value;
    const cursorPos = this.inputEl.selectionStart;
    const beforeCursor = input.substring(0, cursorPos);
    
    // Simple completion for common Rails methods
    const completions = this.getCompletions(beforeCursor);
    if (completions.length === 1) {
      const completion = completions[0];
      const newValue = beforeCursor + completion.substr(beforeCursor.length) + input.substring(cursorPos);
      this.inputEl.value = newValue;
      this.inputEl.setSelectionRange(cursorPos + completion.length - beforeCursor.length, cursorPos + completion.length - beforeCursor.length);
    } else if (completions.length > 1) {
      this.showCompletions(completions);
    }
  }
  
  getCompletions(text) {
    const railsCommands = [
      'Post.all', 'Post.count', 'Post.first', 'Post.last', 'Post.find',
      'User.all', 'User.count', 'User.first', 'User.last', 'User.find',
      'models', 'routes', 'env_info', 'db_info', 'app_config', 'memory_info',
      'Rails.env', 'Rails.root', 'Rails.application'
    ];
    
    return railsCommands.filter(cmd => cmd.startsWith(text.trim()));
  }
  
  showCompletions(completions) {
    this.addOutputLine(`Available completions: ${completions.join(', ')}`, 'output-info');
    this.scrollToBottom();
  }
  
  executeCommand() {
    const command = this.inputEl.value.trim();
    if (!command) return;
    
    // Add to local history
    if (this.commandHistory[this.commandHistory.length - 1] !== command) {
      this.commandHistory.push(command);
      if (this.commandHistory.length > 50) {
        this.commandHistory = this.commandHistory.slice(-50);
      }
    }
    this.historyIndex = this.commandHistory.length;
    
    // Display command
    this.addOutputLine(`> ${command}`, 'output-command');
    const loadingLine = this.addOutputLine('Executing...', 'loading');
    
    // Clear input
    this.inputEl.value = '';
    this.inputEl.style.height = 'auto';
    
    // Execute command
    this.currentRequest = fetch('/console/execute', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ 
        command: command,
        session: this.currentSession
      })
    })
    .then(response => response.json())
    .then(data => {
      this.removeLoadingLine(loadingLine);
      this.displayResult(data);
      this.scrollToBottom();
    })
    .catch(error => {
      this.removeLoadingLine(loadingLine);
      this.addOutputLine(`Network Error: ${error.message}`, 'output-error');
      this.scrollToBottom();
    })
    .finally(() => {
      this.currentRequest = null;
    });
  }
  
  cancelExecution() {
    if (this.currentRequest) {
      this.currentRequest.abort();
      this.addOutputLine('Execution cancelled', 'output-info');
      this.scrollToBottom();
    }
  }
  
  displayResult(data) {
    if (data.error) {
      this.addOutputLine(`Error: ${data.error}`, 'output-error');
      if (data.error_class) {
        this.addOutputLine(`(${data.error_class})`, 'output-error');
      }
    } else {
      this.formatAndDisplayResult(data.result);
    }
    
    if (data.timestamp) {
      this.addOutputLine(`[${data.timestamp}]`, 'output-timestamp');
    }
  }
  
  formatAndDisplayResult(result) {
    if (Array.isArray(result)) {
      result.forEach(item => {
        this.addOutputLine(String(item), 'output-result');
      });
    } else if (typeof result === 'object' && result !== null) {
      this.addOutputLine(JSON.stringify(result, null, 2), 'output-result');
    } else {
      this.addOutputLine(String(result), 'output-result');
    }
  }
  
  addOutputLine(text, className = '') {
    const line = document.createElement('div');
    line.className = `output-line ${className}`;
    line.textContent = text;
    this.outputEl.appendChild(line);
    return line;
  }
  
  removeLoadingLine(loadingLine) {
    if (loadingLine && loadingLine.parentElement) {
      loadingLine.remove();
    }
  }
  
  scrollToBottom() {
    this.outputEl.scrollTop = this.outputEl.scrollHeight;
  }
  
  clearOutput() {
    const lines = this.outputEl.querySelectorAll('.output-line');
    lines.forEach((line, index) => {
      if (index >= 10) { // Keep welcome messages and examples
        line.remove();
      }
    });
  }
  
  clearHistory() {
    if (confirm('Are you sure you want to clear command history?')) {
      fetch('/console/clear_history', {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      .then(response => response.json())
      .then(data => {
        this.commandHistory = [];
        this.historyIndex = 0;
        this.addOutputLine('Command history cleared.', 'output-info');
        this.scrollToBottom();
      })
      .catch(error => {
        this.addOutputLine(`Error clearing history: ${error.message}`, 'output-error');
        this.scrollToBottom();
      });
    }
  }
  
  focusInput() {
    this.inputEl.focus();
  }
  
  saveSession() {
    localStorage.setItem('rails_console_history', JSON.stringify(this.commandHistory.slice(-20)));
  }
  
  setCommand(command) {
    this.inputEl.value = command;
    this.focusInput();
  }
  
  // Session Management Methods
  async loadCurrentSessionInfo() {
    try {
      const response = await fetch('/console/session_list', {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        if (data.current_session) {
          this.updateSessionDisplay(data.current_session);
        }
      }
    } catch (error) {
      console.error('Error loading session info:', error);
    }
  }
  
  updateSessionDisplay(sessionInfo) {
    const sessionInfoEl = document.getElementById('current-session-info');
    if (sessionInfoEl && sessionInfo) {
      sessionInfoEl.textContent = ` - ${sessionInfo.name}`;
      this.currentSessionName = sessionInfo.name;
    }
  }
  
  async newSession() {
    const sessionName = prompt('Enter session name:', `Session ${new Date().toLocaleTimeString()}`);
    if (!sessionName) return;
    
    try {
      const response = await fetch('/console/new_session', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({ name: sessionName })
      });
      
      if (response.ok) {
        const data = await response.json();
        this.updateSessionDisplay(data.session);
        this.clearOutput();
        this.addOutputLine('✅ Created new session: ' + sessionName, 'output-result');
        this.loadHistory();
      } else {
        this.addOutputLine('❌ Failed to create session', 'output-error');
      }
    } catch (error) {
      console.error('Error creating session:', error);
      this.addOutputLine('❌ Error creating session', 'output-error');
    }
  }
  
  async showSessionManager() {
    try {
      const response = await fetch('/console/session_list', {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        this.displaySessionModal(data.sessions, data.current_session);
      } else {
        this.addOutputLine('❌ Failed to load sessions', 'output-error');
      }
    } catch (error) {
      console.error('Error loading sessions:', error);
      this.addOutputLine('❌ Error loading sessions', 'output-error');
    }
  }
  
  displaySessionModal(sessions, currentSession) {
    // Remove existing modal if present
    const existingModal = document.getElementById('session-modal');
    if (existingModal) {
      existingModal.remove();
    }
    
    // Create modal HTML
    const modal = document.createElement('div');
    modal.id = 'session-modal';
    modal.innerHTML = `
      <div class="modal-backdrop">
        <div class="modal-content">
          <div class="modal-header">
            <h3>Session Manager</h3>
            <button class="modal-close" onclick="this.closest('#session-modal').remove()">×</button>
          </div>
          <div class="modal-body">
            <div class="session-list">
              ${sessions.map(session => `
                <div class="session-item ${session.id === currentSession?.id ? 'current' : ''}" data-session-id="${session.id}">
                  <div class="session-info">
                    <div class="session-name">${session.name}</div>
                    <div class="session-meta">
                      Created: ${new Date(session.created_at).toLocaleString()}
                      ${session.last_active ? `| Last active: ${new Date(session.last_active).toLocaleString()}` : ''}
                    </div>
                    <div class="session-stats">
                      Variables: ${Object.keys(session.variables || {}).length} | 
                      History: ${(session.history || []).length} commands
                    </div>
                  </div>
                  <div class="session-actions">
                    ${session.id === currentSession?.id ? 
                      '<span class="current-badge">Current</span>' : 
                      `<button class="btn btn-sm" onclick="window.railsConsole.selectSession('${session.id}')">Switch</button>`
                    }
                    ${sessions.length > 1 ? 
                      `<button class="btn btn-sm btn-danger" onclick="window.railsConsole.closeSession('${session.id}')">Close</button>` : 
                      ''
                    }
                  </div>
                </div>
              `).join('')}
            </div>
            ${sessions.length === 0 ? '<p>No sessions available. Create a new session to get started.</p>' : ''}
          </div>
          <div class="modal-footer">
            <button class="btn" onclick="window.railsConsole.newSession().then(() => this.closest('#session-modal').remove())">New Session</button>
            <button class="btn btn-secondary" onclick="this.closest('#session-modal').remove()">Close</button>
          </div>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
  }
  
  async selectSession(sessionId) {
    try {
      const response = await fetch('/console/select_session', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({ session_id: sessionId })
      });
      
      if (response.ok) {
        const data = await response.json();
        this.updateSessionDisplay(data.session);
        this.clearOutput();
        this.addOutputLine('✅ Switched to session: ' + data.session.name, 'output-result');
        this.loadHistory();
        
        // Close modal
        const modal = document.getElementById('session-modal');
        if (modal) modal.remove();
      } else {
        this.addOutputLine('❌ Failed to switch session', 'output-error');
      }
    } catch (error) {
      console.error('Error switching session:', error);
      this.addOutputLine('❌ Error switching session', 'output-error');
    }
  }
  
  async closeSession(sessionId) {
    if (!confirm('Are you sure you want to close this session? All variables and history will be lost.')) {
      return;
    }
    
    try {
      const response = await fetch('/console/close_session', {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({ session_id: sessionId })
      });
      
      if (response.ok) {
        const data = await response.json();
        this.addOutputLine('✅ Session closed', 'output-result');
        
        if (data.switched_to) {
          this.updateSessionDisplay(data.switched_to);
          this.addOutputLine('✅ Switched to session: ' + data.switched_to.name, 'output-result');
          this.loadHistory();
        }
        
        // Refresh session modal
        this.showSessionManager();
      } else {
        this.addOutputLine('❌ Failed to close session', 'output-error');
      }
    } catch (error) {
      console.error('Error closing session:', error);
      this.addOutputLine('❌ Error closing session', 'output-error');
    }
  }
  
  async loadHistory() {
    try {
      const response = await fetch('/console', {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      });
      
      if (response.ok) {
        // The response should include updated history for the current session
        location.reload(); // Simple reload to get fresh session data
      }
    } catch (error) {
      console.error('Error loading history:', error);
    }
  }
}

// Initialize console when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  window.railsConsole = new RailsWebConsole();
});

// Global functions for backward compatibility
function executeCommand() {
  window.railsConsole.executeCommand();
}

function clearOutput() {
  window.railsConsole.clearOutput();
}

function clearHistory() {
  window.railsConsole.clearHistory();
}

function setCommand(command) {
  window.railsConsole.setCommand(command);
}

function newSession() {
  window.railsConsole.newSession();
}

function showSessionManager() {
  window.railsConsole.showSessionManager();
}

function closeSessionManager() {
  window.railsConsole.closeSessionManager();
}

function createNewSession() {
  window.railsConsole.createNewSession();
}

function selectSession(sessionId) {
  window.railsConsole.selectSession(sessionId);
}

function closeSession(sessionId) {
  window.railsConsole.closeSession(sessionId);
}
