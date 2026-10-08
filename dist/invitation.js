// Confirmed details supplied by the family.
const wedding = { groom: 'Maaz Khan', bride: 'Taushiba Khan', date: '2026-11-16T08:00:00+05:30', endDate: '2026-11-16T17:00:00+05:30', timeZone: 'Asia/Kolkata', venue: 'Gaus Pur, Mahul', address: 'Azamgarh, Uttar Pradesh, India' };
const $ = id => document.getElementById(id);
document.querySelectorAll('[data-groom]').forEach(el => el.textContent = wedding.groom);
document.querySelectorAll('[data-bride]').forEach(el => el.textContent = wedding.bride);
document.title = `${wedding.groom} & ${wedding.bride} · Walima Invitation`;
const date = new Date(wedding.date);
const fmt = options => new Intl.DateTimeFormat('en-GB', { timeZone: wedding.timeZone, ...options }).format(date);
$('weekday').textContent = fmt({ weekday: 'long' }).toUpperCase();
$('day').textContent = fmt({ day: 'numeric' });
$('month').textContent = fmt({ month: 'long', year: 'numeric' }).toUpperCase();
const time = fmt({ hour: 'numeric', minute: '2-digit', hour12: true }).toUpperCase();
const endTime = new Intl.DateTimeFormat('en-GB', { timeZone: wedding.timeZone, hour: 'numeric', minute: '2-digit', hour12: true }).format(new Date(wedding.endDate)).toUpperCase();
$('time').textContent = `${time} - ${endTime}`;
$('venue-name').textContent = wedding.venue;
$('venue-address').textContent = wedding.address;
$('venue-date').textContent = `${fmt({ weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })} · ${time} - ${endTime} (IST)`;
const video = $('opening'); let opened = false, openingTimer, videoFailed = false;
function showNames() { $('couple').classList.add('visible'); $('couple').setAttribute('aria-hidden', 'false'); $('scroll').hidden = false; }
function useOpeningFallback() {
  videoFailed = true;
  clearTimeout(openingTimer);
  video.classList.remove('has-frame');
  video.pause();
  if (opened) showNames();
}
// Keep the floral background visible until playback has actually advanced.
video.addEventListener('timeupdate', () => {
  if (!videoFailed && video.currentTime > 0) video.classList.add('has-frame');
});
$('open').addEventListener('click', () => {
  if (opened) return; opened = true;
  $('open').classList.add('opened'); $('open').disabled = true;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduced || videoFailed || video.error) { useOpeningFallback(); return; }
  // Start the escape timer before play(): its promise can remain pending.
  openingTimer = setTimeout(() => {
    if (video.currentTime === 0 || video.readyState < 2) useOpeningFallback();
    else showNames();
  }, 6000);
  video.muted = true;
  try {
    const playback = video.play();
    if (playback) playback.catch(useOpeningFallback);
  } catch { useOpeningFallback(); }
});
video.addEventListener('ended', () => { clearTimeout(openingTimer); showNames(); });
video.addEventListener('error', useOpeningFallback);
if (video.error) useOpeningFallback();
const observer = new IntersectionObserver(entries => entries.forEach(entry => { if (entry.isIntersecting) { entry.target.classList.add('in'); observer.unobserve(entry.target); } }), { threshold: .12 });
document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
function tick() { let remaining = Math.max(0, date.getTime() - Date.now()); const values = [Math.floor(remaining / 86400000), Math.floor(remaining / 3600000) % 24, Math.floor(remaining / 60000) % 60, Math.floor(remaining / 1000) % 60]; ['days','hours','minutes','seconds'].forEach((id,i) => $(id).textContent = String(values[i]).padStart(2,'0')); if (!remaining) $('countdown-caption').textContent = 'The celebration has begun'; }
tick(); setInterval(tick, 1000);
const canvas = $('scratch-canvas'), ctx = canvas.getContext('2d'); let scratching = false, revealed = false, lastPoint;
function paintScratch() { if (revealed) return; const box = canvas.getBoundingClientRect(), ratio = devicePixelRatio || 1; canvas.width = Math.round(box.width * ratio); canvas.height = Math.round(box.height * ratio); ctx.setTransform(ratio,0,0,ratio,0,0); ctx.globalCompositeOperation = 'source-over'; const gradient = ctx.createLinearGradient(0,0,box.width,box.height); gradient.addColorStop(0,'#c5cca8');gradient.addColorStop(.5,'#e4e6cd');gradient.addColorStop(1,'#a3b08c');ctx.fillStyle=gradient;ctx.fillRect(0,0,box.width,box.height);ctx.strokeStyle='#6b7d5560';ctx.strokeRect(10,10,box.width-20,box.height-20); }
function revealDate() { if(revealed) return; revealed=true; $('scratch').classList.add('revealed'); $('reveal-date').disabled=true; $('status').textContent=`Save the date: ${fmt({day:'numeric',month:'long',year:'numeric'})}`;setTimeout(()=>$('status').textContent='',3500); }
function scratch(e) { const box=canvas.getBoundingClientRect(), point={x:e.clientX-box.left,y:e.clientY-box.top};ctx.globalCompositeOperation='destination-out';ctx.lineWidth=48;ctx.lineCap='round';ctx.beginPath();ctx.moveTo(lastPoint?.x??point.x,lastPoint?.y??point.y);ctx.lineTo(point.x,point.y);ctx.stroke();lastPoint=point; }
canvas.addEventListener('pointerdown',e=>{scratching=true;lastPoint=null;canvas.setPointerCapture(e.pointerId);scratch(e);$('reveal-date').style.opacity='0';});
canvas.addEventListener('pointermove',e=>{if(scratching)scratch(e);});
canvas.addEventListener('pointerup',()=>{scratching=false;lastPoint=null;const pixels=ctx.getImageData(0,0,canvas.width,canvas.height).data;let clear=0,total=0;for(let i=3;i<pixels.length;i+=64){total++;if(pixels[i]<128)clear++;}if(clear/total>.3)revealDate();});
canvas.addEventListener('pointercancel',()=>{scratching=false;lastPoint=null;});
$('reveal-date').addEventListener('click',revealDate);
canvas.addEventListener('click',e=>{if(e.detail===1 && !revealed && lastPoint===null) revealDate();});
new ResizeObserver(paintScratch).observe($('scratch'));
$('calendar').addEventListener('click',()=>{const stamp=d=>d.toISOString().replace(/[-:]/g,'').replace(/\.\d{3}Z/,'Z');const escape=s=>s.replace(/\\/g,'\\\\').replace(/\n/g,'\\n').replace(/,/g,'\\,').replace(/;/g,'\\;');const text=['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//Walima Invitation//EN','BEGIN:VEVENT',`UID:${stamp(date)}-wedding@invitation.local`,`DTSTAMP:${stamp(new Date())}`,`DTSTART:${stamp(date)}`,`DTEND:${stamp(new Date(wedding.endDate))}`,`SUMMARY:${escape(wedding.groom+' & '+wedding.bride+' Walima')}`,`LOCATION:${escape(wedding.venue+', '+wedding.address)}`,'END:VEVENT','END:VCALENDAR'].join('\r\n');const url=URL.createObjectURL(new Blob([text],{type:'text/calendar;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download='Maaz-Khan-and-Taushiba-Khan-Walima.ics';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
// A quiet, original instrumental loop, synthesized locally without external audio requests.
let audio, timer, playing=false;
function melody() { const notes=[261.63,329.63,392,523.25,440,392,329.63,293.66]; notes.forEach((frequency,i)=>{const osc=audio.createOscillator(),gain=audio.createGain(),start=audio.currentTime+i*.65;osc.type='sine';osc.frequency.value=frequency;gain.gain.setValueAtTime(0,start);gain.gain.linearRampToValueAtTime(.055,start+.03);gain.gain.exponentialRampToValueAtTime(.001,start+1.8);osc.connect(gain);gain.connect(audio.destination);osc.start(start);osc.stop(start+1.9);}); }
$('music').addEventListener('click',async()=>{try{audio ||= new(window.AudioContext||window.webkitAudioContext)();if(playing){clearInterval(timer);await audio.suspend();playing=false;}else{await audio.resume();melody();timer=setInterval(melody,5200);playing=true;}$('music').setAttribute('aria-pressed',String(playing));$('music').setAttribute('aria-label',playing?'Pause background music':'Play background music');$('music').title=playing?'Pause background music':'Play background music';}catch{$('status').textContent='Music is unavailable in this browser.';setTimeout(()=>$('status').textContent='',3500);}});
