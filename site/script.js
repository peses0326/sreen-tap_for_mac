(() => {
  const button = document.getElementById('language');
  const metadata = document.querySelector('meta[name="description"]');
  let language;
  try { language = localStorage.getItem('screentap-language'); } catch {}
  language = language === 'en' || language === 'ko' ? language : (navigator.language.startsWith('ko') ? 'ko' : 'en');
  function translate() {
    document.documentElement.lang = language;
    document.querySelectorAll('[data-ko][data-en]').forEach(node => { node.innerHTML = node.dataset[language]; });
    button.textContent = language === 'ko' ? 'EN' : '한국어';
    button.setAttribute('aria-label', language === 'ko' ? 'Switch language to English' : '한국어로 전환');
    document.title = language === 'ko' ? 'ScreenTap — 창은 한눈에. 전환은 한 번에.' : 'ScreenTap — See your windows. Keep your flow.';
    metadata.content = language === 'ko' ? '창 미리보기와 최근 사용 순서로 더 가볍게 전환하세요. 오픈소스 macOS 창 전환기.' : 'A native, open-source macOS window switcher. Small thumbnails, familiar shortcuts, and memory returned when you are done.';
  }
  button.addEventListener('click', () => {
    language = language === 'ko' ? 'en' : 'ko';
    try { localStorage.setItem('screentap-language', language); } catch {}
    translate();
  });
  const windows = [...document.querySelectorAll('.demo-app')];
  let selected = 0;
  document.getElementById('try-tab').addEventListener('click', () => {
    windows[selected].classList.remove('selected');
    selected = (selected + 1) % windows.length;
    windows[selected].classList.add('selected');
    document.getElementById('demo-status').textContent = windows[selected].textContent + (language === 'ko' ? ' 선택됨' : ' selected');
  });
  translate();
})();
