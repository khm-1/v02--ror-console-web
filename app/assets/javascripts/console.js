// Enhanced Console JavaScript
class RailsWebConsole {
  constructor() {
    this.commandHistory = window.initialHistory || [];
    this.historyIndex = this.commandHistory.length;
    this.outputEl = document.getElementById('console-output');
    this.inputEl = document.getElementById('console-input');
    this.currentSession = Date.now();
    
    this.initializeEventListeners();
    this.focusInput();
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
