// @TASK P2-S0-T1 - Blog Editor Controller
// @SPEC Blog AI Dashboard - Inline editing with auto-save

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "content", "status"]
  static values = {
    postId: Number,
    saveUrl: String,
    debounce: { type: Number, default: 2000 }
  }

  connect() {
    this.timeout = null
    this.lastSavedTitle = this.titleTarget?.textContent || ""
    this.lastSavedContent = this.contentTarget?.textContent || ""
  }

  contentChanged() {
    clearTimeout(this.timeout)

    this.showStatus("저장 중...")

    this.timeout = setTimeout(() => {
      this.save()
    }, this.debounceValue)
  }

  async save() {
    const title = this.titleTarget?.textContent.trim() || ""
    const content = this.contentTarget?.textContent.trim() || ""

    // Skip if nothing changed
    if (title === this.lastSavedTitle && content === this.lastSavedContent) {
      this.showStatus("저장됨", "success")
      return
    }

    try {
      const response = await fetch(this.saveUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken(),
          "Accept": "application/json"
        },
        body: JSON.stringify({
          blog_post: {
            title: title,
            content: content
          }
        })
      })

      if (response.ok) {
        this.lastSavedTitle = title
        this.lastSavedContent = content
        this.showStatus("저장됨", "success")
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      console.error("Save Error:", error)
      this.showStatus("저장 실패", "error")
    }
  }

  async copy(event) {
    event.preventDefault()

    const content = this.contentTarget?.textContent || ""

    try {
      await navigator.clipboard.writeText(content)
      this.showStatus("복사됨", "success")

      // Flash the button
      const button = event.target.closest("button")
      if (button) {
        button.classList.add("copied")
        setTimeout(() => button.classList.remove("copied"), 1000)
      }
    } catch (error) {
      console.error("Copy Error:", error)
      this.showStatus("복사 실패", "error")
    }
  }

  showStatus(message, type = "info") {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.className = `blog-editor-status ${type}`

    // Auto-hide success messages
    if (type === "success") {
      setTimeout(() => {
        this.statusTarget.textContent = ""
        this.statusTarget.className = "blog-editor-status"
      }, 2000)
    }
  }

  // Prevent line breaks in title (contenteditable)
  preventLineBreak(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      // Move focus to content
      if (this.hasContentTarget) {
        this.contentTarget.focus()
      }
    }
  }

  // Format content (optional: add formatting buttons)
  makeBold() {
    document.execCommand("bold", false, null)
    this.contentChanged()
  }

  makeItalic() {
    document.execCommand("italic", false, null)
    this.contentChanged()
  }

  insertHeading() {
    document.execCommand("formatBlock", false, "h2")
    this.contentChanged()
  }

  insertList() {
    document.execCommand("insertUnorderedList", false, null)
    this.contentChanged()
  }

  getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
