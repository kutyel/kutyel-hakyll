;(() => {
  const state = {
    isActive: false,
  }

  const cn = {
    dark: 'dark',
    light: 'light',
    toggle: 'toggle',
    toggleDay: 'toggle__day',
    toggleNight: 'toggle__night',
    toggleOff: 'toggle--off',
    toggleOn: 'toggle--on',
  }

  const updateBodyClass = () =>
    document.body.classList.replace(
      state.isActive ? cn.light : cn.dark,
      state.isActive ? cn.dark : cn.light
    )

  const createToggleNightBtn = () => {
    const toggleBtn = document.createElement('button')
    toggleBtn.type = 'button'
    toggleBtn.setAttribute('role', 'switch')
    toggleBtn.setAttribute('aria-checked', String(state.isActive))
    toggleBtn.className = `${cn.toggle} ${state.isActive ? cn.toggleOn : cn.toggleOff}`
    toggleBtn.addEventListener('click', () => {
      const isActive = !state.isActive
      state.isActive = isActive

      localStorage.setItem('isActive', String(isActive))
      updateBodyClass()

      toggleBtn.setAttribute('aria-checked', String(isActive))
      toggleBtn.className = `${cn.toggle} ${isActive ? cn.toggleOn : cn.toggleOff}`
    })

    const dayEl = document.createElement('span')
    dayEl.innerText = '🌞'
    dayEl.className = cn.toggleDay
    dayEl.setAttribute('aria-label', 'Day Mode')

    const nightEl = document.createElement('span')
    nightEl.innerText = '🌙'
    nightEl.className = cn.toggleNight
    nightEl.setAttribute('aria-label', 'Night Mode')

    toggleBtn.appendChild(dayEl)
    toggleBtn.appendChild(nightEl)

    return toggleBtn
  }

  const readingTime = () => {
    const words = document.getElementById('content').innerText.trim().split(/\s+/).length
    // M. Brysbaert, Journal of Memory and Language (2009) vol 109. DOI: 10.1016/j.jml.2019.104047
    const WORDS_PER_MINUTE = 238
    document.getElementById('time').innerText = Math.ceil(words / WORDS_PER_MINUTE)
  }

  const init = () => {
    state.isActive = window.localStorage.getItem('isActive') === 'true'
    updateBodyClass()
    const el = document.querySelector('[data-nav-wrap]') || document.body
    el && el.appendChild(createToggleNightBtn())
    // we only want the reading time calculation to run on the post.html template
    document.getElementById('time') && readingTime()
    setTimeout(() => document.body.classList.remove('preload'), 100)
  }

  init()
})()
