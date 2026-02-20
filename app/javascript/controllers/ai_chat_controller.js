// @TASK P2-S0-T1 - AI Chat Controller
// @SPEC Blog AI Dashboard - SSE streaming chat interface

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "messages", "input", "form", "status"]
  static values = {
    url: String
  }

  connect() {
    this.isOpen = false
    this.scrollToBottom()
  }

  toggle() {
    this.isOpen = !this.isOpen
    const panel = this.element

    if (this.isOpen) {
      panel.classList.add("open")
    } else {
      panel.classList.remove("open")
    }
  }

  async send(event) {
    event.preventDefault()

    const content = this.inputTarget.value.trim()
    if (!content) return

    // Add user message to UI immediately
    this.addMessage("user", content)
    this.inputTarget.value = ""
    this.showStatus()

    // Prepare form data
    const formData = new FormData(this.formTarget)

    try {
      // Fetch with SSE streaming support
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Accept": "text/event-stream",
          "X-CSRF-Token": this.getCSRFToken()
        },
        body: formData
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      await this.handleSSE(response)
    } catch (error) {
      console.error("AI Chat Error:", error)
      this.addMessage("assistant", "⚠️ 오류가 발생했습니다. 다시 시도해주세요.")
    } finally {
      this.hideStatus()
    }
  }

  async handleSSE(response) {
    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ""
    let currentMessage = ""

    // Create assistant message container
    const messageEl = this.createMessageElement("assistant")
    this.messagesTarget.appendChild(messageEl)
    const contentEl = messageEl.querySelector(".message-text")

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })
      const lines = buffer.split("\n")
      buffer = lines.pop() // Keep incomplete line in buffer

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const data = line.slice(6).trim()

          if (data === "[DONE]") {
            this.scrollToBottom()
            return
          }

          try {
            const parsed = JSON.parse(data)
            if (parsed.text) {
              currentMessage += parsed.text
              contentEl.textContent = currentMessage
              this.scrollToBottom()
            }
          } catch (e) {
            // Not JSON, treat as plain text
            currentMessage += data
            contentEl.textContent = currentMessage
            this.scrollToBottom()
          }
        }
      }
    }
  }

  addMessage(role, content) {
    const messageEl = this.createMessageElement(role)
    const contentEl = messageEl.querySelector(".message-text")
    contentEl.textContent = content
    this.messagesTarget.appendChild(messageEl)
    this.scrollToBottom()
  }

  createMessageElement(role) {
    const div = document.createElement("div")
    div.className = `ai-chat-message ${role}`
    div.innerHTML = `
      <div class="message-avatar">
        ${role === "user" ? "👤" : "🤖"}
      </div>
      <div class="message-content">
        <div class="message-text"></div>
        <div class="message-time">방금</div>
      </div>
    `
    return div
  }

  showStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.style.display = "flex"
    }
  }

  hideStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.style.display = "none"
    }
  }

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
