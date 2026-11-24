// Sidebar menu search for #sidebar-search-input.
//
// Typing shows a suggestion dropdown of matching menus (best match first:
// exact > prefix > word prefix > substring > fuzzy), with matching sub-pages
// listed under their menu. Picking a suggestion moves that menu's whole
// section to the top of the sidebar, expands its dropdown and opens the
// picked page (picking a dropdown heading just expands it). The section stays
// on top across page loads until the Reset button restores the default order.
//
// Keys: ↑/↓ move, Enter picks, Esc closes.
//
// Works with every portal's sidebar (admin, franchise, store admin, affiliate,
// customer): the selectors below cover each one's markup.

const MAX_RESULTS = 10
const STORAGE_KEY = 'sidebarPinnedSection'

const SECTION = '.nav-section, .customer-nav-section, .sidebar-section'
const SECTION_TITLE = '.nav-section-title, .customer-nav-section-title, h6'
const HEAD_LINK = '.nav-link-modern, .customer-nav-link-modern'
const LABEL = '.nav-text, .customer-nav-text'
const ICON_BG = '.icon-bg, .customer-icon-bg'
const BADGE = '.badge, .customer-nav-badge'
const NOT_LABEL = `${BADGE}, .submenu-bullet, .dropdown-arrow`

function text(el) {
  return (el?.textContent || '').replace(/\s+/g, ' ').trim()
}

function escapeHtml(str) {
  return str.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
}

// Each portal remembers its own pinned section (admin keeps the original key)
function storageKey(sidebar) {
  const scope = sidebar?.querySelector('.sidebar-search')?.dataset.scope
  return scope && scope !== 'admin' ? `${STORAGE_KEY}:${scope}` : STORAGE_KEY
}

function storage(sidebar, action, value) {
  const key = storageKey(sidebar)
  try {
    if (action === 'get') return localStorage.getItem(key)
    if (action === 'set') localStorage.setItem(key, value)
    if (action === 'remove') localStorage.removeItem(key)
  } catch (_) { /* storage blocked: pinning just won't persist */ }
  return null
}

// Link text without bullets, arrows or count badges
function labelOf(link) {
  const label = link.querySelector(LABEL) || [...link.querySelectorAll('span')].filter(s => !s.matches(NOT_LABEL)).pop()
  return text(label || link)
}

function sectionTitle(section) {
  return text(section.querySelector(SECTION_TITLE))
}

// Copy the menu icon's gradient (from classes or inline styles). Plain light
// backgrounds would hide the white icon, so those keep the default.
function iconBackground(iconBg) {
  const image = iconBg ? getComputedStyle(iconBg).backgroundImage : 'none'
  return image && image.includes('gradient') ? `background:${image}` : ''
}

// Returns { score, ranges } where ranges are [start, end) spans to highlight.
function match(label, query) {
  const l = label.toLowerCase()
  if (!query || !l) return { score: 0, ranges: [] }
  if (l === query) return { score: 100, ranges: [[0, l.length]] }
  if (l.startsWith(query)) return { score: 90, ranges: [[0, query.length]] }

  const wordStart = l.search(new RegExp(`\\b${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`))
  if (wordStart > 0) return { score: 75, ranges: [[wordStart, wordStart + query.length]] }

  const idx = l.indexOf(query)
  if (idx >= 0) return { score: 55, ranges: [[idx, idx + query.length]] }

  // Fuzzy: all query letters appear in order (spaces ignored)
  const ranges = []
  let pos = 0
  for (const ch of query.replace(/\s+/g, '')) {
    const found = l.indexOf(ch, pos)
    if (found < 0) return { score: 0, ranges: [] }
    const last = ranges[ranges.length - 1]
    if (last && last[1] === found) last[1] = found + 1
    else ranges.push([found, found + 1])
    pos = found + 1
  }
  // Fewer, tighter chunks score higher
  return { score: Math.max(10, 35 - ranges.length * 4), ranges }
}

function highlight(label, ranges) {
  let html = ''
  let pos = 0
  ranges.forEach(([s, e]) => {
    html += escapeHtml(label.slice(pos, s)) + `<mark>${escapeHtml(label.slice(s, e))}</mark>`
    pos = e
  })
  return html + escapeHtml(label.slice(pos))
}

// Bootstrap Icons or Font Awesome classes, without spacing utilities
function iconClass(i) {
  const classes = i ? [...i.classList].filter(c => /^(bi|fa[srbl]?|bi-.+|fa-.+)$/.test(c)) : []
  return classes.length ? classes.join(' ') : 'bi bi-dot'
}

const words = label => label.split(' ').length

// One group per top-level menu item, with its submenu links as children.
function collectGroups(sidebar) {
  const groups = []
  sections(sidebar).forEach(section => {
    const sectionLabel = sectionTitle(section)

    section.querySelectorAll(HEAD_LINK).forEach(head => {
      if (head.closest('.submenu')) return
      // Admin/franchise/customer wrap each link in an <li> (which may hold a
      // submenu); store admin and affiliate links stand alone
      const item = head.parentElement.matches('li') ? head.parentElement : head
      const iconBg = head.querySelector(ICON_BG)
      groups.push({
        section,
        item,
        head,
        label: labelOf(head),
        sectionLabel,
        iconStyle: iconBackground(iconBg),
        icon: iconClass(iconBg?.querySelector('i') || head.querySelector(':scope > i')),
        children: item === head ? [] : [...item.querySelectorAll('.submenu-list a')].map(link => ({
          label: labelOf(link),
          link,
          icon: iconClass(link.querySelector(':scope > i'))
        }))
      })
    })
  })
  return groups
}

// Groups ordered best match first. A matching menu lists all its pages;
// otherwise only the pages that match are listed under it.
function rank(groups, query) {
  return groups
    .map(group => {
      const own = match(group.label, query)
      const section = match(group.sectionLabel, query).score * 0.5
      const children = group.children.map(child => ({ ...child, ...match(child.label, query) }))
      const bestChild = Math.max(0, ...children.map(c => c.score)) * 0.9
      return {
        ...group,
        ranges: own.ranges,
        ownScore: own.score,
        score: Math.max(own.score, bestChild, section),
        children: own.score > 0 || section >= bestChild ? children : children.filter(c => c.score > 0).sort((a, b) => b.score - a.score)
      }
    })
    .filter(g => g.score > 0)
    .sort((a, b) => b.score - a.score || words(a.label) - words(b.label) || a.label.localeCompare(b.label))
    .slice(0, MAX_RESULTS)
}

function badgeHtml(link) {
  const badge = link?.querySelector(BADGE)
  return badge ? `<span class="ss-badge">${escapeHtml(text(badge))}</span>` : ''
}

function render(sidebar, query) {
  const panel = sidebar.querySelector('.sidebar-search-results')
  if (!panel) return

  sidebar.classList.toggle('searching', query !== '')
  sidebar._searchTargets = []
  if (!query) {
    panel.innerHTML = ''
    return
  }

  const groups = rank(collectGroups(sidebar), query)
  if (!groups.length) {
    panel.innerHTML = `
      <div class="ss-empty">
        <div class="ss-empty-icon"><i class="bi bi-search"></i></div>
        <div class="ss-empty-title">No matches for “${escapeHtml(query)}”</div>
        <div class="ss-empty-sub">Try a shorter or different word</div>
      </div>`
    return
  }

  const targets = sidebar._searchTargets
  const row = (target, cls, inner) => {
    const i = targets.push(target) - 1
    return `<div class="ss-item ${cls}" data-index="${i}" role="option">${inner}</div>`
  }

  panel.innerHTML = groups.map((g, gi) => {
    const head = row({ group: g, el: g.head }, `ss-head ${gi === 0 ? 'ss-top' : ''}`, `
      <span class="ss-icon" style="${escapeHtml(g.iconStyle)}"><i class="${g.icon}"></i></span>
      <span class="ss-body">
        <span class="ss-label">${g.ranges.length ? highlight(g.label, g.ranges) : escapeHtml(g.label)}</span>
        <span class="ss-crumbs">${escapeHtml(g.sectionLabel)}${g.children.length ? ` · ${g.children.length} page${g.children.length > 1 ? 's' : ''}` : ''}</span>
      </span>
      ${badgeHtml(g.head)}
      <i class="bi bi-pin-angle ss-enter"></i>`)

    const children = g.children.map(c => row({ group: g, el: c.link }, 'ss-child', `
      <i class="${c.icon} ss-child-icon"></i>
      <span class="ss-label">${c.ranges?.length ? highlight(c.label, c.ranges) : escapeHtml(c.label)}</span>
      ${badgeHtml(c.link)}
      <i class="bi bi-pin-angle ss-enter"></i>`)).join('')

    return `<div class="ss-group" style="animation-delay:${Math.min(gi, 8) * 30}ms">
      ${head}${children ? `<div class="ss-children">${children}</div>` : ''}
    </div>`
  }).join('')

  // Preselect the top hit; when only one of its pages matched (not the menu
  // itself), preselect that page so Enter opens it directly
  const first = panel.querySelector('.ss-group')
  const top = groups[0].ownScore > 0 ? first.querySelector('.ss-item') : first.querySelector('.ss-child') || first.querySelector('.ss-item')
  top.classList.add('is-selected')
}

function select(sidebar, index) {
  const items = sidebar.querySelectorAll('.ss-item')
  if (!items.length) return
  const next = (index + items.length) % items.length
  items.forEach((el, i) => el.classList.toggle('is-selected', i === next))
  items[next].scrollIntoView({ block: 'nearest' })
}

function selectedIndex(sidebar) {
  const el = sidebar.querySelector('.ss-item.is-selected')
  return el ? Number(el.dataset.index) : -1
}

// --- Moving a section to the top ------------------------------------------

// Top-level sections, in their current DOM order
function sections(sidebar) {
  return [...sidebar.querySelectorAll(SECTION)].filter(s => !s.parentElement.closest(SECTION))
}

// The element the sections live in (and that scrolls, where one does)
function menuContainer(sidebar) {
  return sections(sidebar)[0]?.parentElement
}

// Remember the server-rendered order once, so Reset can restore it.
function rememberOrder(sidebar) {
  sections(sidebar).forEach((section, i) => {
    if (section.dataset.order === undefined) section.dataset.order = i
  })
}

function moveToTop(sidebar, section) {
  rememberOrder(sidebar)
  sections(sidebar).forEach(s => s.classList.remove('is-pinned'))
  section.classList.add('is-pinned')
  // Insert before the current first section rather than prepending: in some
  // sidebars the sections share their parent with the search box and footer
  const first = sections(sidebar)[0]
  if (first !== section) first.before(section)
  updateReset(sidebar)
}

function resetOrder(sidebar) {
  rememberOrder(sidebar)
  const current = sections(sidebar)
  if (!current.length) return
  const marker = document.createComment('')
  current[0].before(marker)
  current
    .sort((a, b) => a.dataset.order - b.dataset.order)
    .forEach(section => { section.classList.remove('is-pinned'); marker.before(section) })
  marker.remove()
  storage(sidebar, 'remove')
  updateReset(sidebar)
  menuContainer(sidebar)?.scrollTo({ top: 0, behavior: 'smooth' })
}

function updateReset(sidebar) {
  const bar = sidebar.querySelector('.sidebar-pin-bar')
  if (!bar) return
  const pinned = sections(sidebar).find(s => s.classList.contains('is-pinned'))
  bar.hidden = !pinned
  const name = bar.querySelector('.sidebar-pin-name')
  if (name) name.textContent = pinned ? sectionTitle(pinned) : ''
}

function expand(item) {
  const submenu = item.querySelector(':scope > .collapse.submenu')
  if (!submenu) return
  submenu.classList.add('show')
  item.querySelector(':scope > [data-bs-toggle="collapse"]')?.setAttribute('aria-expanded', 'true')
}

function flash(el) {
  el.classList.remove('ss-flash')
  void el.offsetWidth // restart the animation
  el.classList.add('ss-flash')
  setTimeout(() => el.classList.remove('ss-flash'), 2400)
}

function pick(sidebar, index) {
  const target = sidebar._searchTargets?.[index]
  if (!target) return
  const { section, item, sectionLabel } = target.group

  // With a single section there is nothing to reorder
  if (sections(sidebar).length > 1) {
    moveToTop(sidebar, section)
    storage(sidebar, 'set', sectionLabel)
  }
  expand(item)

  const input = sidebar.querySelector('#sidebar-search-input')
  if (input) { input.value = ''; input.blur() }
  render(sidebar, '')

  const menu = menuContainer(sidebar)
  menu?.scrollTo({ top: 0, behavior: 'smooth' })
  flash(target.el)

  // Open the picked page; dropdown headings have no page of their own
  const href = target.el.getAttribute('href')
  if (href && href !== '#' && !href.startsWith('javascript:')) {
    // The layout restores the sidebar's saved scroll on every load, which
    // would scroll the section we just moved up out of view
    sidebar.scrollTop = 0
    if (menu) menu.scrollTop = 0
    try { sessionStorage.setItem('sidebarScrollPosition', '0') } catch (_) {}
    if (window.Turbo?.visit) window.Turbo.visit(href)
    else window.location.href = href
  }
}

// Keep the dropdown holding the current page open after it loads.
function expandActive(sidebar) {
  sidebar.querySelectorAll('.submenu-list a.active').forEach(link => {
    const item = link.closest('.collapse.submenu')?.parentElement
    if (item) expand(item)
  })
}

// Re-apply the remembered section after every page load.
function applyPinned() {
  const sidebar = document.querySelector('.sidebar-search')?.closest('.modern-sidebar')
  if (!sidebar) return
  rememberOrder(sidebar)
  expandActive(sidebar)
  const title = storage(sidebar, 'get')
  const section = title && sections(sidebar).find(s => sectionTitle(s) === title)
  if (section) moveToTop(sidebar, section)
  else updateReset(sidebar)
}

// --- Events ----------------------------------------------------------------

function close(input) {
  input.value = ''
  render(input.closest('.modern-sidebar'), '')
}

document.addEventListener('input', (event) => {
  if (event.target.id !== 'sidebar-search-input') return
  const sidebar = event.target.closest('.modern-sidebar')
  if (sidebar) render(sidebar, event.target.value.trim().toLowerCase())
})

document.addEventListener('keydown', (event) => {
  const input = event.target
  if (input.id !== 'sidebar-search-input') return

  const sidebar = input.closest('.modern-sidebar')
  if (event.key === 'Escape') { close(input); input.blur() }
  else if (event.key === 'ArrowDown') { event.preventDefault(); select(sidebar, selectedIndex(sidebar) + 1) }
  else if (event.key === 'ArrowUp') { event.preventDefault(); select(sidebar, selectedIndex(sidebar) - 1) }
  else if (event.key === 'Enter') { event.preventDefault(); pick(sidebar, Math.max(0, selectedIndex(sidebar))) }
})

document.addEventListener('click', (event) => {
  const item = event.target.closest('.ss-item')
  if (item) {
    pick(item.closest('.modern-sidebar'), Number(item.dataset.index))
    return
  }
  if (event.target.closest('.sidebar-search-clear')) {
    const input = document.getElementById('sidebar-search-input')
    if (input) { close(input); input.focus() }
    return
  }
  const reset = event.target.closest('.sidebar-pin-reset')
  if (reset) {
    resetOrder(reset.closest('.modern-sidebar'))
    return
  }
  // Clicking anywhere outside the search closes the dropdown
  const input = document.getElementById('sidebar-search-input')
  if (input?.value && !event.target.closest('.sidebar-search')) close(input)
})

document.addEventListener('mousemove', (event) => {
  const item = event.target.closest?.('.ss-item')
  if (item && !item.classList.contains('is-selected')) select(item.closest('.modern-sidebar'), Number(item.dataset.index))
})

document.addEventListener('turbo:load', applyPinned)
if (document.readyState !== 'loading') applyPinned()
else document.addEventListener('DOMContentLoaded', applyPinned)
