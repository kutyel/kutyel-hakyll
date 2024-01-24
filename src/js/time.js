;(() => {
  // M. Brysbaert, Journal of Memory and Language (2009) vol 109. DOI: 10.1016/j.jml.2019.104047
  const WORDS_PER_MINUTE = 238;

  function readingTime() {
    const timeEl = document.getElementById('time');
    const contentEl = document.getElementById('content');

    if (timeEl && contentEl) {
      const words = contentEl
        .innerText
        .trim()
        .split(/\s+/)
        .length;

      timeEl.innerText = Math.ceil(words / WORDS_PER_MINUTE);
    }
  }

  readingTime();
})();
