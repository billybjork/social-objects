const DEFAULT_THRESHOLD_PX = 120

const InfiniteScroll = {
  mounted() {
    this.pendingLoad = false
    this.thresholdPx = this.parseThreshold()

    this.onContainerScroll = () => this.maybeLoadMore("container_scroll")
    this.onWindowScroll = () => this.maybeLoadMore("window_scroll")
    this.onResize = () => this.maybeLoadMore("resize")

    this.bindScrollListener()
    window.addEventListener("resize", this.onResize)

    // Try once on mount in case initial content is shorter than the viewport/container.
    this.maybeLoadMore("mounted")
  },

  updated() {
    if (!this.loading()) {
      this.pendingLoad = false
    }

    this.thresholdPx = this.parseThreshold()
    this.bindScrollListener()
    this.maybeLoadMore("updated")
  },

  destroyed() {
    this.unbindScrollListener()
    window.removeEventListener("resize", this.onResize)
  },

  parseThreshold() {
    const rawValue = this.el.dataset.thresholdPx
    const threshold = Number.parseInt(rawValue || "", 10)
    return Number.isFinite(threshold) ? threshold : DEFAULT_THRESHOLD_PX
  },

  hasMore() {
    return this.el.dataset.hasMore === "true"
  },

  loading() {
    return this.el.dataset.loading === "true"
  },

  loadEvent() {
    return this.el.dataset.loadEvent
  },

  scrollScope() {
    return this.el.dataset.scrollScope === "container" ? "container" : "viewport"
  },

  bindScrollListener() {
    const nextScope = this.scrollScope()

    if (this.activeScope === nextScope) {
      return
    }

    this.unbindScrollListener()
    this.activeScope = nextScope

    if (nextScope === "container") {
      this.el.addEventListener("scroll", this.onContainerScroll, { passive: true })
    } else {
      window.addEventListener("scroll", this.onWindowScroll, { passive: true })
    }
  },

  unbindScrollListener() {
    this.el.removeEventListener("scroll", this.onContainerScroll)
    window.removeEventListener("scroll", this.onWindowScroll)
    this.activeScope = null
  },

  distanceToBottom() {
    if (this.scrollScope() === "container") {
      return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight
    }

    return this.el.getBoundingClientRect().bottom - window.innerHeight
  },

  maybeLoadMore(_reason) {
    const event = this.loadEvent()

    if (!event || !this.hasMore() || this.loading() || this.pendingLoad) {
      return
    }

    if (this.distanceToBottom() <= this.thresholdPx) {
      this.pendingLoad = true

      this.pushEvent(event, {}, () => {
        this.pendingLoad = false
      })
    }
  }
}

export default InfiniteScroll
