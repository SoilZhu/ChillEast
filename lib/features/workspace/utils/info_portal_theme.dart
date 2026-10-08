import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 湖南农业大学信息门户 (toApps2) Material Design 2 (MD2) 动态排版主题与自适应脚本
/// 匹配 ChillEast 原生功能页横向双列卡片风格
class InfoPortalTheme {
  /// MD2 核心样式表 (CSS)
  static const String md2Css = r'''/* ==========================================================================
   Material Design 2 (MD2) Theme for HUNAU Info Portal (toApps2)
   Matching ChillEast Native Functions Screen UI (2-column Horizontal Cards)
   ========================================================================== */

:root {
  --portal-bg: #FFFFFF;
  --portal-card-bg: #FFFFFF;
  --portal-card-border: #E0E0E0;
  --portal-card-active: #F5F5F5;
  --portal-title-color: #616161;
  --portal-text-color: rgba(0, 0, 0, 0.87);
  --portal-primary: #09C489;
  --md-primary: #09C489;
  --portal-font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
}

@media (prefers-color-scheme: dark) {
  :root {
    --portal-bg: #121212;
    --portal-card-bg: #1E1E1E;
    --portal-card-border: rgba(255, 255, 255, 0.12);
    --portal-card-active: #2A2A2A;
    --portal-title-color: rgba(255, 255, 255, 0.7);
    --portal-text-color: #FFFFFF;
  }
}

/* Base resets & layout */
html, body {
  background-color: var(--portal-bg) !important;
  color: var(--portal-text-color) !important;
  font-family: var(--portal-font-family) !important;
  -webkit-font-smoothing: antialiased !important;
  margin: 0 !important;
  padding: 0 !important;
  min-height: 100vh !important;
  -webkit-tap-highlight-color: transparent !important;
}

body {
  padding-bottom: 32px !important;
}

.wrapMax {
  max-width: 680px !important;
  margin: 0 auto !important;
  padding: 16px 16px 24px 16px !important;
  box-sizing: border-box !important;
}

/* ==========================================================================
   Search Bar (Automatically Hidden for Pure Native Category View)
   ========================================================================== */
.centerSearchBox,
div[class*="SearchBox"],
div[class*="searchBox"],
#searchBox {
  display: none !important;
  visibility: hidden !important;
  height: 0 !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow: hidden !important;
}

/* ==========================================================================
   Hidden Duplicate Apps (Native ChillEast features already exist)
   ========================================================================== */
.item[valid="6336614"], .item[valId="6336614"],      /* 学工系统 */
.item[valid="7710759"], .item[valId="7710759"],      /* 本科生公寓 */
.item[valid="8056745"], .item[valId="8056745"],      /* 教学评价平台 */
.item[valid="4311705"], .item[valId="4311705"],      /* 办事大厅 */
.item[valid="15336377"], .item[valId="15336377"],    /* 综合报修平台 */
.item[valid="4311769"], .item[valId="4311769"],      /* 成绩查询 */
.item[valid="4311750"], .item[valId="4311750"],      /* 课表查询 */
.item[valid="18418170"], .item[valId="18418170"],    /* 体育馆预约 */
.item[valid="6243391"], .item[valId="6243391"],      /* 馆藏查询 */
.item[valid="4610339"], .item[valId="4610339"] {     /* 借阅记录 */
  display: none !important;
  visibility: hidden !important;
  height: 0 !important;
  width: 0 !important;
  margin: 0 !important;
  padding: 0 !important;
  border: none !important;
  pointer-events: none !important;
}

/* ==========================================================================
   Category Containers (.applicationBox)
   ========================================================================== */
.applicationBox,
div[class*="applicationBox"],
div[class*="appBox"],
div[class*="ServiceBox"],
div[class*="serviceBox"] {
  background: transparent !important;
  border: none !important;
  box-shadow: none !important;
  border-radius: 0 !important;
  padding: 0 !important;
  margin: 0 0 20px 0 !important;
  overflow: visible !important;
}

.applicationBox.borderBtm {
  border-bottom: none !important;
}

/* Category Title (.title) */
.applicationBox .title,
div[class*="applicationBox"] .title,
div[class*="appBox"] .title,
div[class*="ServiceBox"] .title {
  display: block !important;
  height: auto !important;
  line-height: normal !important;
  padding: 0 0 10px 0 !important;
  margin: 0 !important;
  color: var(--portal-title-color) !important;
  font-size: 15px !important;
  font-weight: 600 !important;
  letter-spacing: normal !important;
  background: transparent !important;
  border: none !important;
  position: static !important;
}

/* Hide any decorative pseudo-elements before title */
.applicationBox .title::before,
div[class*="applicationBox"] .title::before,
div[class*="appBox"] .title::before,
div[class*="ServiceBox"] .title::before {
  display: none !important;
  content: none !important;
}

/* ==========================================================================
   Apps 2-Column Grid Layout (.list)
   ========================================================================== */
.applicationBox .list,
div[class*="applicationBox"] .list,
div[class*="appBox"] .list,
div[class*="ServiceBox"] .list {
  display: grid !important;
  grid-template-columns: repeat(2, 1fr) !important;
  gap: 10px !important;
  padding: 0 !important;
  margin: 0 !important;
  overflow: visible !important;
}

@media (min-width: 600px) {
  .applicationBox .list,
  div[class*="applicationBox"] .list {
    grid-template-columns: repeat(3, 1fr) !important;
  }
}

@media (min-width: 900px) {
  .applicationBox .list,
  div[class*="applicationBox"] .list {
    grid-template-columns: repeat(4, 1fr) !important;
  }
}

/* ==========================================================================
   Horizontal App Card (.item)
   Matching ChillEast Native _buildFunctionGridCard
   ========================================================================== */
.applicationBox .list .item,
div[class*="applicationBox"] .list .item,
div[class*="appBox"] .list .item,
div[class*="ServiceBox"] .list .item {
  float: none !important;
  width: 100% !important;
  height: 52px !important;
  min-height: 52px !important;
  max-height: 52px !important;
  display: flex !important;
  flex-direction: row !important;
  align-items: center !important;
  justify-content: flex-start !important;
  padding: 0 14px !important;
  border-radius: 8px !important;
  background-color: var(--portal-card-bg) !important;
  border: 1px solid var(--portal-card-border) !important;
  box-shadow: none !important;
  position: relative !important;
  overflow: hidden !important;
  cursor: pointer !important;
  box-sizing: border-box !important;
  user-select: none !important;
  -webkit-user-select: none !important;
  transition: background-color 0.15s ease, border-color 0.15s ease !important;
}

.applicationBox .list .item:active,
.applicationBox .list .item:hover,
div[class*="applicationBox"] .list .item:active,
div[class*="applicationBox"] .list .item:hover {
  background-color: var(--portal-card-active) !important;
}

/* ==========================================================================
   App Icon (Left Aligned, 20px)
   ========================================================================== */
.applicationBox .list .item img,
div[class*="applicationBox"] .list .item img,
.applicationBox .list .item .icon,
div[class*="applicationBox"] .list .item .icon,
.applicationBox .list .item svg,
div[class*="applicationBox"] .list .item svg {
  display: block !important;
  width: 20px !important;
  height: 20px !important;
  min-width: 20px !important;
  min-height: 20px !important;
  max-width: 20px !important;
  max-height: 20px !important;
  margin: 0 10px 0 0 !important;
  padding: 0 !important;
  border: none !important;
  border-radius: 2px !important;
  background: transparent !important;
  box-shadow: none !important;
  object-fit: contain !important;
  flex-shrink: 0 !important;
}

/* Fallback generated avatar (for broken or missing images) */
.md2-fallback-icon {
  width: 20px !important;
  height: 20px !important;
  min-width: 20px !important;
  min-height: 20px !important;
  margin: 0 10px 0 0 !important;
  border-radius: 4px !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  font-size: 11px !important;
  font-weight: 600 !important;
  color: #FFFFFF !important;
  box-shadow: none !important;
  user-select: none !important;
  flex-shrink: 0 !important;
}

/* ==========================================================================
   App Label (Right Aligned, 14px Regular, Single Line)
   ========================================================================== */
.applicationBox .list .item p,
div[class*="applicationBox"] .list .item p,
.applicationBox .list .item .search,
div[class*="applicationBox"] .list .item .search,
.applicationBox .list .item .searchText,
div[class*="applicationBox"] .list .item .searchText,
.applicationBox .list .item span,
div[class*="applicationBox"] .list .item span {
  font-size: 14px !important;
  font-weight: 400 !important;
  color: var(--portal-text-color) !important;
  text-align: left !important;
  line-height: normal !important;
  margin: 0 !important;
  padding: 0 !important;
  height: auto !important;
  display: block !important;
  white-space: nowrap !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  word-break: normal !important;
  flex: 1 !important;
  min-width: 0 !important;
}

/* ==========================================================================
   Hidden Navigation Sibling Elements
   ========================================================================== */
.applicationBox .list > div[style*="display:none"],
.applicationBox .list > div[style*="display: none"],
div[class*="applicationBox"] .list > div[style*="display:none"],
div[class*="applicationBox"] .list > div[style*="display: none"] {
  display: none !important;
  width: 0 !important;
  height: 0 !important;
  margin: 0 !important;
  padding: 0 !important;
}

/* ==========================================================================
   Gentle Ripple Effect
   ========================================================================== */
.md2-ripple {
  position: absolute !important;
  border-radius: 50% !important;
  background: rgba(0, 0, 0, 0.06) !important;
  transform: scale(0) !important;
  animation: md2RippleAnimation 0.4s ease-out forwards !important;
  pointer-events: none !important;
}

@keyframes md2RippleAnimation {
  to {
    transform: scale(3);
    opacity: 0;
  }
}

/* ==========================================================================
   Empty Search State
   ========================================================================== */
.md2-empty-state {
  display: none;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 48px 16px;
  text-align: center;
}

.md2-empty-state.visible {
  display: flex !important;
}

.md2-empty-state-icon {
  width: 48px;
  height: 48px;
  margin-bottom: 12px;
  opacity: 0.35;
  color: var(--portal-title-color);
}

.md2-empty-state-text {
  font-size: 14px;
  font-weight: 400;
  color: var(--portal-title-color);
  margin-bottom: 14px;
}

.md2-empty-state-btn {
  padding: 6px 16px;
  border-radius: 8px;
  background: var(--portal-primary);
  color: #FFFFFF;
  font-size: 13px;
  font-weight: 500;
  border: none;
  cursor: pointer;
}
''';

  /// MD2 核心自适应与排版逻辑 (JS)
  static const String md2Js = r'''/**
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
''';

  /// 获取用于 InAppWebView 初始化注入的 UserScript 列表
  static List<UserScript> get userScripts => [
    // 1. 样式表注入 (在文档开始时注入，杜绝 FOUC 白屏或跳闪)
    UserScript(
      source: """
        (function() {
          const url = window.location.href;
          if (!url.includes('toApps2') && !url.includes('microService2')) return;
          const style = document.createElement('style');
          style.id = 'chilleast-info-portal-md2-theme';
          style.textContent = ${jsonEncode(md2Css)};
          if (document.head) {
            document.head.appendChild(style);
          } else {
            document.addEventListener('DOMContentLoaded', function() {
              document.head.appendChild(style);
            });
          }
        })();
      """,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    ),
    // 2. MD2 动态逻辑脚本注入 (在文档加载完成时启动排版与观察器)
    UserScript(
      source: md2Js,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
    ),
  ];
}
