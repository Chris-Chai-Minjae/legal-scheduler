// @TASK P2-S0-T1 - Streaming Controller
// @SPEC Blog AI Dashboard - SSE text streaming with cursor animation

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "cursor", "status"]
  static values = {
    url: String
  }

  connect() {
    this.isStreaming = false
    this.currentText = ""
  }

  async start(event) {
    if (event) {
      event.preventDefault()
    }

    if (this.isStreaming) return

    this.isStreaming = true
    this.currentText = ""
    this.showCursor()
    this.updateStatus("생성 중...")

    const form = event?.target.closest("form")
    const formData = form ? new FormData(form) : new FormData()

    try {
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

      await this.handleStream(response)
      this.complete()
    } catch (error) {
      console.error("Streaming Error:", error)
      this.updateStatus("⚠️ 오류 발생")
      this.isStreaming = false
    }
  }

  async handleStream(response) {
    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ""

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })
      const lines = buffer.split("\n")
      buffer = lines.pop()

      for (const line of lines) {
        if (line.startsWith("data: ")) {
          const data = line.slice(6).trim()

          if (data === "[DONE]") {
            return
          }

          try {
            const parsed = JSON.parse(data)
            if (parsed.text) {
              await this.handleChunk(parsed.text)
            } else if (parsed.event === "done") {
              return
            }
          } catch (e) {
            // Plain text chunk
            await this.handleChunk(data)
          }
        } else if (line.startsWith("event: ")) {
          const eventType = line.slice(7).trim()
          if (eventType === "done") {
            return
          }
        }
      }
    }
  }

  async handleChunk(text) {
    this.currentText += text

    if (this.hasOutputTarget) {
      this.outputTarget.textContent = this.currentText
    }

    // Smooth typing effect
    await this.delay(20)
  }

  complete() {
    this.isStreaming = false
    this.hideCursor()
    this.updateStatus("완료")

    // Dispatch custom event for other controllers
    this.element.dispatchEvent(new CustomEvent("streaming:complete", {
      bubbles: true,
      detail: { text: this.currentText }
    }))
  }

  showCursor() {
    if (this.hasCursorTarget) {
      this.cursorTarget.style.display = "inline-block"
    }
  }

  hideCursor() {
    if (this.hasCursorTarget) {
      this.cursorTarget.style.display = "none"
    }
  }

  updateStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }

  disconnect() {
    this.isStreaming = false
  }
}
