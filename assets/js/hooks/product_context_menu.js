/**
 * ProductContextMenu Hook
 *
 * Adds a right-click context menu to product cards with "Copy Product ID" option.
 * Attach to a container element - it will handle right-clicks on any product card within.
 * Also handles server-pushed "copy" events for copying arbitrary text to clipboard.
 */

const ProductContextMenu = {
  mounted() {
    this.menuEl = null;
    this.currentProductId = null;

    // Create the context menu element
    this.createMenu();

    // Store bound handlers for cleanup
    this.handleContextMenu = (e) => {
      const productCard = e.target.closest("[data-product-tiktok-id], [data-product-shopify-id]");
      if (productCard) {
        e.preventDefault();
        this.showMenu(e, productCard);
      }
    };

    this.handleClickOutside = (e) => {
      if (this.menuEl && !this.menuEl.contains(e.target)) {
        this.hideMenu();
      }
    };

    this.handleEscape = (e) => {
      if (e.key === "Escape" && this.menuEl) {
        this.hideMenu();
      }
    };

    this.handleScroll = () => {
      this.hideMenu();
    };

    // Attach event listeners
    this.el.addEventListener("contextmenu", this.handleContextMenu);
    document.addEventListener("click", this.handleClickOutside);
    document.addEventListener("keydown", this.handleEscape);
    document.addEventListener("scroll", this.handleScroll, true);

    // Handle server-pushed copy events (for "Copy Product IDs" from session menu)
    this.handleEvent("copy", ({ text }) => {
      navigator.clipboard.writeText(text).catch((err) => {
        console.error("Failed to copy to clipboard:", err);
      });
    });
  },

  createMenu() {
    this.menuEl = document.createElement("div");
    this.menuEl.className = "product-context-menu";
    this.menuEl.innerHTML = `
      <button class="product-context-menu__item" data-action="copy-id">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="size-4">
          <path fill-rule="evenodd" d="M15.988 3.012A2.25 2.25 0 0118 5.25v6.5A2.25 2.25 0 0115.75 14H13.5V7A2.5 2.5 0 0011 4.5H8.128a2.252 2.252 0 011.884-1.488A2.25 2.25 0 0112.25 1h1.5a2.25 2.25 0 012.238 2.012zM11.5 3.25a.75.75 0 01.75-.75h1.5a.75.75 0 01.75.75v.25h-3v-.25z" clip-rule="evenodd" />
          <path fill-rule="evenodd" d="M2 7a1 1 0 011-1h8a1 1 0 011 1v10a1 1 0 01-1 1H3a1 1 0 01-1-1V7zm2 3.25a.75.75 0 01.75-.75h4.5a.75.75 0 010 1.5h-4.5a.75.75 0 01-.75-.75zm0 3.5a.75.75 0 01.75-.75h4.5a.75.75 0 010 1.5h-4.5a.75.75 0 01-.75-.75z" clip-rule="evenodd" />
        </svg>
        Copy Product ID
      </button>
    `;
    this.menuEl.style.display = "none";
    document.body.appendChild(this.menuEl);

    // Handle menu item clicks
    this.menuEl.querySelector("[data-action='copy-id']").addEventListener("click", () => {
      this.copyProductId();
    });
  },

  showMenu(e, productCard) {
    // Get the product ID - prefer TikTok, fall back to Shopify
    const tiktokId = productCard.dataset.productTiktokId;
    const shopifyId = productCard.dataset.productShopifyId;

    this.currentProductId = tiktokId || shopifyId || null;

    if (!this.currentProductId) {
      return;
    }

    // Position the menu at the cursor
    this.menuEl.style.display = "block";

    // Get menu dimensions after showing
    const menuRect = this.menuEl.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    // Calculate position, keeping menu in viewport
    let x = e.clientX;
    let y = e.clientY;

    if (x + menuRect.width > viewportWidth) {
      x = viewportWidth - menuRect.width - 8;
    }
    if (y + menuRect.height > viewportHeight) {
      y = viewportHeight - menuRect.height - 8;
    }

    this.menuEl.style.left = `${x}px`;
    this.menuEl.style.top = `${y}px`;
  },

  hideMenu() {
    if (this.menuEl) {
      this.menuEl.style.display = "none";
    }
    this.currentProductId = null;
  },

  copyProductId() {
    if (this.currentProductId) {
      navigator.clipboard.writeText(this.currentProductId).then(
        () => {
          // Push event to show flash message
          this.pushEvent("product_id_copied", {});
        },
        (err) => {
          console.error("Failed to copy product ID:", err);
        }
      );
    }
    this.hideMenu();
  },

  destroyed() {
    // Clean up event listeners
    this.el.removeEventListener("contextmenu", this.handleContextMenu);
    document.removeEventListener("click", this.handleClickOutside);
    document.removeEventListener("keydown", this.handleEscape);
    document.removeEventListener("scroll", this.handleScroll, true);

    // Remove menu element from DOM
    if (this.menuEl && this.menuEl.parentNode) {
      this.menuEl.parentNode.removeChild(this.menuEl);
    }
  }
};

export default ProductContextMenu;
