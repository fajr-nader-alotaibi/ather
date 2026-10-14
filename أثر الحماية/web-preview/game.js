(() => {
  "use strict";
  const canvas = document.getElementById("world");
  const ctx = canvas.getContext("2d");
  const shell = document.querySelector(".game-shell");
  const seedCounter = document.getElementById("seed-count");
  const seedLabel = document.getElementById("seed-label");
  const objective = document.getElementById("objective");
  const hint = document.getElementById("hint");
  const rootThread = document.querySelector(".root-thread");
  const veil = document.getElementById("veil");
  const modalTitle = document.getElementById("modal-title");
  const modalCopy = document.getElementById("modal-copy");
  const resumeButton = document.getElementById("resume");
  const restartButton = document.getElementById("restart");
  const pauseButton = document.getElementById("pause");
  const languageButton = document.getElementById("language");
  const W = 3600, H = 720, VIEW_W = 1280, VIEW_H = 720;
  const ground = [
    [0,1110,620], [735,1015,524], [1080,1360,620], [1415,1535,554],
    [1620,1750,520], [1775,2325,620], [2510,2700,505], [2680,W,620]
  ];
  const art = {};
  for (const [name, src] of Object.entries({
    background: "../assets/hope_forest.svg", explorer: "../assets/explorer.svg",
    companion: "../assets/companion.svg", seed: "../assets/seed.svg"
  })) {
    art[name] = new Image(); art[name].src = src;
  }
  const keys = new Set();
  const touches = new Set();
  const player = { x: 160, y: 572, vx: 0, vy: 0, w: 36, h: 70, grounded: false, coyote: 0, buffer: 0, face: 1 };
  const seeds = [
    {x:505,y:470,got:false}, {x:928,y:414,got:false}, {x:1652,y:438,got:false}
  ];
  let count = 0, restored = false, won = false, paused = false, time = 0, cameraX = 0, toast = "", toastTimer = 0, language = "ar";
  const plant = {x:2186,y:544};
  const gate = {x:3370,y:558};
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const isDown = (action) => touches.has(action) ||
    (action === "move_left" && (keys.has("ArrowLeft") || keys.has("a") || keys.has("A"))) ||
    (action === "move_right" && (keys.has("ArrowRight") || keys.has("d") || keys.has("D"))) ||
    (action === "jump" && (keys.has(" ") || keys.has("ArrowUp") || keys.has("w") || keys.has("W")));
  const tr = (ar, en) => language === "ar" ? ar : en;

  function reset() {
    Object.assign(player, {x:160,y:572,vx:0,vy:0,grounded:false,coyote:0,buffer:0,face:1});
    for (const seed of seeds) seed.got = false;
    count = 0; restored = false; won = false; paused = false; toast = ""; toastTimer = 0;
    veil.hidden = true; updateHud();
  }
  function updateHud() {
    seedCounter.innerHTML = `${count} <i>/ 3</i>`;
    rootThread.classList.toggle("awake", restored);
    objective.textContent = restored
      ? tr("عاد النور! اعبر الجسر واتبع اليراعات.", "The grove is waking. Cross the bridge and follow the fireflies.")
      : tr("اجمع ٣ بذور قمرية وأيقظ الجسر الجذري.", "Gather 3 moonseeds and wake the root bridge.");
    seedLabel.textContent = tr("بذور القمر", "MOONSEEDS");
    document.documentElement.lang = language;
    document.documentElement.dir = language === "ar" ? "rtl" : "ltr";
    languageButton.textContent = tr("العربية / EN", "العربية / EN");
    pauseButton.setAttribute("aria-label", tr("إيقاف مؤقت", "Pause"));
    const nearPlant = Math.hypot(player.x - plant.x, player.y - plant.y) < 180;
    const nearGate = Math.hypot(player.x - gate.x, player.y - gate.y) < 190;
    let message = tr("A / D أو الأسهم للحركة · Space للقفز · E للتفاعل", "A / D or arrows to move · Space to leap · E to interact");
    if (toastTimer > 0) message = toast;
    else if (nearPlant && !restored) message = count >= 3
      ? tr("اقترب واضغط E لإيقاظ البذرة", "Press E to wake the root")
      : tr("هذه البذرة تحتاج إلى ٣ بذور قمرية", "This sprout needs all 3 moonseeds");
    else if (nearGate) message = restored
      ? tr("اضغط E لعبور البوابة", "Press E to pass the lantern gate")
      : tr("البوابة تنتظر عودة الجسر", "The gate waits for the root bridge");
    hint.textContent = message;
  }
  function showModal(kind) {
    veil.hidden = false;
    if (kind === "win") {
      modalTitle.textContent = tr("عاد الأثر إلى الغابة!", "The forest remembers");
      modalCopy.textContent = tr("عادت الجذور إلى الحياة، وصار للطريق أثر أخضر جديد.", "You restored the root bridge and brought the first colors back to Hope Forest.");
      resumeButton.textContent = tr("العب من جديد", "Walk the trail again");
      resumeButton.onclick = reset;
      restartButton.hidden = true;
    } else {
      modalTitle.textContent = tr("استراحة بين الأشجار", "A quiet clearing");
      modalCopy.textContent = tr("تتحرك الغابة عندما تعود.", "The forest will wait for you here.");
      resumeButton.textContent = tr("متابعة الرحلة", "Return to the trail");
      resumeButton.onclick = () => { paused = false; veil.hidden = true; };
      restartButton.hidden = false;
      restartButton.textContent = tr("إعادة من البداية", "Start this trail again");
    }
  }
  function togglePause() {
    if (won) return;
    paused = !paused;
    if (paused) showModal("pause"); else veil.hidden = true;
  }

  function step(dt) {
    if (paused || won) return;
    time += dt;
    toastTimer = Math.max(0, toastTimer - dt);
    const axis = (isDown("move_right") ? 1 : 0) - (isDown("move_left") ? 1 : 0);
    if (axis) player.face = axis;
    player.vx += (axis * 300 - player.vx) * Math.min(1, (player.grounded ? 11 : 7) * dt);
    if (!axis && player.grounded) player.vx *= Math.max(0, 1 - 9 * dt);
    if (pressedJump) { player.buffer = .13; pressedJump = false; }
    else player.buffer = Math.max(0, player.buffer - dt);
    if (player.grounded) player.coyote = .12; else player.coyote = Math.max(0, player.coyote - dt);
    if (player.buffer && player.coyote) { player.vy = -650; player.buffer = player.coyote = 0; player.grounded = false; }
    else player.vy += 1750 * dt;
    if (!isDown("jump") && player.vy < -240) player.vy += 1400 * dt;
    const oldBottom = player.y + player.h / 2;
    const oldX = player.x;
    player.x += player.vx * dt;
    player.y += player.vy * dt;
    player.grounded = false;
    const bottom = player.y + player.h / 2;
    for (const [x1, x2, top] of activeTerrain()) {
      const overlapsWall = bottom > top + 8 && player.y - player.h / 2 < top + 68;
      if (overlapsWall && oldX + player.w / 2 <= x1 && player.x + player.w / 2 > x1) {
        player.x = x1 - player.w / 2; player.vx = 0;
      } else if (overlapsWall && oldX - player.w / 2 >= x2 && player.x - player.w / 2 < x2) {
        player.x = x2 + player.w / 2; player.vx = 0;
      }
      if (player.x + player.w/2 > x1 && player.x - player.w/2 < x2 && oldBottom <= top+8 && bottom >= top && player.vy >= 0) {
        player.y = top - player.h/2; player.vy = 0; player.grounded = true;
      }
    }
    player.x = clamp(player.x, 20, W-20);
    if (player.y > 900) Object.assign(player,{x:160,y:572,vx:0,vy:0});
    for (const seed of seeds) {
      if (!seed.got && Math.hypot(player.x-seed.x, player.y-seed.y) < 57) {
        seed.got = true; count++; toast = tr("بذرة جديدة!", "Moonseed found!"); toastTimer = 1.5;
      }
    }
    cameraX = clamp(player.x - VIEW_W*.5, 0, W - VIEW_W);
    updateHud();
  }
  let pressedJump = false;
  function interact() {
    if (paused || won) return;
    if (Math.hypot(player.x-plant.x, player.y-plant.y) < 130 && !restored) {
      if (count < 3) { toast = tr("اجمع كل البذور أولًا.", "Gather all three moonseeds first."); toastTimer=1.8; }
      else { restored = true; count -= 3; toast = tr("الجسر عاد للحياة!", "The bridge is alive again!"); toastTimer=2.2; }
    } else if (Math.hypot(player.x-gate.x, player.y-gate.y) < 135) {
      if (restored) { won=true; showModal("win"); }
      else { toast = tr("أعد الحياة إلى الجسر أولًا.", "Restore the root bridge first."); toastTimer=1.8; }
    }
    updateHud();
  }
  function activeTerrain() { return restored ? [...ground,[2320,2684,620]] : ground; }

  function drawTerrain(seg, bridge=false) {
    const [x1,x2,y]=seg, width=x2-x1;
    ctx.save(); ctx.translate(x1-cameraX,y);
    ctx.beginPath(); ctx.moveTo(0,7); ctx.quadraticCurveTo(width*.22,0,width*.38,8); ctx.quadraticCurveTo(width*.7,1,width-4,7); ctx.lineTo(width,69); ctx.lineTo(0,69); ctx.closePath();
    ctx.fillStyle=bridge?"#746543":"#725248"; ctx.fill();
    ctx.strokeStyle="#36464a"; ctx.lineWidth=4; ctx.stroke();
    ctx.beginPath(); ctx.moveTo(3,34); ctx.quadraticCurveTo(width*.22,25,width*.4,38); ctx.quadraticCurveTo(width*.7,26,width-3,36); ctx.lineTo(width-3,67); ctx.lineTo(3,67); ctx.closePath(); ctx.fillStyle=bridge?"#535448":"#514341"; ctx.fill();
    ctx.beginPath(); ctx.moveTo(5,9); ctx.quadraticCurveTo(width*.23,4,width*.4,13); ctx.quadraticCurveTo(width*.67,2,width-5,10); ctx.lineTo(width-5,19); ctx.quadraticCurveTo(width*.7,16,width*.46,21); ctx.quadraticCurveTo(width*.2,15,5,20); ctx.closePath();
    ctx.fillStyle=bridge?"#b3ce76":"#78955e"; ctx.fill();
    ctx.strokeStyle=bridge?"#e2d88c":"#adbd70"; ctx.lineWidth=3; ctx.beginPath(); ctx.moveTo(5,10);ctx.lineTo(width-5,10);ctx.stroke();
    for(let x=18;x<width-12;x+=39){let k=(Math.sin(x*4.73)+1)/2;ctx.fillStyle="#987366";ctx.beginPath();ctx.ellipse(x,45+k*12,5+k*3,3+k*2,0,0,Math.PI*2);ctx.fill();if(bridge&&x%3<1){ctx.fillStyle="#f1d38f";ctx.beginPath();ctx.arc(x,14,2.4,0,7);ctx.fill();}}
    ctx.restore();
  }
  function drawSprout() {
    const x=plant.x-cameraX,y=620;
    ctx.save();ctx.translate(x,y);ctx.lineCap="round";
    ctx.strokeStyle=restored?"#72b995":"#8f7770";ctx.lineWidth=8;ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(0,-58);ctx.moveTo(0,-28);ctx.lineTo(-26,restored?-48:-35);ctx.moveTo(0,-37);ctx.lineTo(24,restored?-58:-43);ctx.stroke();
    if(restored){leaf(-27,-50,-.4,"#a6d77b");leaf(24,-60,.55,"#8bcf88");for(let i=0;i<5;i++){let a=i*Math.PI*2/5;ctx.fillStyle="#f7cc83";ctx.beginPath();ctx.arc(Math.cos(a)*12, -65+Math.sin(a)*12,7,0,7);ctx.fill();}ctx.fillStyle="#fff1b0";ctx.beginPath();ctx.arc(0,-65,7,0,7);ctx.fill();ctx.fillStyle="#d4f0a2";ctx.globalAlpha=.24;ctx.beginPath();ctx.arc(0,-58,34+Math.sin(time*2.5)*3,0,7);ctx.fill();ctx.globalAlpha=1;}
    else {leaf(-22,-37,1.1,"#788267");leaf(22,-44,-.9,"#726d68");ctx.fillStyle="#82717a";ctx.beginPath();ctx.arc(0,-56,10,0,7);ctx.fill();}
    ctx.restore();
  }
  function leaf(x,y,a,color){ctx.save();ctx.translate(x,y);ctx.rotate(a);ctx.fillStyle=color;ctx.beginPath();ctx.moveTo(-4,0);ctx.quadraticCurveTo(0,-23,15,-14);ctx.quadraticCurveTo(21,-1,8,6);ctx.closePath();ctx.fill();ctx.restore();}
  function drawGate() {
    const x=gate.x-cameraX,y=gate.y;ctx.save();ctx.lineWidth=10;ctx.strokeStyle=restored?"#d8b57b":"#8293a2";ctx.beginPath();ctx.arc(x,y,51,Math.PI,Math.PI*2);ctx.stroke();ctx.fillStyle=restored?"#f9d586":"#8e9da9";ctx.beginPath();ctx.arc(x,y-47,13+Math.sin(time*2.2)*2,0,7);ctx.fill();ctx.globalAlpha=.15;ctx.beginPath();ctx.arc(x,y-47,25,0,7);ctx.fill();ctx.restore();}
  function drawMushroom(x,y,s,c){x-=cameraX;let h=48*s,w=47*s;ctx.fillStyle="#d7ac91";ctx.fillRect(x-w*.22,y-h,w*.44,h);ctx.fillStyle=c;ctx.strokeStyle="#553e43";ctx.lineWidth=4*s;ctx.beginPath();ctx.moveTo(x-w,y-h);ctx.quadraticCurveTo(x-w*.88,y-h*1.9,x,y-h*1.9);ctx.quadraticCurveTo(x+w*.95,y-h*1.8,x+w,y-h);ctx.closePath();ctx.fill();ctx.stroke();ctx.strokeStyle="#f2c8a1";ctx.lineWidth=4*s;ctx.beginPath();ctx.moveTo(x-w*.72,y-h-3);ctx.lineTo(x+w*.7,y-h-3);ctx.stroke();}
  function draw() {
    ctx.clearRect(0,0,VIEW_W,VIEW_H);
    if (art.background.complete && art.background.naturalWidth) ctx.drawImage(art.background,-cameraX,0,W,H);
    else {const grad=ctx.createLinearGradient(0,0,0,H);grad.addColorStop(0,"#182e43");grad.addColorStop(1,"#a87c8a");ctx.fillStyle=grad;ctx.fillRect(0,0,W,H);}
    if(restored){ctx.save();ctx.globalAlpha=.11;ctx.fillStyle="#ccf0b4";ctx.fillRect(0,0,VIEW_W,VIEW_H);ctx.restore();}
    for(const seg of activeTerrain())drawTerrain(seg,seg[0]===2320);
    drawMushroom(685,620,.85,"#c77e77");drawMushroom(1160,620,.62,"#da9777");drawMushroom(1880,620,.72,"#b97881");drawMushroom(2900,620,.9,"#d08c78");
    drawSprout();drawGate();
    for(const seed of seeds){if(seed.got)continue;let sx=seed.x-cameraX,sy=seed.y+Math.sin(time*2.6+seed.x)*5;if(art.seed.complete&&art.seed.naturalWidth)ctx.drawImage(art.seed,sx-31,sy-31,62,62);else{ctx.fillStyle="#f5d47e";ctx.beginPath();ctx.arc(sx,sy,13,0,7);ctx.fill();}}
    const companionX=player.x-48-cameraX,companionY=player.y-78+Math.sin(time*2.8)*10;
    if(art.companion.complete&&art.companion.naturalWidth)ctx.drawImage(art.companion,companionX-50,companionY-50,100,100);
    if(art.explorer.complete&&art.explorer.naturalWidth){ctx.save();ctx.translate(player.x-cameraX,player.y-13+Math.sin(time*8)*(player.grounded&&Math.abs(player.vx)>10?2:0));ctx.scale(player.face,1);ctx.drawImage(art.explorer,-53,-61,106,123);ctx.restore();}
    if(toastTimer>0){ctx.save();ctx.globalAlpha=Math.min(1,toastTimer);ctx.fillStyle="#fff0cc";ctx.font="bold 25px Amiri,serif";ctx.textAlign="center";ctx.shadowColor="#19353b";ctx.shadowBlur=11;ctx.fillText(toast,640,182);ctx.restore();}
  }

  window.addEventListener("keydown",e=>{if(["ArrowLeft","ArrowRight","ArrowUp","Space"].includes(e.code))e.preventDefault();keys.add(e.key);if((e.code==="Space"||e.code==="ArrowUp"||e.code==="KeyW")&&!e.repeat)pressedJump=true;if(e.code==="KeyE"&&!e.repeat)interact();if(e.code==="Escape"&&!e.repeat)togglePause();});
  window.addEventListener("keyup",e=>keys.delete(e.key));
  window.addEventListener("blur",()=>{keys.clear();touches.clear();});
  languageButton.addEventListener("click",()=>{language=language==="ar"?"en":"ar";updateHud();});
  pauseButton.addEventListener("click",togglePause);
  restartButton.addEventListener("click",reset);
  for(const button of document.querySelectorAll("[data-action]")){
    const action=button.dataset.action;
    button.addEventListener("pointerdown",e=>{e.preventDefault();button.setPointerCapture(e.pointerId);touches.add(action);if(action==="jump")pressedJump=true;if(action==="interact")interact();});
    const release=()=>touches.delete(action);button.addEventListener("pointerup",release);button.addEventListener("pointercancel",release);button.addEventListener("lostpointercapture",release);
  }
  let last=performance.now();
  function frame(now){const dt=Math.min(.034,(now-last)/1000);last=now;step(dt);draw();requestAnimationFrame(frame);}
  updateHud();requestAnimationFrame(frame);
})();
