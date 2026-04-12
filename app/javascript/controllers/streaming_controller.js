// @TASK P2-S0-T1 - Streaming Controller
// @SPEC Blog AI Dashboard - SSE text streaming with cursor animation

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "cursor", "status"]
  static values = {
    url: String,
    autoStart: { type: Boolean, default: false }
  }

  connect() {
    this.isStreaming = false
    this.currentText = ""

    // status=generating 상태로 페이지에 도착한 경우 자동으로 SSE 스트리밍 시작
    if (this.autoStartValue) {
      // Turbo 네비게이션 직후 DOM 안정화 대기
      setTimeout(() => {
        if (!this.isStreaming) {
          // placeholder 본문 비우고 실제 스트리밍 시작
          if (this.hasOutputTarget) {
            this.outputTarget.textContent = ""
          }
          this.start(null)
        }
      }, 150)
    }
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
    } finally {
      // Safety timeout: stream ended but complete() never fired (edge case)
      if (this.isStreaming) {
        setTimeout(() => {
          if (this.isStreaming) {
            console.warn("[Streaming] Safety timeout: forcing complete")
            this.complete()
          }
        }, 5000)
      }
    }
  }

  async handleStream(response) {
    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let buffer = ""
    let streamEnded = false

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
            if (parsed.type === "image") {
              this.insertImage(parsed.url, parsed.alt)
            } else if (parsed.type === "image_status") {
              if (parsed.status === "generating") this.updateStatus("이미지 생성 중...")
              else if (parsed.status === "done") this.updateStatus(`이미지 ${parsed.count}장 생성 완료`)
              else if (parsed.status === "error") this.updateStatus("⚠️ 이미지 생성 실패 (본문은 정상)")
            } else if (parsed.type === "title" && parsed.text) {
              this.updateTitle(parsed.text)
            } else if (parsed.type === "description" && parsed.text) {
              this.updateDescription(parsed.text)
            } else if (parsed.type === "end") {
              return
            } else if (parsed.type === "text" && parsed.text) {
              await this.handleChunk(parsed.text)
            }
          } catch (e) {
            // Plain text chunk (legacy)
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

    // After stream ends, process any remaining buffer
    // (last chunk may contain "event: done" split across chunk boundaries)
    if (buffer.trim()) {
      const remainingLines = buffer.split("\n")
      for (const line of remainingLines) {
        if (line.startsWith("event: ")) {
          const eventType = line.slice(7).trim()
          if (eventType === "done") {
            return
          }
        } else if (line.startsWith("data: ")) {
          const data = line.slice(6).trim()
          if (data === "[DONE]") {
            return
          }
          try {
            const parsed = JSON.parse(data)
            if (parsed.type === "end") {
              return
            }
          } catch (e) {
            // ignore
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

  updateTitle(newTitle) {
    if (!newTitle) return
    // 1) 인라인 편집 title 영역 (show.html.erb .blog-editor-title)
    const editorTitle = document.querySelector('.blog-editor-title')
    if (editorTitle) {
      editorTitle.textContent = newTitle
    }
    // 2) 페이지 상단 h1 (.blog-header h1) — status badge 뒤 텍스트만 교체
    const headerH1 = document.querySelector('.blog-header h1')
    if (headerH1) {
      const badge = headerH1.querySelector('.blog-status-badge')
      if (badge) {
        // badge 이후 모든 노드 제거 후 새 텍스트 노드 삽입
        let next = badge.nextSibling
        while (next) {
          const n = next
          next = next.nextSibling
          n.remove()
        }
        headerH1.appendChild(document.createTextNode(' ' + newTitle))
      } else {
        headerH1.textContent = newTitle
      }
    }
    // 3) 브라우저 탭 제목
    document.title = newTitle
  }

  updateDescription(newDesc) {
    if (!newDesc) return
    // 메타 디스크립션은 숨김 필드이지만 SEO 분석 결과 + <meta> 태그에 반영될 수 있음
    // 1) 페이지 <meta name="description"> 업데이트 (SPA 내에서 검색엔진 이해 도움)
    let metaEl = document.querySelector('meta[name="description"]')
    if (!metaEl) {
      metaEl = document.createElement("meta")
      metaEl.name = "description"
      document.head.appendChild(metaEl)
    }
    metaEl.content = newDesc

    // 2) SEO 패널에 description 미리보기가 있다면 업데이트
    const descPreview = document.querySelector('[data-post-description-preview]')
    if (descPreview) {
      descPreview.textContent = newDesc
    }

    // 3) 사용자 피드백: 상태 메시지로 표시
    this.updateStatus(`메타 디스크립션 생성됨: ${newDesc.substring(0, 30)}...`)
  }

  insertImage(url, alt) {
    const imgContainer = document.createElement("div")
    imgContainer.className = "generated-image-container"
    imgContainer.innerHTML = `
      <img src="${url}" alt="${alt || "Generated image"}" class="generated-image" style="max-width: 100%; border-radius: 8px; margin: 16px 0;">
      ${alt ? `<p class="image-caption" style="color: var(--gray-500); font-size: 14px; margin-top: 8px;">${alt}</p>` : ""}
    `
    
    // Insert after the output target
    if (this.hasOutputTarget) {
      this.outputTarget.parentNode.insertBefore(imgContainer, this.outputTarget.nextSibling)
    }
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
