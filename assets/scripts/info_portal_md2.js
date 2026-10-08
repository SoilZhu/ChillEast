/**
 * Material Design 2 (MD2) Dynamic Adapter for HUNAU Info Portal (toApps2)
 * Matching ChillEast Native Functions Screen UI (2-column Horizontal Cards)
 * 
 * Features:
 * 1. Automatic real-time adaptation for existing & future service elements.
 * 2. Instant client-side search filtering across categories & apps.
 * 3. Graceful fallback MD2 avatars for broken/missing icons.
 * 4. Micro-interaction touch feedback.
 * 5. MutationObserver to automatically format and style any new features added in the future.
 */
(function() {
  'use strict';

  if (window.__MD2_PORTAL_ENHANCED__) return;
  window.__MD2_PORTAL_ENHANCED__ = true;

  console.log("🎨 [MD2] Initializing ChillEast card theme for HUNAU Info Portal...");

  const MD2_PALETTE = [
    '#3476E6', // Blue (xgxt)
    '#E91E63', // Pink (gym)
    '#00BCD4', // Cyan (teaching_eval)
    '#008268', // Teal (campus_card)
    '#1E88E5', // Blue (ehall)
    '#1976D2', // Blue (info_portal)
    '#607D8B', // BlueGrey (vpn)
    '#09C489', // Green (sunshine)
    '#9C27B0', // Purple
    '#FF9800', // Orange
  ];

  function getConsistentColor(text) {
    let hash = 0;
    const str = text || '★';
    for (let i = 0; i < str.length; i++) {
      hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }
    const index = Math.abs(hash) % MD2_PALETTE.length;
    return MD2_PALETTE[index];
  }

  // 1. Water Ripple / Tap Feedback on Pointer Down
  function attachRipple(el) {
    if (el.__has_md2_ripple__) return;
    el.__has_md2_ripple__ = true;

    el.addEventListener('pointerdown', function(e) {
      const rect = el.getBoundingClientRect();
      const ripple = document.createElement('span');
      ripple.className = 'md2-ripple';
      
      const size = Math.max(rect.width, rect.height);
      const x = e.clientX - rect.left - size / 2;
      const y = e.clientY - rect.top - size / 2;
      
      ripple.style.width = ripple.style.height = `${size}px`;
      ripple.style.left = `${x}px`;
      ripple.style.top = `${y}px`;
      
      el.appendChild(ripple);
      setTimeout(() => { ripple.remove(); }, 500);
    }, { passive: true });
  }

  // 2. Handle Broken or Missing App Icons with 20px Fallback Avatars
  function setupImageFallback(img, title) {
    if (img.__has_fallback_handler__) return;
    img.__has_fallback_handler__ = true;

    function applyFallback() {
      const char = (title || '').trim().charAt(0) || '★';
      const fallback = document.createElement('div');
      fallback.className = 'md2-fallback-icon';
      fallback.style.backgroundColor = getConsistentColor(title || char);
      fallback.innerText = char;
      img.replaceWith(fallback);
    }

    img.onerror = applyFallback;

    if (img.complete && img.naturalWidth === 0 && img.src) {
      applyFallback();
    }
  }

  const HIDDEN_APPS = [
    '学工系统',
    '本科生公寓',
    '办事大厅',
    '教学评价平台',
    '综合报修平台',
    '成绩查询',
    '课表查询',
    '体育馆预约',
    '馆藏查询',
    '借阅记录',
  ];

  // 3. Enhance & Rename Categories ('三方服务' -> '校方服务')
  function enhanceCategories() {
    const boxes = document.querySelectorAll('.applicationBox, div[class*="applicationBox"]');
    boxes.forEach(box => {
      const titleEl = box.querySelector('.title');
      if (titleEl && titleEl.textContent.includes('三方服务')) {
        titleEl.textContent = titleEl.textContent.replace('三方服务', '校方服务');
      }

      // Check if all items in category are hidden
      const items = box.querySelectorAll('.item');
      if (items.length > 0) {
        const hasVisible = Array.from(items).some(item => {
          return item.style.display !== 'none' && window.getComputedStyle(item).display !== 'none';
        });
        box.style.display = hasVisible ? '' : 'none';
      }
    });
  }

  // 4. Enhance App Grid Items & Hide Duplicates
  function enhanceItems() {
    const items = document.querySelectorAll('.item, div[class*="applicationBox"] .list > div:not([style*="display:none"])');
    items.forEach(item => {
      const p = item.querySelector('p') || item.querySelector('.searchText') || item.querySelector('span');
      const text = p ? p.textContent.trim() : '';

      if (HIDDEN_APPS.includes(text)) {
        item.style.setProperty('display', 'none', 'important');
        return;
      }

      attachRipple(item);
      const img = item.querySelector('img');
      if (img) setupImageFallback(img, text);
    });
  }

  // 4. Enhance Search with Real-time Client-Side Filtering + Clear Button + Empty State
  function setupSearchEnhancement() {
    const searchInput = document.querySelector('input.search');
    const searchBox = document.querySelector('.centerSearchBox');
    const wrapMax = document.querySelector('.wrapMax') || document.body;

    if (!searchInput || !searchBox || searchInput.__md2_search_ready__) return;
    searchInput.__md2_search_ready__ = true;

    // Add clear button inside search bar
    let clearBtn = searchBox.querySelector('.md2-search-clear');
    if (!clearBtn) {
      clearBtn = document.createElement('div');
      clearBtn.className = 'md2-search-clear';
      clearBtn.innerHTML = '✕';
      searchInput.parentElement.appendChild(clearBtn);

      clearBtn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        searchInput.value = '';
        clearBtn.classList.remove('visible');
        filterApps('');
        searchInput.focus();
      });
    }

    // Add empty state container for search results
    let emptyState = document.querySelector('.md2-empty-state');
    if (!emptyState) {
      emptyState = document.createElement('div');
      emptyState.className = 'md2-empty-state';
      emptyState.innerHTML = `
        <svg class="md2-empty-state-icon" viewBox="0 0 24 24" fill="currentColor">
          <path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/>
        </svg>
        <div class="md2-empty-state-text">未找到相关服务</div>
        <button class="md2-empty-state-btn" type="button">清空搜索</button>
      `;
      wrapMax.appendChild(emptyState);

      emptyState.querySelector('.md2-empty-state-btn').addEventListener('click', () => {
        searchInput.value = '';
        clearBtn.classList.remove('visible');
        filterApps('');
      });
    }

    function filterApps(query) {
      const q = (query || '').trim().toLowerCase();
      const boxes = document.querySelectorAll('.applicationBox, div[class*="applicationBox"]');
      let totalVisible = 0;

      boxes.forEach(box => {
        const items = box.querySelectorAll('.list .item');
        let boxVisibleCount = 0;

        items.forEach(item => {
          const textEl = item.querySelector('p') || item.querySelector('.searchText') || item;
          const text = (textEl ? textEl.textContent : '').trim().toLowerCase();
          const matches = !q || text.includes(q);

          item.style.display = matches ? 'flex' : 'none';
          if (matches) {
            boxVisibleCount++;
            totalVisible++;
          }
        });

        // Hide empty category when searching
        box.style.display = (boxVisibleCount > 0 || !q) ? '' : 'none';
      });

      if (emptyState) {
        if (totalVisible === 0 && q) {
          emptyState.classList.add('visible');
        } else {
          emptyState.classList.remove('visible');
        }
      }
    }

    searchInput.addEventListener('input', function() {
      const val = this.value;
      if (val) {
        clearBtn.classList.add('visible');
      } else {
        clearBtn.classList.remove('visible');
      }
      filterApps(val);
    });
  }

  // 5. MutationObserver for Future-Proof Dynamic Elements
  function observeDynamicElements() {
    let debounceTimer = null;
    const observer = new MutationObserver(() => {
      if (debounceTimer) clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        enhanceCategories();
        enhanceItems();
        setupSearchEnhancement();
      }, 100);
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  // Main initialization routine
  function init() {
    enhanceCategories();
    enhanceItems();
    setupSearchEnhancement();
    observeDynamicElements();
    console.log("🚀 [MD2] ChillEast card theme initialization complete.");
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
