from pathlib import Path
folder=Path('assets/ui/icons')
shapes={
'head':'<path d="M20 34c0-26 56-26 56 0v18H20z M18 52h60 M34 19v23 M61 19v23"/>',
'left_hand':'<path d="M31 76 18 52c-5-10 1-14 7-6l7 8V22c0-9 9-9 9 0v22-27c0-9 9-9 9 0v27-23c0-9 9-9 9 0v25-15c0-9 9-9 9 0v29c0 12-6 16-7 20z"/>',
'right_hand':'<g transform="translate(96 0) scale(-1 1)"><path d="M31 76 18 52c-5-10 1-14 7-6l7 8V22c0-9 9-9 9 0v22-27c0-9 9-9 9 0v27-23c0-9 9-9 9 0v25-15c0-9 9-9 9 0v29c0 12-6 16-7 20z"/></g>',
'upper':'<path d="m32 19-20 15 12 19 9-6v32h30V47l9 6 12-19-20-15c-5 12-27 12-32 0z"/>',
'lower':'<path d="M27 16h42l7 64H55l-7-39-7 39H20z M27 27h42"/>',
'feet':'<path d="M22 22h23v29l24 11c12 4 14 9 12 16H17V46z M17 68h64 M45 52l-8 7 M54 56l-8 7"/>',
'water':'<path fill="#80bdce" d="M37 13h22v15l10 12v41H27V40l10-12z"/><path d="M37 24h22 M30 50h36 M32 61h32"/>',
'food':'<rect x="22" y="22" width="52" height="58" rx="8" fill="#b9986d"/><ellipse cx="48" cy="22" rx="26" ry="8"/><path d="M26 40h44v24H26 M42 18h12"/>',
'medicine':'<rect x="18" y="23" width="60" height="55" rx="9" fill="#a5b8a8"/><path d="M34 23v-9h28v9"/><path fill="#cc9c90" d="M43 34h10v12h12v10H53v12H43V56H31V46h12z"/>',
'scrap':'<path fill="#a4a99e" d="m24 18 13 12-8 9-13-9c-3 14 7 23 19 18l29 30c12 10 24-3 13-13L46 36c6-14-5-23-22-18z"/>'}
for name,shape in shapes.items():
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><g fill="none" stroke="#c4d2cf" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round">{shape}</g></svg>'
 (folder/(name+'.svg')).write_text(svg,encoding='utf-8')
