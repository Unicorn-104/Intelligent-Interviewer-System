import { signalTicket, signalSend, signalStreamUrl } from '@/api/system/conference'

// ICE 服务器：至少提供 STUN，让跨网络 P2P 能拿到公网候选地址；
// 生产环境若存在对称 NAT / 严格防火墙，需在此基础上补配自建 TURN（coturn）中继。
const ICE_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' }
]

/**
 * 面试视频会议 WebRTC 多方网状连接（SSE 信令 + P2P 媒体）
 *
 * 房间内每两端各建一路 RTCPeerConnection（mesh），本端与每位在线参与者
 * 独立收发媒体，互不影响（多面试官场景下候选人可与每位面试官各建一路）。
 * 信令事件：offer / answer / ice 采用「定向转发」（按 to 指定目标端），
 * 后端另广播 self-joined / peer-joined / peer-left / bye。
 *
 * 协商策略（perfect-negotiation）：
 * - 以 userId 大小决定发起方：id 较小的一方为「不礼让方」主动 offer，
 *   较大一方为「礼让方」，冲突时回滚本地 offer 再接纳对方 offer；
 * - ICE 候选在远端描述设置前到达则按连接排队，setRemoteDescription 后冲刷。
 *
 * 回调：onPeerStream(userId, stream) / onPeerLeft(userId) / onPeerState(userId, state)
 *       onControl(type, payload) 接收业务控制消息（如录制状态同步）
 */
export function createConferenceRtc({ sessionId, onPeerStream, onPeerLeft, onPeerState, onControl }) {
  let ticket = ''
  let selfId = null
  let es = null
  let localStream = null
  let streamOpen = false
  let destroyed = false
  let reconnectTimer = null
  // userId -> { userId, role, pc, remoteSet, pending, impolite }
  const peers = new Map()

  function start() {
    return signalTicket(sessionId)
      .then((res) => {
        const data = res && res.data
        // 纯前端演示模式（无后端）拿不到票据时跳过；生产环境出现该情况说明票据接口异常，需暴露
        if (destroyed) return
        if (!data || !data.ticket) {
          console.error('[conference] 信令票据获取失败：接口未返回 ticket', res)
          return
        }
        ticket = data.ticket
        selfId = data.userId
        openStream()
        // 房间内已在线参与者：本端后进场时不会再收到其 peer-joined，用票据快照补齐
        ;(data.peers || []).forEach((p) => addPeer(p.userId, p.role))
      })
      .catch((error) => {
        // 票据接口 401 / 网络失败 / 代理未转发都会走到这里，静默会导致画面永远停在等待占位
        console.error('[conference] 信令票据请求失败，无法建立 SSE 信令通道', error)
      })
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
    es.onerror = () => {
      // CONNECTING=0 OPEN=1 CLOSED=2；服务器部署下若 Nginx 未转发 /prod-api 或缓冲 SSE，
      // 通道会反复报错重连，这里打印状态便于从 F12 直接定位
      console.error('[conference] SSE 信令通道异常，readyState =', es && es.readyState, 'url =', signalStreamUrl(ticket))
      scheduleReconnect()
    }
    // 通道建立后再发起协商：此时本端 emitter 已在后端注册，
    // 能确保收到对端的 answer / ICE，避免仅凭快照抢跑而漏收回包
    es.onopen = () => {
      streamOpen = true
      peers.forEach(maybeInitiate)
    }
  }

  function scheduleReconnect() {
    if (destroyed) return
    // 仅重连信令通道：WebRTC 媒体是 P2P，不依赖 SSE。信令瞬断时若销毁所有
    // RTCPeerConnection，会把正在播放的画面一并打断，且重连后仅不礼让方重发 offer、
    // 与对端 EventSource 就绪时机错开就会永久卡在「等待画面」。这里保留既有连接，
    // 人员真正离开由后端 peer-left / bye 驱动，连接异常由 onconnectionstatechange 兜底。
    closeStream()
    clearTimeout(reconnectTimer)
    reconnectTimer = setTimeout(start, 2000)
  }

  function closeStream() {
    streamOpen = false
    if (es) {
      es.close()
      es = null
    }
  }

  function send(type, payload, to) {
    if (!ticket) return
    signalSend(ticket, { type: type, payload: payload || {}, to: to == null ? undefined : to }).catch(() => {})
  }

  // 发送业务控制消息（如录制状态）；to 为空时广播给房间内所有参与者
  function sendControl(type, payload, to) {
    send(type, payload, to)
  }

  // id 较小的一方主动发起，双方判定一致，避免同一对连接同时 offer 造成冲突
  function isImpolite(peerId) {
    return selfId != null && peerId != null && Number(selfId) < Number(peerId)
  }

  function addPeer(userId, role) {
    if (userId == null || (selfId != null && String(userId) === String(selfId))) return
    const key = String(userId)
    if (peers.has(key)) {
      if (role && !peers.get(key).role) peers.get(key).role = role
      return
    }
    const state = { userId: userId, role: role || null, pc: null, remoteSet: false, pending: [], impolite: isImpolite(userId) }
    peers.set(key, state)
    if (onPeerState) onPeerState(userId, 'joining')
    maybeInitiate(state)
  }

  function ensureState(userId, role) {
    const key = String(userId)
    if (!peers.has(key)) {
      peers.set(key, { userId: userId, role: role || null, pc: null, remoteSet: false, pending: [], impolite: isImpolite(userId) })
    }
    return peers.get(key)
  }

  function removePeer(userId) {
    const key = String(userId)
    const state = peers.get(key)
    if (!state) return
    peers.delete(key)
    closePeer(state)
    if (onPeerLeft) onPeerLeft(userId)
  }

  function maybeInitiate(state) {
    if (destroyed || !streamOpen || !state.impolite || state.pc) return
    createOfferFor(state)
  }

  function ensurePc(state) {
    if (state.pc) return state.pc
    const pc = new RTCPeerConnection({ iceServers: ICE_SERVERS })
    state.pc = pc
    state.remoteSet = false
    if (localStream) {
      localStream.getTracks().forEach((track) => pc.addTrack(track, localStream))
    }
    pc.onicecandidate = (event) => send('ice', { candidate: event.candidate || null }, state.userId)
    pc.ontrack = (event) => {
      const stream = event.streams && event.streams[0] ? event.streams[0] : new MediaStream([event.track])
      if (onPeerStream) onPeerStream(state.userId, stream)
    }
    pc.onconnectionstatechange = () => {
      if (destroyed || state.pc !== pc) return
      if (pc.connectionState === 'connected') {
        if (onPeerState) onPeerState(state.userId, 'connected')
      } else if (pc.connectionState === 'failed') {
        // 发起方重连；礼让方等待对端重新 offer
        closePeer(state)
        if (state.impolite) createOfferFor(state)
        else if (onPeerLeft) onPeerLeft(state.userId)
      }
    }
    return pc
  }

  /**
   * 页面本地轨道就绪后接入（媒体采集与信令连接解耦，谁后到谁触发）。
   * 同类轨道已存在时 replaceTrack（关闭再开启摄像头不产生悬挂的 ended sender），
   * 仅在真正新增轨道时重协商。
   * 未「加入本次面试」的面试官不接入本地轨道，因而只收不发。
   */
  function attachLocalTracks(videoTrack, audioTrack) {
    const tracks = [videoTrack, audioTrack].filter(Boolean)
    if (!tracks.length) return
    localStream = new MediaStream(tracks)
    peers.forEach((state) => {
      if (!state.pc) {
        maybeInitiate(state)
        return
      }
      let added = false
      tracks.forEach((t) => {
        const senders = state.pc.getSenders()
        const active = senders.find((s) => s.track && s.track.kind === t.kind && s.track.readyState !== 'ended')
        if (active) {
          if (active.track !== t) active.replaceTrack(t)
          return
        }
        const ended = senders.find((s) => s.track && s.track.kind === t.kind)
        if (ended) ended.replaceTrack(t)
        else {
          state.pc.addTrack(t, localStream)
          added = true
        }
      })
      if (added) renegotiate(state)
    })
  }

  /**
   * 移除本地轨道（媒体重试时先清掉已 stop 的旧轨道，避免 sender 悬挂）
   */
  function detachLocalTracks() {
    localStream = null
    peers.forEach((state) => {
      if (!state.pc) return
      state.pc.getSenders().forEach((sender) => {
        try {
          state.pc.removeTrack(sender)
        } catch (e) {
          // 连接状态异常时忽略
        }
      })
      renegotiate(state)
    })
  }

  async function createOfferFor(state) {
    if (destroyed) return
    const pc = ensurePc(state)
    try {
      const offer = await pc.createOffer()
      await pc.setLocalDescription(offer)
      send('offer', { sdp: pc.localDescription.sdp }, state.userId)
    } catch (e) {
      // 创建 offer 失败等待对端重连触发
    }
  }

  async function renegotiate(state) {
    if (!state.pc || destroyed) return
    try {
      const offer = await state.pc.createOffer()
      await state.pc.setLocalDescription(offer)
      send('offer', { sdp: state.pc.localDescription.sdp }, state.userId)
    } catch (e) {
      // 忽略重协商异常，连接失败时由 onconnectionstatechange 兜底
    }
  }

  function handleSignal(msg) {
    const from = msg.from
    switch (msg.type) {
      case 'self-joined':
        if (selfId == null) selfId = from
        break
      case 'peer-joined':
        addPeer(from, msg.fromRole)
        break
      case 'peer-left':
      case 'bye':
        removePeer(from)
        break
      case 'offer':
        handleOffer(ensureState(from, msg.fromRole), msg.payload || {})
        break
      case 'answer': {
        const state = peers.get(String(from))
        if (state) handleAnswer(state, msg.payload || {})
        break
      }
      case 'ice': {
        const state = peers.get(String(from))
        if (state) handleIce(state, msg.payload || {})
        break
      }
      case 'recording':
        // 录制状态由正在录制的面试官广播；转交业务层更新 UI
        if (onControl) onControl('recording', msg.payload || {})
        break
      default:
        break
    }
  }

  async function handleOffer(state, payload) {
    if (!payload.sdp) return
    const pc = ensurePc(state)
    const collision = pc.signalingState !== 'stable'
    // 发起方（不礼让）冲突时忽略对方 offer；礼让方回滚后接纳
    if (state.impolite && collision) return
    try {
      if (collision) await pc.setLocalDescription({ type: 'rollback' })
      await pc.setRemoteDescription({ type: 'offer', sdp: payload.sdp })
      state.remoteSet = true
      flushCandidates(state)
      const answer = await pc.createAnswer()
      await pc.setLocalDescription(answer)
      send('answer', { sdp: pc.localDescription.sdp }, state.userId)
    } catch (e) {
      // 信令乱序导致的失败由下一次重协商恢复
    }
  }

  async function handleAnswer(state, payload) {
    if (!state.pc || !payload.sdp) return
    try {
      await state.pc.setRemoteDescription({ type: 'answer', sdp: payload.sdp })
      state.remoteSet = true
      flushCandidates(state)
    } catch (e) {
      // 同上
    }
  }

  function handleIce(state, payload) {
    const candidate = payload && payload.candidate
    if (!candidate) return
    if (!state.pc || !state.remoteSet) {
      state.pending.push(candidate)
      return
    }
    state.pc.addIceCandidate(candidate).catch(() => {})
  }

  function flushCandidates(state) {
    const list = state.pending.splice(0)
    list.forEach((c) => {
      if (state.pc) state.pc.addIceCandidate(c).catch(() => {})
    })
  }

  function closePeer(state) {
    state.remoteSet = false
    state.pending = []
    if (state.pc) {
      state.pc.close()
      state.pc = null
    }
  }

  function closeAllPeers() {
    peers.forEach(closePeer)
  }

  function destroy() {
    destroyed = true
    clearTimeout(reconnectTimer)
    send('bye')
    closeStream()
    closeAllPeers()
    peers.clear()
  }

  return { start, attachLocalTracks, detachLocalTracks, sendControl, destroy }
}