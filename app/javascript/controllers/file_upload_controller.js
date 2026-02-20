// @TASK P2-S0-T1 - File Upload Controller
// @SPEC Blog AI Dashboard - Drag & drop file upload with validation

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropzone", "input", "preview", "progress"]

  static values = {
    maxSize: { type: Number, default: 50 * 1024 * 1024 }, // 50MB
    allowedTypes: {
      type: Array,
      default: [
        "application/pdf",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "application/x-hwp",
        "application/haansofthwp"
      ]
    }
  }

  connect() {
    this.files = []
  }

  dragover(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.add("dragover")
  }

  dragleave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.remove("dragover")
  }

  drop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.remove("dragover")

    const files = Array.from(event.dataTransfer.files)
    this.handleFiles(files)
  }

  select(event) {
    const files = Array.from(event.target.files)
    this.handleFiles(files)
  }

  handleFiles(files) {
    const validFiles = files.filter(file => this.validate(file))

    if (validFiles.length === 0) return

    validFiles.forEach(file => {
      this.files.push(file)
      this.addPreview(file)
    })

    // Auto-upload if form exists
    const form = this.element.closest("form")
    if (form) {
      this.upload()
    }
  }

  validate(file) {
    // Check file type
    if (!this.allowedTypesValue.includes(file.type)) {
      alert(`허용되지 않는 파일 형식입니다: ${file.name}\n(PDF, DOCX, HWP만 가능)`)
      return false
    }

    // Check file size
    if (file.size > this.maxSizeValue) {
      alert(`파일 크기가 너무 큽니다: ${file.name}\n(최대 50MB)`)
      return false
    }

    return true
  }

  addPreview(file) {
    if (!this.hasPreviewTarget) return

    const div = document.createElement("div")
    div.className = "file-preview-item"
    div.dataset.filename = file.name

    const icon = this.getFileIcon(file.type)
    const size = this.formatFileSize(file.size)

    div.innerHTML = `
      <div class="file-icon">${icon}</div>
      <div class="file-info">
        <div class="file-name">${file.name}</div>
        <div class="file-size">${size}</div>
      </div>
      <button type="button"
              class="file-remove"
              data-action="click->file-upload#remove"
              data-filename="${file.name}">
        ×
      </button>
    `

    this.previewTarget.appendChild(div)
  }

  remove(event) {
    const filename = event.target.dataset.filename
    this.files = this.files.filter(f => f.name !== filename)

    const previewItem = this.previewTarget.querySelector(`[data-filename="${filename}"]`)
    if (previewItem) {
      previewItem.remove()
    }
  }

  upload() {
    const form = this.element.closest("form")
    if (!form) return

    // Create FormData with files
    const formData = new FormData(form)

    // Remove old file inputs
    formData.delete("blog_document[file]")

    // Add new files
    this.files.forEach(file => {
      formData.append("blog_document[file]", file)
    })

    // Show progress
    if (this.hasProgressTarget) {
      this.progressTarget.style.display = "block"
    }

    // Submit with Turbo
    fetch(form.action, {
      method: form.method,
      body: formData,
      headers: {
        "X-CSRF-Token": this.getCSRFToken(),
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
    .then(response => {
      if (response.ok) {
        // Clear files after successful upload
        this.files = []
        if (this.hasPreviewTarget) {
          this.previewTarget.innerHTML = ""
        }
        if (this.hasInputTarget) {
          this.inputTarget.value = ""
        }
      }
      return response.text()
    })
    .then(html => {
      // Turbo will handle the stream response
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error("Upload Error:", error)
      alert("업로드 중 오류가 발생했습니다.")
    })
    .finally(() => {
      if (this.hasProgressTarget) {
        this.progressTarget.style.display = "none"
      }
    })
  }

  getFileIcon(type) {
    if (type.includes("pdf")) return "📄"
    if (type.includes("word")) return "📝"
    if (type.includes("hwp")) return "📋"
    return "📎"
  }

  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + " " + sizes[i]
  }

  getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
