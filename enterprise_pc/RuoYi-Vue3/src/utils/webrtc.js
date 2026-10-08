import { signalTicket, signalSend, signalStreamUrl } from '@/api/system/conference'

/**
 * 面试视频会议 WebRTC 点对点连接（SSE 信令 + P2P 媒体）
 *
 * 信令事件：offer / answer / ice 为 SDP 与 ICE 候选，后端另推送
 * self-joined / peer-joined / peer-left / bye。
 *
 * 协商策略（perfect-negotiation lite）：
 * - 初次 offer 固定由 HR 端在收到 peer-joined（且本地轨道就绪）后发起；
 *   候选人端只应答，结构性消除两端同时 offer 的冲突；
 * - 重协商（本地轨道晚于对端就绪）两端均可发起，候选人端为礼貌方，
 *   冲突时回滚本地 offer 再接纳对方 offer；
 * - ICE 候选在远端描述设置前到达则排队，setRemoteDescription 后冲刷。
 */
export function createConferenceRtc({ sessionId, onPeerStream, onPeerLeft }) {
  let ticket = ''
  let role = ''
  let es = null
  let pc = null
  let localStream = null
  let peerOnline = false
  let remoteSet = false
  let pendingCandidates = []
  let destroyed = false
  let reconnectTimer = null

  function start() {
    return signalTicket(sessionId)
      .then((res) => {
        const data = res && res.data
        // 纯前端演示模式（无后端）拿不到票据时静默跳过，页面保留本地演示
        if (destroyed || !data || !data.ticket) return
        ticket = data.ticket
        role = data.role
        // 对端已在本房间（本端后进场）时不会再收到 peer-joined，用票据携带的 peers 快照补判，
        // 否则 HR 作为 offerer 将永远不发起协商，双方画面都停在等待占位
        if (data.peers && data.peers.length) peerOnline = true
        openStream()
      })
      .catch(() => {})
  }

  function openStream() {
    es = new EventSource(signalStreamUrl(ticket))
    es.addEventListener('signal', (event) => {
      let msg
      try {
        msg = JSON.parse(event.data)
      } catch (e) {
        return
      }
      handleSignal(msg)
    })
    es.onerror = () => scheduleReconnect()
    // 通道建立后再发起协商：此时本端 emitter 已在后端注册，
    // 能确保收到对端的 answer / ICE，避免仅凭 peers 快照抢跑而漏收回包
    es.onopen = () => {
      if (peerOnline && role === 'HR' && localStream && !pc) createPeerAndOffer()
    }
  }

  function scheduleReconnect() {
    if (destroyed) return
    closeStream()
    resetPeer()
    clearTimeout(reconnectTimer)
    reconnectTimer = setTimeout(start, 2000)
  }

  function closeStream() {
    if (es) {
      es.close()
      es = null
    }
  }

  function send(type, payload) {
    if (!ticket) return
    signalSend(ticket, { type: type, payload: payload || {} }).catch(() => {})
  }

  function ensurePeer() {
    if (pc) return pc
    pc = new RTCPeerConnection({ iceServers: [] })
    if (localStream) {
      localStream.getTracks().forEach((track) => pc.addTrack(track, localStream))
    }
    pc.onicecandidate = (event) => {
      send('ice', { candidate: event.candidate || null })
    }
    pc.ontrack = (event) => {
      const stream = event.streams && event.streams[0] ? event.streams[0] : new MediaStream([event.track])
      if (onPeerStream) onPeerStream(stream)
    }
    pc.onconnectionstatechange = () => {
      if (!pc || destroyed || pc.connectionState !== 'failed') return
      if (role === 'HR' && peerOnline) {
        // offerer 端自动重建连接（新 PC 重新收集 ICE）
        const old = pc
        pc = null
        remoteSet = false
        old.close()
        if (onPeerLeft) onPeerLeft()
        createPeerAndOffer()
      } else {
        resetPeer()
      }
    }
    return pc
  }

  /**
   * 页面本地轨道就绪后接入（媒体采集与信令连接解耦，谁后到谁触发）
   * 同类轨道已存在时 replaceTrack（关闭再开启摄像头不产生悬挂的 ended sender），
   * 仅在真正新增轨道时重协商。
   */
  function attachLocalTracks(videoTrack, audioTrack) {
    const tracks = [videoTrack, audioTrack].filter(Boolean)
    if (!tracks.length) return
    localStream = new MediaStream(tracks)
    if (pc) {
      let added = false
      tracks.forEach((t) => {
        const senders = pc.getSenders()
        const active = senders.find((s) => s.track && s.track.kind === t.kind && s.track.readyState !== 'ended')
        if (active) {
          if (active.track !== t) active.replaceTrack(t)
          return
        }
        const ended = senders.find((s) => s.track && s.track.kind === t.kind)
        if (ended) ended.replaceTrack(t)
        else {
          pc.addTrack(t, localStream)
          added = true
        }
      })
      if (added) renegotiate()
    } else if (peerOnline && role === 'HR') {
      createPeerAndOffer()
    }
  }

  /**
   * 移除本地轨道（媒体重试时先清掉已 stop 的旧轨道，避免 sender 悬挂）
   */
  function detachLocalTracks() {
    localStream = null
    if (!pc) return
    pc.getSenders().forEach((sender) => {
      try {
        pc.removeTrack(sender)
      } catch (e) {
        // 连接状态异常时忽略
      }
    })
    renegotiate()
  }

  async function createPeerAndOffer() {
    const p = ensurePeer()
    try {
      const offer = await p.createOffer()
      await p.setLocalDescription(offer)
      send('offer', { sdp: p.localDescription.sdp })
    } catch (e) {
      // 创建 offer 失败等待对端重连触发
    }
  }

  async function renegotiate() {
    if (!pc || destroyed) return
    try {
      const offer = await pc.createOffer()
      await pc.setLocalDescription(offer)
      send('offer', { sdp: pc.localDescription.sdp })
    } catch (e) {
      // 忽略重协商异常，连接失败时由 onconnectionstatechange 兜底
    }
  }

  function handleSignal(msg) {
    switch (msg.type) {
      case 'peer-joined':
        peerOnline = true
        if (role === 'HR' && localStream) createPeerAndOffer()
        break
      case 'peer-left':
      case 'bye':
        resetPeer()
        break
      case 'offer':
        handleOffer(msg.payload || {})
        break
      case 'answer':
        handleAnswer(msg.payload || {})
        break
      case 'ice':
        handleIce(msg.payload || {})
        break
      default:
        break
    }
  }

  async function handleOffer(payload) {
    if (!payload.sdp) return
    const p = ensurePeer()
    const collision = p.signalingState !== 'stable'
    // HR 为不礼貌方：重协商冲突时忽略对方 offer；候选人为礼貌方：回滚后接纳
    if (role === 'HR' && collision) return
    try {
      if (collision) await p.setLocalDescription({ type: 'rollback' })
      await p.setRemoteDescription({ type: 'offer', sdp: payload.sdp })
      remoteSet = true
      flushCandidates()
      const answer = await p.createAnswer()
      await p.setLocalDescription(answer)
      send('answer', { sdp: p.localDescription.sdp })
    } catch (e) {
      // 信令乱序导致的失败由下一次重协商恢复
    }
  }

  async function handleAnswer(payload) {
    if (!pc || !payload.sdp) return
    try {
      await pc.setRemoteDescription({ type: 'answer', sdp: payload.sdp })
      remoteSet = true
      flushCandidates()
    } catch (e) {
      // 同上
    }
  }

  function handleIce(payload) {
    const candidate = payload && payload.candidate
    if (!candidate) return
    if (!pc || !remoteSet) {
      pendingCandidates.push(candidate)
      return
    }
    pc.addIceCandidate(candidate).catch(() => {})
  }

  function flushCandidates() {
    const list = pendingCandidates.splice(0)
    list.forEach((c) => {
      if (pc) pc.addIceCandidate(c).catch(() => {})
    })
  }

  function resetPeer() {
    peerOnline = false
    remoteSet = false
    pendingCandidates = []
    if (pc) {
      pc.close()
      pc = null
    }
    if (onPeerLeft) onPeerLeft()
  }

  function destroy() {
    destroyed = true
    clearTimeout(reconnectTimer)
    send('bye')
    closeStream()
    resetPeer()
  }

  return { start, attachLocalTracks, detachLocalTracks, destroy }
}
