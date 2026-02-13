const DEBUG_FLAG = "debug:creators:infinite"

const CreatorsInfiniteScroll = {
  mounted() {
    this.pendingLoad = false
    this.thresholdPx = 120

    this.onScroll = () => {
      this.maybeLoadMore("scroll")
    }

    this.el.addEventListener("scroll", this.onScroll, { passive: true })

    // Evaluate once on mount in case content starts near the bottom.
    this.maybeLoadMore("mounted")
  },

  updated() {
    // Defensive reset in case callback ordering is delayed.
    if (!this.loading()) {
      this.pendingLoad = false
    }

    // Re-check after patch so users at bottom continue loading naturally.
    this.maybeLoadMore("updated")
  },

  destroyed() {
    this.el.removeEventListener("scroll", this.onScroll)
  },

  hasMore() {
    return this.el.dataset.hasMore === "true"
  },

  loading() {
    return this.el.dataset.loading === "true"
  },

  distanceToBottom() {
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight
  },

  debugEnabled() {
    try {
      return window.localStorage.getItem(DEBUG_FLAG) === "1"
    } catch (_error) {
      return false
    }
  },

  debugLog(reason, details) {
    if (this.debugEnabled()) {
      console.debug("[CreatorsInfiniteScroll]", reason, details)
    }
  },

  maybeLoadMore(reason) {
    const hasMore = this.hasMore()
    const loading = this.loading()
    const distance = this.distanceToBottom()

    this.debugLog(reason, {
      hasMore,
      loading,
      pendingLoad: this.pendingLoad,
      distance,
      scrollTop: this.el.scrollTop,
      clientHeight: this.el.clientHeight,
      scrollHeight: this.el.scrollHeight,
      scrollLeft: this.el.scrollLeft
    })

    if (!hasMore || loading || this.pendingLoad) {
      return
    }

    if (distance <= this.thresholdPx) {
      this.pendingLoad = true

      this.pushEvent("load_more", {}, () => {
        this.pendingLoad = false
        this.debugLog("ack", { hasMore: this.hasMore(), loading: this.loading() })
      })
    }
  }
}

export default CreatorsInfiniteScroll
