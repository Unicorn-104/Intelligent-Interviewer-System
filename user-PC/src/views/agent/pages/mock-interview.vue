<template>
<header class="topbar">
    <div class="topbar-inner">
      <a class="brand" :href="appHref('/index')"><span class="brand-mark">智</span><span class="brand-name">智聘 AI</span><span class="brand-tag">模拟面试</span></a>
      <div class="header-context">
        <span class="secure-state"><svg viewBox="0 0 24 24"><path d="M7 10V7a5 5 0 0 1 10 0v3M5 10h14v11H5z"/></svg>设备画面仅在本机预览</span>
        <a class="exit-link" id="exitLink" :href="appHref('/applications')">退出模拟</a>
      </div>
    </div>
  </header>

  <main class="page">
    <section class="panel session-strip" aria-labelledby="pageTitle">
      <div><div class="session-kicker"><span class="live-dot"></span>AI 模拟面试</div><h1 id="pageTitle">高级产品经理（AI 方向）</h1><div class="session-meta" id="companyMeta">极氪智能科技有限公司 · 共 8 道岗位高频问题</div></div>
      <div class="stage-track" aria-label="模拟面试进度"><div class="stage active" data-stage="setup"><span class="stage-num">1</span>设备准备</div><span class="stage-line"></span><div class="stage" data-stage="answer"><span class="stage-num">2</span>模拟答题</div><span class="stage-line"></span><div class="stage" data-stage="result"><span class="stage-num">3</span>完成评估</div></div>
    </section>

    <!-- 第一步：先由用户主动开启摄像头和麦克风 -->
    <section class="setup-layout" id="setupView">
      <div class="panel preview-panel">
        <div class="preview-head"><h2>画面预览</h2><span>请保持面部居中，光线从正面照射</span></div>
        <div class="video-stage is-off" id="setupVideoStage"><video id="setupVideo" autoplay playsinline muted></video><div class="camera-empty"><div class="camera-empty-icon"><svg viewBox="0 0 24 24"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3M4 4l16 16"/></svg></div><strong>摄像头尚未开启</strong><span>点击下方按钮后，浏览器会请求设备权限</span></div><span class="camera-label">林晓雨 · 求职者</span></div>
        <div class="device-bar"><button class="icon-button" id="setupCameraButton"><svg viewBox="0 0 24 24"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/></svg><span>开启摄像头</span></button><button class="icon-button" id="setupMicButton"><svg viewBox="0 0 24 24"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3M9 21h6"/></svg><span>开启麦克风</span></button><span class="device-help">也可以不启用设备，直接进入文字模拟</span></div>
      </div>
      <aside class="panel setup-panel">
        <div class="setup-head"><h2>面试前检查</h2><p>确认以下项目后即可开始，本次模拟不会上传或保存音视频。</p></div>
        <ul class="check-list">
          <li class="check-item"><span class="check-icon"><svg viewBox="0 0 24 24"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/></svg></span><div><strong>摄像头</strong><small id="cameraDetail">尚未检测</small></div><span class="check-state" id="cameraState">未开启</span></li>
          <li class="check-item"><span class="check-icon"><svg viewBox="0 0 24 24"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3M9 21h6"/></svg></span><div><strong>麦克风</strong><small id="micDetail">尚未检测</small></div><span class="check-state" id="micState">未开启</span></li>
          <li class="check-item"><span class="check-icon"><svg viewBox="0 0 24 24"><path d="M4 8h16M4 12h10M4 16h7"/></svg></span><div><strong>答题环境</strong><small>建议预留约 20 分钟，保持网络稳定</small></div><span class="check-state ok">已就绪</span></li>
        </ul>
        <div class="notice" id="deviceNotice">摄像头为可选项。开启后可在答题时观察自己的画面表现，也可随时关闭。</div>
        <p class="privacy">开始即表示你已了解：本页面仅用于模拟练习，回答保存在当前浏览器页面，退出后自动清除。</p>
        <button class="primary-button" id="startButton">开始模拟面试</button>
      </aside>
    </section>

    <!-- 第二步：逐题作答 -->
    <section class="interview-view" id="interviewView">
      <div class="panel question-panel">
        <div class="question-head"><div class="progress-copy">当前进度 <strong id="questionProgress">1 / 8</strong></div><div class="timer" id="timer"><svg viewBox="0 0 24 24"><circle cx="12" cy="13" r="8"/><path d="M12 9v5l3 2M9 3h6"/></svg><span id="timerText">02:00</span></div></div>
        <div class="progress-line"><span id="progressBar"></span></div>
        <div class="question-body"><span class="competency" id="competency">表达与岗位动机</span><span class="question-number" id="questionNumber">问题 01</span><h2 class="question-title" id="questionTitle"></h2><label class="answer-label" for="answerInput">你的回答 <span class="answer-count" id="answerCount">0 / 800</span></label><textarea class="answer-input" id="answerInput" maxlength="800" placeholder="请结合真实经历作答。建议使用 STAR 结构，说明背景、任务、行动与结果。"></textarea><p class="answer-tip">回答会自动暂存。你可以返回上一题继续补充。</p></div>
        <div class="question-actions"><button class="secondary-button" id="prevButton">上一题</button><button class="text-button" id="skipButton">暂时跳过</button><button class="next-button" id="nextButton">保存并进入下一题</button></div>
      </div>
      <aside class="side-stack">
        <div class="panel preview-panel mini-video"><div class="preview-head"><h2>面试画面</h2><span id="liveDeviceState">设备未开启</span></div><div class="video-stage is-off" id="interviewVideoStage"><video id="interviewVideo" autoplay playsinline muted></video><div class="camera-empty"><div class="camera-empty-icon"><svg viewBox="0 0 24 24"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3M4 4l16 16"/></svg></div><strong>摄像头已关闭</strong></div><span class="camera-label">林晓雨 · 求职者</span></div><div class="device-bar"><button class="icon-button" id="cameraToggle" title="开启或关闭摄像头"><svg viewBox="0 0 24 24"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/></svg><span>摄像头</span></button><button class="icon-button" id="micToggle" title="开启或关闭麦克风"><svg viewBox="0 0 24 24"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3M9 21h6"/></svg><span>麦克风</span></button></div></div>
        <div class="panel coach-panel"><div class="coach-head"><span><svg viewBox="0 0 24 24"><path d="M9 18h6M10 22h4M8 14a6 6 0 1 1 8 0c-1.2.8-1 2-1 2H9s.2-1.2-1-2Z"/></svg></span>回答建议</div><ul class="coach-list" id="coachList"></ul></div>
        <div class="panel answer-overview"><h3>答题概览</h3><div class="answer-dots" id="answerDots"></div></div>
      </aside>
    </section>

    <!-- 第三步：本地生成练习结果 -->
    <section class="result-view" id="resultView"><div class="panel result-panel"><div class="result-mark"><svg viewBox="0 0 24 24"><path d="m5 12 4 4L19 6"/></svg></div><h2>本次模拟面试已完成</h2><p>以下结果根据答题完整度生成，仅作为练习参考。</p><div class="score-row"><div class="score-cell"><strong id="scoreValue">--</strong><small>模拟完成度</small></div><div class="score-cell"><strong id="answeredValue">--</strong><small>已回答</small></div><div class="score-cell"><strong id="skippedValue">--</strong><small>待补充</small></div></div><div class="feedback"><strong>练习建议</strong><p id="feedbackText"></p></div><div class="result-actions"><a id="returnLink" :href="appHref('/applications')">返回投递跟踪</a><button id="restartButton">重新模拟</button></div></div></section>
  </main>
  <div class="toast" id="toast" role="status" aria-live="polite"></div>
</template>

<script setup>
import { appHref } from '@/utils/agentNavigation'
import { onMounted } from 'vue'
import { resolveApplicationDetailPath } from '@/utils/agentApplication'

onMounted(async () => {
  // 根据投递详情传入的岗位 ID，展示对应的模拟面试内容。
      const jobProfiles={
        'ai-product':{title:'高级产品经理（AI 方向）',company:'极氪智能科技有限公司'},
        'frontend-react':{title:'前端开发工程师（React）',company:'杭州云杉网络技术有限公司'},
        'nlp-algorithm':{title:'算法工程师（NLP 方向）',company:'北京智谱华章科技有限公司'},
        'saas-ux':{title:'UI/UX 设计师（企业级 SaaS）',company:'深圳蓝色光标数据科技有限公司'},
        'test-engineer':{title:'测试开发工程师（自动化）',company:'苏州讯飞智能科技有限公司'}
      };
      const questions=[
        {type:'表达与岗位动机',title:'请用 1 分钟介绍你自己，并说明为什么适合这个岗位。',tips:['突出与岗位直接相关的经验','用一个量化结果建立可信度','在结尾说明你的求职动机']},
        {type:'项目复盘',title:'介绍一个你主导的 AI 产品项目，你解决了什么核心问题？',tips:['说明业务背景与目标用户','明确你承担的职责和关键决策','用上线结果验证解决方案']},
        {type:'场景判断',title:'你会如何判断一个业务场景是否适合接入大模型？',tips:['从用户价值与使用频率出发','评估准确性、成本和响应速度','考虑传统方案作为对照组']},
        {type:'产品设计',title:'大模型回答出现幻觉时，你会如何设计产品与评估方案？',tips:['区分可接受与高风险场景','说明检索增强、引用和兜底机制','给出可持续监测的评估指标']},
        {type:'协作推动',title:'请描述一次你与算法或研发团队产生分歧并推动落地的经历。',tips:['客观描述分歧的根因','说明如何用数据统一判断标准','补充最终结果与个人反思']},
        {type:'指标体系',title:'如何为智能招聘 Agent 设计核心指标体系？',tips:['覆盖效率、质量与用户体验','区分过程指标与结果指标','关注偏差、公平性和人工干预']},
        {type:'问题定位',title:'如果产品上线后用户转化率低于预期，你会如何定位问题？',tips:['先拆解完整的转化漏斗','结合定量数据与用户访谈','提出验证优先级和迭代闭环']},
        {type:'合规意识',title:'你如何看待 AI 面试中的公平性、隐私与合规问题？',tips:['说明数据最小化与授权原则','关注模型偏差和可解释性','保留人工复核与申诉通道']}
      ];
      const params=new URLSearchParams(location.search),jobId=params.get('job')||'ai-product',job=jobProfiles[jobId]||jobProfiles['ai-product'];
      const detailUrl=await resolveApplicationDetailPath(jobId);
      document.getElementById('pageTitle').textContent=job.title;document.getElementById('companyMeta').textContent=`${job.company} · 共 ${questions.length} 道岗位高频问题`;document.getElementById('exitLink').href=appHref(detailUrl);document.getElementById('returnLink').href=appHref(detailUrl);document.title=`${job.title} · AI 模拟面试`;
  
      let mediaStream=null,currentIndex=0,answers=Array(questions.length).fill(''),skipped=new Set(),secondsLeft=120,timerId=null;
      const setupView=document.getElementById('setupView'),interviewView=document.getElementById('interviewView'),resultView=document.getElementById('resultView'),answerInput=document.getElementById('answerInput');
      const toast=document.getElementById('toast');
      function showToast(message){toast.textContent=message;toast.classList.add('show');clearTimeout(showToast.timer);showToast.timer=setTimeout(()=>toast.classList.remove('show'),2600)}
      function videoTracks(){return mediaStream?mediaStream.getVideoTracks():[]}function audioTracks(){return mediaStream?mediaStream.getAudioTracks():[]}
      function isVideoOn(){return videoTracks().some(track=>track.enabled&&track.readyState==='live')}function isAudioOn(){return audioTracks().some(track=>track.enabled&&track.readyState==='live')}
      function stopDevices(){if(mediaStream)mediaStream.getTracks().forEach(track=>track.stop());mediaStream=null;[document.getElementById('setupVideo'),document.getElementById('interviewVideo')].forEach(video=>{video.srcObject=null});syncDeviceUI()}
  
      // 同一媒体流同时用于准备页和答题页预览，不进行录制或上传。
      function syncDeviceUI(){
        const cameraOn=isVideoOn(),micOn=isAudioOn();
        ['setupVideoStage','interviewVideoStage'].forEach(id=>document.getElementById(id).classList.toggle('is-off',!cameraOn));
        [document.getElementById('setupVideo'),document.getElementById('interviewVideo')].forEach(video=>{if(mediaStream&&video.srcObject!==mediaStream)video.srcObject=mediaStream});
        const setupCamera=document.getElementById('setupCameraButton'),setupMic=document.getElementById('setupMicButton'),cameraToggle=document.getElementById('cameraToggle'),micToggle=document.getElementById('micToggle');
        setupCamera.className=`icon-button ${cameraOn?'active':'off'}`;setupCamera.querySelector('span').textContent=cameraOn?'关闭摄像头':'开启摄像头';
        setupMic.className=`icon-button ${micOn?'active':'off'}`;setupMic.querySelector('span').textContent=micOn?'关闭麦克风':'开启麦克风';
        cameraToggle.className=`icon-button ${cameraOn?'active':'off'}`;micToggle.className=`icon-button ${micOn?'active':'off'}`;
        document.getElementById('cameraState').textContent=cameraOn?'已开启':'未开启';document.getElementById('cameraState').className=`check-state ${cameraOn?'ok':''}`;document.getElementById('cameraDetail').textContent=cameraOn?'画面预览正常':'尚未检测';
        document.getElementById('micState').textContent=micOn?'已开启':'未开启';document.getElementById('micState').className=`check-state ${micOn?'ok':''}`;document.getElementById('micDetail').textContent=micOn?'音频输入已连接':'尚未检测';
        document.getElementById('liveDeviceState').textContent=cameraOn?(micOn?'摄像头与麦克风已开启':'摄像头已开启'):(micOn?'麦克风已开启':'设备未开启');
      }
      async function requestDevices(preferVideo=true,preferAudio=true){
        if(!navigator.mediaDevices?.getUserMedia){showToast('当前浏览器不支持摄像头访问，可继续使用文字模拟。');return false}
        try{
          const requested=await navigator.mediaDevices.getUserMedia({video:preferVideo,audio:preferAudio});
          if(!mediaStream)mediaStream=new MediaStream();
          // 只替换本次请求的轨道，避免开启麦克风时关闭已经启用的摄像头。
          requested.getTracks().forEach(newTrack=>{mediaStream.getTracks().filter(track=>track.kind===newTrack.kind).forEach(oldTrack=>{oldTrack.stop();mediaStream.removeTrack(oldTrack)});mediaStream.addTrack(newTrack)});
          [document.getElementById('setupVideo'),document.getElementById('interviewVideo')].forEach(video=>{video.srcObject=null;video.srcObject=mediaStream});syncDeviceUI();document.getElementById('deviceNotice').textContent='设备连接正常。你可以在答题过程中随时关闭摄像头或麦克风。';return true;
        }catch(error){
          const denied=error.name==='NotAllowedError'||error.name==='SecurityError',missing=error.name==='NotFoundError'||error.name==='DevicesNotFoundError';
          document.getElementById('deviceNotice').textContent=denied?'未获得设备权限。请在浏览器地址栏中允许访问，或直接进入文字模拟。':missing?'未检测到可用的摄像头或麦克风，可直接进入文字模拟。':'设备暂时无法启用，可直接进入文字模拟。';
          showToast(document.getElementById('deviceNotice').textContent);return false;
        }
      }
      async function toggleDevice(kind){
        const tracks=kind==='video'?videoTracks():audioTracks();
        if(!tracks.length){await requestDevices(kind==='video',kind==='audio');return}
        tracks.forEach(track=>{track.enabled=!track.enabled});syncDeviceUI();
      }
      document.getElementById('setupCameraButton').addEventListener('click',()=>toggleDevice('video'));document.getElementById('setupMicButton').addEventListener('click',()=>toggleDevice('audio'));document.getElementById('cameraToggle').addEventListener('click',()=>toggleDevice('video'));document.getElementById('micToggle').addEventListener('click',()=>toggleDevice('audio'));
  
      function setStage(active){
        const order=['setup','answer','result'],activeIndex=order.indexOf(active);
        document.querySelectorAll('.stage').forEach((stage,index)=>{stage.classList.toggle('active',index===activeIndex);stage.classList.toggle('done',index<activeIndex);if(index<activeIndex)stage.querySelector('.stage-num').textContent='✓';else stage.querySelector('.stage-num').textContent=index+1});
        document.querySelectorAll('.stage-line').forEach((line,index)=>line.classList.toggle('done',index<activeIndex));
      }
      function renderDots(){
        const dots=document.getElementById('answerDots');dots.replaceChildren(...questions.map((_,index)=>{const button=document.createElement('button');button.className=`answer-dot ${index===currentIndex?'current':answers[index].trim()?'answered':skipped.has(index)?'skipped':''}`;button.textContent=index+1;button.title=`跳转到第 ${index+1} 题`;button.addEventListener('click',()=>{saveCurrent();currentIndex=index;renderQuestion()});return button}));
      }
      function saveCurrent(){answers[currentIndex]=answerInput.value.trim();if(answers[currentIndex])skipped.delete(currentIndex)}
      function startTimer(){clearInterval(timerId);secondsLeft=120;renderTimer();timerId=setInterval(()=>{secondsLeft--;renderTimer();if(secondsLeft<=0){clearInterval(timerId);saveCurrent();if(currentIndex<questions.length-1){skipped.add(currentIndex);currentIndex++;renderQuestion();showToast('本题时间已到，已进入下一题。')}else finishInterview()}},1000)}
      function renderTimer(){const minutes=String(Math.floor(secondsLeft/60)).padStart(2,'0'),seconds=String(secondsLeft%60).padStart(2,'0');document.getElementById('timerText').textContent=`${minutes}:${seconds}`;document.getElementById('timer').classList.toggle('warn',secondsLeft<=30)}
      function renderQuestion(){
        const item=questions[currentIndex];document.getElementById('questionProgress').textContent=`${currentIndex+1} / ${questions.length}`;document.getElementById('progressBar').style.width=`${((currentIndex+1)/questions.length)*100}%`;document.getElementById('competency').textContent=item.type;document.getElementById('questionNumber').textContent=`问题 ${String(currentIndex+1).padStart(2,'0')}`;document.getElementById('questionTitle').textContent=item.title;answerInput.value=answers[currentIndex];updateAnswerCount();
        const coach=document.getElementById('coachList');coach.replaceChildren(...item.tips.map(tip=>{const li=document.createElement('li');li.textContent=tip;return li}));document.getElementById('prevButton').disabled=currentIndex===0;document.getElementById('nextButton').textContent=currentIndex===questions.length-1?'完成模拟面试':'保存并进入下一题';renderDots();startTimer();answerInput.focus();
      }
      function updateAnswerCount(){document.getElementById('answerCount').textContent=`${answerInput.value.length} / 800`}
      answerInput.addEventListener('input',()=>{answers[currentIndex]=answerInput.value;updateAnswerCount();renderDots()});
      document.getElementById('startButton').addEventListener('click',()=>{setupView.style.display='none';interviewView.classList.add('active');setStage('answer');renderQuestion();window.scrollTo({top:0,behavior:'smooth'})});
      document.getElementById('prevButton').addEventListener('click',()=>{saveCurrent();if(currentIndex>0){currentIndex--;renderQuestion()}});
      document.getElementById('skipButton').addEventListener('click',()=>{answers[currentIndex]='';skipped.add(currentIndex);if(currentIndex<questions.length-1){currentIndex++;renderQuestion()}else finishInterview()});
      document.getElementById('nextButton').addEventListener('click',()=>{saveCurrent();if(currentIndex<questions.length-1){currentIndex++;renderQuestion()}else finishInterview()});
      function finishInterview(){
        saveCurrent();clearInterval(timerId);stopDevices();interviewView.classList.remove('active');resultView.classList.add('active');setStage('result');const answered=answers.filter(answer=>answer.trim()).length,missing=questions.length-answered,score=Math.round(answered/questions.length*100);document.getElementById('scoreValue').textContent=`${score}%`;document.getElementById('answeredValue').textContent=`${answered} 题`;document.getElementById('skippedValue').textContent=`${missing} 题`;document.getElementById('feedbackText').textContent=answered===questions.length?'你已完成全部问题。建议再次复盘回答中的量化结果，并将每题控制在 1-2 分钟内。':`你已完成 ${answered} 道问题，仍有 ${missing} 道待补充。建议优先完善项目复盘和岗位能力相关回答，再进行下一轮模拟。`;window.scrollTo({top:0,behavior:'smooth'});
      }
      document.getElementById('restartButton').addEventListener('click',()=>{answers=Array(questions.length).fill('');skipped.clear();currentIndex=0;resultView.classList.remove('active');setupView.style.display='grid';setStage('setup');window.scrollTo({top:0,behavior:'smooth'})});
      window.addEventListener('beforeunload',stopDevices);
      syncDeviceUI();
})
</script>

<style>
:root{
      --primary:#1A3C6E;--blue:#2B7FFF;--blue-dark:#1D68DB;--blue-soft:#EDF4FF;
      --bg:#F5F7FA;--card:#FFFFFF;--text:#172B4D;--muted:#66758A;--light:#93A0B2;
      --line:#E2E8F0;--green:#169B69;--green-soft:#EAF7F1;--amber:#C57712;
      --amber-soft:#FFF5E8;--red:#D94B55;--shadow:0 8px 24px rgba(26,60,110,.06)
    }
    *{box-sizing:border-box}
    html{scroll-behavior:smooth}
    body{margin:0;background:var(--bg);color:var(--text);font-family:"PingFang SC","Microsoft YaHei",system-ui,-apple-system,"Segoe UI",sans-serif;font-size:14px;line-height:1.55}
    button,textarea{font:inherit}button{cursor:pointer}svg{display:block}a{color:inherit}
    button:focus-visible,a:focus-visible,textarea:focus-visible{outline:3px solid rgba(43,127,255,.22);outline-offset:2px}

    /* 聚焦面试任务的顶部栏 */
    .topbar{height:68px;border-bottom:1px solid var(--line);background:#fff}
    .topbar-inner{width:min(1280px,calc(100% - 48px));height:100%;margin:auto;display:flex;align-items:center;gap:24px}
    .brand{display:flex;align-items:center;gap:10px;text-decoration:none;color:var(--primary);white-space:nowrap}
    .brand-mark{width:34px;height:34px;display:grid;place-items:center;border-radius:8px;color:#fff;background:var(--primary);font-size:17px;font-weight:800}
    .brand-name{font-size:18px;font-weight:800}.brand-tag{color:var(--muted);font-size:11px}
    .header-context{margin-left:auto;display:flex;align-items:center;gap:18px;color:var(--muted);font-size:12px}
    .secure-state{display:flex;align-items:center;gap:7px}.secure-state svg{width:16px;height:16px;fill:none;stroke:var(--green);stroke-width:1.8}
    .exit-link{height:34px;padding:0 13px;display:inline-flex;align-items:center;border:1px solid var(--line);border-radius:6px;text-decoration:none;color:var(--primary);font-weight:700;background:#fff}
    .exit-link:hover{border-color:#B9C9DE;background:#F8FAFD}

    .page{width:min(1280px,calc(100% - 48px));margin:0 auto;padding:24px 0 42px}
    .panel{border:1px solid var(--line);border-radius:8px;background:#fff;box-shadow:var(--shadow)}
    .session-strip{display:grid;grid-template-columns:minmax(0,1fr) auto;align-items:center;gap:24px;padding:17px 20px}
    .session-kicker{display:flex;align-items:center;gap:8px;color:var(--blue);font-size:11px;font-weight:700}
    .live-dot{width:7px;height:7px;border-radius:50%;background:var(--blue);box-shadow:0 0 0 4px var(--blue-soft)}
    .session-strip h1{margin:4px 0 0;color:var(--primary);font-size:20px;letter-spacing:0}
    .session-meta{margin-top:5px;color:var(--muted);font-size:11px}
    .stage-track{display:flex;align-items:center}.stage{display:flex;align-items:center;gap:7px;color:var(--light);font-size:11px;font-weight:700}
    .stage-num{width:24px;height:24px;display:grid;place-items:center;border:1px solid #D6DFEA;border-radius:50%;background:#fff;font-size:10px}
    .stage.active{color:var(--blue)}.stage.active .stage-num{border-color:var(--blue);color:#fff;background:var(--blue)}
    .stage.done{color:var(--primary)}.stage.done .stage-num{border-color:var(--green);color:var(--green);background:var(--green-soft)}
    .stage-line{width:42px;height:1px;margin:0 8px;background:#DCE4EE}.stage-line.done{background:var(--green)}

    /* 设备预检 */
    .setup-layout{display:grid;grid-template-columns:minmax(0,1.4fr) minmax(330px,.8fr);gap:16px;margin-top:16px}
    .preview-panel{overflow:hidden}.preview-head,.setup-head,.question-head{padding:17px 18px;border-bottom:1px solid var(--line)}
    .preview-head,.question-head{display:flex;align-items:center;justify-content:space-between;gap:12px}
    .preview-head h2,.setup-head h2,.question-head h2{margin:0;color:var(--primary);font-size:15px}
    .preview-head span,.setup-head p{color:var(--muted);font-size:11px}.setup-head p{margin:5px 0 0}
    .video-stage{position:relative;min-height:430px;display:grid;place-items:center;overflow:hidden;background:#132238}
    .video-stage video{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;transform:scaleX(-1);background:#132238}
    .video-stage.is-off video{visibility:hidden}
    .video-stage:not(.is-off) .camera-empty{display:none}
    .camera-empty{position:relative;z-index:1;max-width:300px;text-align:center;color:#DCE6F4}
    .camera-empty-icon{width:58px;height:58px;margin:0 auto 14px;display:grid;place-items:center;border:1px solid rgba(255,255,255,.24);border-radius:50%;background:rgba(255,255,255,.08)}
    .camera-empty-icon svg{width:25px;height:25px;fill:none;stroke:currentColor;stroke-width:1.6}
    .camera-empty strong{display:block;color:#fff;font-size:15px}.camera-empty span{display:block;margin-top:5px;color:#AAB9CC;font-size:11px}
    .camera-label{position:absolute;left:14px;bottom:14px;z-index:2;padding:5px 9px;border:1px solid rgba(255,255,255,.16);border-radius:5px;color:#fff;background:rgba(8,20,37,.66);font-size:10px;backdrop-filter:blur(8px)}
    .device-bar{padding:13px 16px;display:flex;align-items:center;gap:9px;border-top:1px solid var(--line)}
    .icon-button{height:36px;padding:0 12px;display:inline-flex;align-items:center;justify-content:center;gap:7px;border:1px solid #CFDAE8;border-radius:6px;color:var(--primary);background:#fff;font-weight:700;font-size:11px}
    .icon-button:hover{border-color:var(--blue);color:var(--blue);background:#F7FAFF}.icon-button.active{border-color:#BAD2F6;color:var(--blue);background:var(--blue-soft)}
    .icon-button.off{border-color:#F0C9CC;color:var(--red);background:#FFF7F7}.icon-button svg{width:16px;height:16px;fill:none;stroke:currentColor;stroke-width:1.8}
    .device-help{margin-left:auto;color:var(--light);font-size:10px}
    .check-list{margin:0;padding:5px 18px 18px;list-style:none}.check-item{display:grid;grid-template-columns:34px minmax(0,1fr) auto;align-items:center;gap:11px;padding:15px 0;border-bottom:1px solid #EDF1F5}
    .check-icon{width:34px;height:34px;display:grid;place-items:center;border-radius:6px;color:var(--blue);background:var(--blue-soft)}.check-icon svg{width:17px;height:17px;fill:none;stroke:currentColor;stroke-width:1.7}
    .check-item strong{display:block;color:var(--primary);font-size:12px}.check-item small{display:block;margin-top:2px;color:var(--muted);font-size:10px}
    .check-state{padding:3px 7px;border-radius:4px;color:var(--muted);background:#F0F3F7;font-size:9px;font-weight:700}.check-state.ok{color:var(--green);background:var(--green-soft)}.check-state.warn{color:var(--amber);background:var(--amber-soft)}
    .notice{margin:2px 18px 16px;padding:10px 11px;border-left:3px solid var(--blue);color:#53657C;background:#F6F9FD;font-size:10px}.privacy{margin:0 18px 15px;color:var(--light);font-size:10px}
    .primary-button{width:calc(100% - 36px);height:44px;margin:0 18px 18px;border:0;border-radius:6px;color:#fff;background:var(--blue);font-weight:800;box-shadow:0 6px 14px rgba(43,127,255,.18)}
    .primary-button:hover{background:var(--blue-dark)}.primary-button:disabled{cursor:not-allowed;box-shadow:none;background:#AAB8C9}

    /* 正式答题视图 */
    .interview-view{display:none;margin-top:16px}.interview-view.active{display:grid;grid-template-columns:minmax(0,1.55fr) minmax(310px,.7fr);gap:16px}
    .question-panel{min-height:620px;display:flex;flex-direction:column}.progress-copy{color:var(--muted);font-size:11px}.progress-copy strong{color:var(--blue);font-size:14px}
    .timer{min-width:82px;height:30px;display:flex;align-items:center;justify-content:center;gap:6px;border:1px solid #D8E2EF;border-radius:5px;color:var(--primary);font-variant-numeric:tabular-nums;font-weight:800}.timer.warn{border-color:#F0CB95;color:var(--amber);background:var(--amber-soft)}.timer svg{width:14px;height:14px;fill:none;stroke:currentColor;stroke-width:1.8}
    .progress-line{height:3px;background:#E8EDF4}.progress-line span{display:block;width:12.5%;height:100%;background:var(--blue);transition:width .25s ease}
    .question-body{flex:1;padding:28px}.competency{display:inline-flex;padding:4px 8px;border-radius:4px;color:var(--blue);background:var(--blue-soft);font-size:10px;font-weight:700}
    .question-number{display:block;margin-top:18px;color:var(--light);font-size:11px}.question-title{margin:7px 0 22px;max-width:780px;color:var(--primary);font-size:24px;line-height:1.48;letter-spacing:0}
    .answer-label{display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;color:var(--primary);font-size:12px;font-weight:700}.answer-count{color:var(--light);font-size:10px;font-weight:400}
    .answer-input{width:100%;min-height:190px;padding:14px 15px;resize:vertical;border:1px solid #CFDAE8;border-radius:6px;color:var(--text);background:#FBFCFE;line-height:1.8;transition:border-color .15s,box-shadow .15s}
    .answer-input::placeholder{color:#A6B2C1}.answer-input:focus{border-color:var(--blue);box-shadow:0 0 0 3px rgba(43,127,255,.1);background:#fff;outline:0}
    .answer-tip{margin:9px 0 0;color:var(--muted);font-size:10px}.question-actions{padding:15px 18px;display:flex;align-items:center;gap:9px;border-top:1px solid var(--line);background:#FBFCFE}
    .secondary-button,.text-button{height:38px;padding:0 15px;border-radius:6px;font-weight:700;font-size:11px}.secondary-button{border:1px solid #CFDAE8;color:var(--primary);background:#fff}.secondary-button:hover{border-color:var(--blue);color:var(--blue)}.secondary-button:disabled{cursor:not-allowed;opacity:.45}.text-button{border:0;color:var(--muted);background:transparent}.text-button:hover{color:var(--blue);background:var(--blue-soft)}
    .next-button{height:38px;margin-left:auto;padding:0 18px;border:0;border-radius:6px;color:#fff;background:var(--blue);font-weight:800;font-size:11px}.next-button:hover{background:var(--blue-dark)}
    .side-stack{display:grid;gap:16px;align-content:start}.mini-video{overflow:hidden}.mini-video .video-stage{min-height:225px}.mini-video .camera-empty{transform:scale(.85)}.mini-video .device-bar{padding:10px 12px}.mini-video .device-help{display:none}
    .coach-panel{padding:17px 18px}.coach-head{display:flex;align-items:center;gap:9px;color:var(--primary);font-size:13px;font-weight:800}.coach-head span{width:28px;height:28px;display:grid;place-items:center;border-radius:6px;color:var(--blue);background:var(--blue-soft)}.coach-head svg{width:15px;height:15px;fill:none;stroke:currentColor;stroke-width:1.8}
    .coach-list{margin:13px 0 0;padding:0;list-style:none}.coach-list li{position:relative;padding:7px 0 7px 15px;color:var(--muted);font-size:10px}.coach-list li::before{content:"";position:absolute;left:0;top:13px;width:5px;height:5px;border-radius:50%;background:#82AEEF}
    .answer-overview{padding:17px 18px}.answer-overview h3{margin:0;color:var(--primary);font-size:13px}.answer-dots{display:grid;grid-template-columns:repeat(8,1fr);gap:5px;margin-top:12px}.answer-dot{aspect-ratio:1;display:grid;place-items:center;border:1px solid #D9E1EC;border-radius:5px;color:var(--muted);background:#fff;font-size:9px}.answer-dot.current{border-color:var(--blue);color:#fff;background:var(--blue)}.answer-dot.answered{border-color:#BFE2D3;color:var(--green);background:var(--green-soft)}.answer-dot.skipped{border-color:#E8D3B4;color:var(--amber);background:var(--amber-soft)}

    /* 完成页 */
    .result-view{display:none;margin-top:16px}.result-view.active{display:block}.result-panel{padding:34px;text-align:center}.result-mark{width:62px;height:62px;margin:auto;display:grid;place-items:center;border-radius:50%;color:var(--green);background:var(--green-soft)}.result-mark svg{width:28px;height:28px;fill:none;stroke:currentColor;stroke-width:2}
    .result-panel h2{margin:15px 0 5px;color:var(--primary);font-size:22px}.result-panel>p{margin:0;color:var(--muted);font-size:12px}.score-row{max-width:650px;margin:26px auto 0;display:grid;grid-template-columns:repeat(3,1fr);border:1px solid var(--line);border-radius:7px}.score-cell{padding:16px}.score-cell+.score-cell{border-left:1px solid var(--line)}.score-cell strong{display:block;color:var(--primary);font-size:24px;font-variant-numeric:tabular-nums}.score-cell small{color:var(--muted);font-size:10px}
    .feedback{max-width:650px;margin:16px auto 0;padding:16px 18px;text-align:left;border-left:3px solid var(--blue);background:#F7FAFE}.feedback strong{color:var(--primary);font-size:12px}.feedback p{margin:5px 0 0;color:var(--muted);font-size:11px}.result-actions{margin-top:22px;display:flex;justify-content:center;gap:10px}.result-actions a,.result-actions button{height:40px;padding:0 18px;display:inline-flex;align-items:center;border-radius:6px;text-decoration:none;font-weight:700;font-size:11px}.result-actions a{border:1px solid #CFDAE8;color:var(--primary);background:#fff}.result-actions button{border:0;color:#fff;background:var(--blue)}
    .toast{position:fixed;right:22px;bottom:22px;z-index:10;max-width:360px;padding:11px 14px;border:1px solid #D4DFEC;border-radius:6px;color:var(--primary);background:#fff;box-shadow:0 12px 28px rgba(26,60,110,.14);opacity:0;transform:translateY(10px);pointer-events:none;transition:.18s}.toast.show{opacity:1;transform:translateY(0)}

    @media(max-width:900px){.setup-layout,.interview-view.active{grid-template-columns:1fr}.video-stage{min-height:360px}.side-stack{grid-template-columns:1fr 1fr}.mini-video{grid-column:1/-1}.stage-track{display:none}}
    @media(max-width:640px){.topbar-inner,.page{width:calc(100% - 28px)}.brand-tag,.secure-state{display:none}.session-strip{grid-template-columns:1fr}.setup-layout{grid-template-columns:1fr}.video-stage{min-height:250px}.side-stack{grid-template-columns:1fr}.question-body{padding:21px 18px}.question-title{font-size:19px}.question-actions{flex-wrap:wrap}.next-button{margin-left:0}.score-row{grid-template-columns:1fr}.score-cell+.score-cell{border-left:0;border-top:1px solid var(--line)}}
    @media(prefers-reduced-motion:reduce){*,*::before,*::after{scroll-behavior:auto!important;transition:none!important}}
</style>
