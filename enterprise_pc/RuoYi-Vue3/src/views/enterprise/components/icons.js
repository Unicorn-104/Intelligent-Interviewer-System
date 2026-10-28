import { defineComponent, h } from 'vue'

// 图标形状注册表：lucide 风格（viewBox 24、stroke 描边），按业务语义命名
// 未注册的名称回退为圆圈加号占位
const shapes = {
  Bot: [
    ['path', { d: 'M12 8V4H8' }],
    ['rect', { width: 16, height: 12, x: 4, y: 8, rx: 2 }],
    ['path', { d: 'M2 14h2' }],
    ['path', { d: 'M20 14h2' }],
    ['path', { d: 'M15 13v2' }],
    ['path', { d: 'M9 13v2' }]
  ],
  BriefcaseBusiness: [
    ['path', { d: 'M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16' }],
    ['rect', { width: 20, height: 14, x: 2, y: 6, rx: 2 }]
  ],
  FileText: [
    ['path', { d: 'M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z' }],
    ['path', { d: 'M14 2v4a2 2 0 0 0 2 2h4' }],
    ['path', { d: 'M16 13H8' }],
    ['path', { d: 'M16 17H8' }],
    ['path', { d: 'M10 9H8' }]
  ],
  Clock3: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['polyline', { points: '12 6 12 12 16 14' }]
  ],
  CircleCheckBig: [
    ['path', { d: 'M21.801 10A10 10 0 1 1 17 3.335' }],
    ['path', { d: 'm9 11 3 3L22 4' }]
  ],
  ArrowUpRight: [
    ['path', { d: 'M7 7h10v10' }],
    ['path', { d: 'M7 17 17 7' }]
  ],
  CalendarDays: [
    ['path', { d: 'M8 2v4' }],
    ['path', { d: 'M16 2v4' }],
    ['rect', { width: 18, height: 18, x: 3, y: 4, rx: 2 }],
    ['path', { d: 'M3 10h18' }],
    ['path', { d: 'M8 14h.01' }],
    ['path', { d: 'M12 14h.01' }],
    ['path', { d: 'M16 14h.01' }],
    ['path', { d: 'M8 18h.01' }],
    ['path', { d: 'M12 18h.01' }],
    ['path', { d: 'M16 18h.01' }]
  ],
  UserRoundCheck: [
    ['circle', { cx: 16, cy: 3, r: 1 }],
    ['path', { d: 'm13 6 2 2 4-4' }],
    ['path', { d: 'M2 21v-2a4 4 0 0 1 4-4h10' }],
    ['path', { d: 'M16 3.13a4 4 0 0 1 0 7.75' }]
  ],
  Timer: [
    ['line', { x1: 10, x2: 14, y1: 2, y2: 2 }],
    ['line', { x1: 12, x2: 15, y1: 14, y2: 11 }],
    ['circle', { cx: 12, cy: 14, r: 8 }]
  ],
  Sparkles: [
    ['path', { d: 'M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z' }],
    ['path', { d: 'M20 3v4' }],
    ['path', { d: 'M22 5h-4' }]
  ],
  Plus: [
    ['path', { d: 'M5 12h14' }],
    ['path', { d: 'M12 5v14' }]
  ],
  Search: [
    ['circle', { cx: 11, cy: 11, r: 8 }],
    ['path', { d: 'm21 21-4.3-4.3' }]
  ],
  Bell: [
    ['path', { d: 'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9' }],
    ['path', { d: 'M10.3 21a1.94 1.94 0 0 0 3.4 0' }]
  ],
  Video: [
    ['path', { d: 'm22 8-6 4 6 4V8Z' }],
    ['rect', { width: 14, height: 12, x: 2, y: 6, rx: 2 }]
  ],
  Send: [
    ['path', { d: 'm22 2-7 20-4-9-9-4Z' }],
    ['path', { d: 'M22 2 11 13' }]
  ],
  Smile: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['path', { d: 'M8 14s1.5 2 4 2 4-2 4-2' }],
    ['line', { x1: 9, x2: 9.01, y1: 9, y2: 9 }],
    ['line', { x1: 15, x2: 15.01, y1: 9, y2: 9 }]
  ],
  Paperclip: [
    ['path', { d: 'm21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48' }]
  ],
  Users: [
    ['path', { d: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2' }],
    ['circle', { cx: 9, cy: 7, r: 4 }],
    ['path', { d: 'M22 21v-2a4 4 0 0 0-3-3.87' }],
    ['path', { d: 'M16 3.13a4 4 0 0 1 0 7.75' }]
  ],
  AlertTriangle: [
    ['path', { d: 'm21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z' }],
    ['path', { d: 'M12 9v4' }],
    ['path', { d: 'M12 17h.01' }]
  ],
  Archive: [
    ['rect', { width: 20, height: 5, x: 2, y: 3, rx: 1 }],
    ['path', { d: 'M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8' }],
    ['path', { d: 'M10 12h4' }]
  ],
  ArrowLeft: [
    ['path', { d: 'm12 19-7-7 7-7' }],
    ['path', { d: 'M19 12H5' }]
  ],
  AudioWaveform: [
    ['path', { d: 'M2 13a2 2 0 0 0 2-2V7a2 2 0 0 1 4 0v13a2 2 0 0 0 4 0V4a2 2 0 0 1 4 0v13a2 2 0 0 0 4 0v-4a2 2 0 0 1 2-2' }]
  ],
  BellRing: [
    ['path', { d: 'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9' }],
    ['path', { d: 'M10.3 21a1.94 1.94 0 0 0 3.4 0' }],
    ['path', { d: 'M4 2C2.8 3.7 2 5.7 2 8' }],
    ['path', { d: 'M22 8c0-2.3-.8-4.3-2-6' }]
  ],
  Bookmark: [
    ['path', { d: 'm19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2Z' }]
  ],
  Building2: [
    ['path', { d: 'M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z' }],
    ['path', { d: 'M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2' }],
    ['path', { d: 'M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2' }],
    ['path', { d: 'M10 6h4' }],
    ['path', { d: 'M10 10h4' }],
    ['path', { d: 'M10 14h4' }],
    ['path', { d: 'M10 18h4' }]
  ],
  CalendarClock: [
    ['path', { d: 'M8 2v4' }],
    ['path', { d: 'M16 2v4' }],
    ['path', { d: 'M21 13V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h6' }],
    ['path', { d: 'M3 10h18' }],
    ['circle', { cx: 17, cy: 17, r: 4 }],
    ['path', { d: 'M17 15.5V17l1 1' }]
  ],
  CalendarPlus: [
    ['path', { d: 'M8 2v4' }],
    ['path', { d: 'M16 2v4' }],
    ['rect', { width: 18, height: 18, x: 3, y: 4, rx: 2 }],
    ['path', { d: 'M3 10h18' }],
    ['path', { d: 'M12 14v4' }],
    ['path', { d: 'M10 16h4' }]
  ],
  CalendarSync: [
    ['path', { d: 'M8 2v4' }],
    ['path', { d: 'M16 2v4' }],
    ['rect', { width: 18, height: 18, x: 3, y: 4, rx: 2 }],
    ['path', { d: 'M3 10h18' }],
    ['path', { d: 'M14 14h3l-1-1' }],
    ['path', { d: 'M17 14v3a2 2 0 0 1-4 0' }],
    ['path', { d: 'M13 17h-3l1 1' }],
    ['path', { d: 'M10 17v-3a2 2 0 0 1 4 0' }]
  ],
  Camera: [
    ['path', { d: 'M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z' }],
    ['circle', { cx: 12, cy: 13, r: 3 }]
  ],
  Check: [
    ['path', { d: 'M20 6 9 17l-5-5' }]
  ],
  CheckCheck: [
    ['path', { d: 'M18 6 7 17l-5-5' }],
    ['path', { d: 'm22 10-7.5 7.5L13 16' }]
  ],
  CheckCircle2: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['path', { d: 'm9 12 2 2 4-4' }]
  ],
  ChevronDown: [['path', { d: 'm6 9 6 6 6-6' }]],
  ChevronLeft: [['path', { d: 'm15 18-6-6 6-6' }]],
  ChevronRight: [['path', { d: 'm9 18 6-6-6-6' }]],
  ChevronUp: [['path', { d: 'm18 15-6-6-6 6' }]],
  CircleCheck: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['path', { d: 'm9 12 2 2 4-4' }]
  ],
  CirclePause: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['path', { d: 'M10 15V9' }],
    ['path', { d: 'M14 15V9' }]
  ],
  CircleX: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['path', { d: 'm15 9-6 6' }],
    ['path', { d: 'm9 9 6 6' }]
  ],
  CloudUpload: [
    ['path', { d: 'M4 14.9A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 .5 8.97' }],
    ['path', { d: 'M12 12v9' }],
    ['path', { d: 'm16 16-4-4-4 4' }]
  ],
  Copy: [
    ['rect', { width: 14, height: 14, x: 8, y: 8, rx: 2 }],
    ['path', { d: 'M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2' }]
  ],
  Database: [
    ['ellipse', { cx: 12, cy: 5, rx: 9, ry: 3 }],
    ['path', { d: 'M3 5V19A9 3 0 0 0 21 19V5' }],
    ['path', { d: 'M3 12A9 3 0 0 0 21 12' }]
  ],
  Download: [
    ['path', { d: 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4' }],
    ['polyline', { points: '7 10 12 15 17 10' }],
    ['line', { x1: 12, x2: 12, y1: 15, y2: 3 }]
  ],
  FileCheck2: [
    ['path', { d: 'M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z' }],
    ['path', { d: 'M14 2v4a2 2 0 0 0 2 2h4' }],
    ['path', { d: 'm9 15 2 2 4-4' }]
  ],
  GitBranch: [
    ['line', { x1: 6, x2: 6, y1: 3, y2: 15 }],
    ['circle', { cx: 18, cy: 6, r: 3 }],
    ['circle', { cx: 6, cy: 18, r: 3 }],
    ['path', { d: 'M18 9a9 9 0 0 1-9 9' }]
  ],
  Globe2: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['path', { d: 'M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20' }],
    ['path', { d: 'M2 12h20' }]
  ],
  GripVertical: [
    ['circle', { cx: 9, cy: 5, r: 1 }],
    ['circle', { cx: 9, cy: 12, r: 1 }],
    ['circle', { cx: 9, cy: 19, r: 1 }],
    ['circle', { cx: 15, cy: 5, r: 1 }],
    ['circle', { cx: 15, cy: 12, r: 1 }],
    ['circle', { cx: 15, cy: 19, r: 1 }]
  ],
  History: [
    ['path', { d: 'M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8' }],
    ['path', { d: 'M3 3v5h5' }],
    ['path', { d: 'M12 7v5l4 2' }]
  ],
  KeyRound: [
    ['circle', { cx: 7.5, cy: 15.5, r: 5.5 }],
    ['path', { d: 'm21 2-9.6 9.6' }],
    ['path', { d: 'm15.5 7.5 3 3L22 7l-3-3' }]
  ],
  LayoutDashboard: [
    ['rect', { width: 7, height: 9, x: 3, y: 3, rx: 1 }],
    ['rect', { width: 7, height: 5, x: 14, y: 3, rx: 1 }],
    ['rect', { width: 7, height: 9, x: 14, y: 12, rx: 1 }],
    ['rect', { width: 7, height: 5, x: 3, y: 16, rx: 1 }]
  ],
  Lightbulb: [
    ['path', { d: 'M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5' }],
    ['path', { d: 'M9 18h6' }],
    ['path', { d: 'M10 22h4' }]
  ],
  Link2: [
    ['path', { d: 'M9 17H7A5 5 0 0 1 7 7h2' }],
    ['path', { d: 'M15 7h2a5 5 0 1 1 0 10h-2' }],
    ['line', { x1: 8, x2: 16, y1: 12, y2: 12 }]
  ],
  Mail: [
    ['rect', { width: 20, height: 16, x: 2, y: 4, rx: 2 }],
    ['path', { d: 'm22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7' }]
  ],
  MailPlus: [
    ['path', { d: 'M22 13V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h8' }],
    ['path', { d: 'm22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7' }],
    ['path', { d: 'M16 19h6' }],
    ['path', { d: 'M19 16v6' }]
  ],
  MapPin: [
    ['path', { d: 'M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0' }],
    ['circle', { cx: 12, cy: 10, r: 3 }]
  ],
  Megaphone: [
    ['path', { d: 'm3 11 18-5v12L3 14v-3z' }],
    ['path', { d: 'M11.6 16.8a3 3 0 1 1-5.8-1.6' }]
  ],
  MessageCircle: [
    ['path', { d: 'M7.9 20A9 9 0 1 0 4 16.1L2 22Z' }]
  ],
  MessageSquare: [
    ['path', { d: 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z' }]
  ],
  MessageSquareText: [
    ['path', { d: 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z' }],
    ['path', { d: 'M16 8H8' }],
    ['path', { d: 'M13 12H8' }]
  ],
  Mic: [
    ['path', { d: 'M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z' }],
    ['path', { d: 'M19 10v2a7 7 0 0 1-14 0v-2' }],
    ['line', { x1: 12, x2: 12, y1: 19, y2: 22 }],
    ['line', { x1: 8, x2: 16, y1: 22, y2: 22 }]
  ],
  MicOff: [
    ['path', { d: 'm2 2 20 20' }],
    ['path', { d: 'M18.89 13.23A7.12 7.12 0 0 0 19 12v-2' }],
    ['path', { d: 'M5 10v2a7 7 0 0 0 12 5' }],
    ['path', { d: 'M15 9.34V5a3 3 0 0 0-5.68-1.33' }],
    ['path', { d: 'M9 9v3a3 3 0 0 0 5.12 2.12' }],
    ['line', { x1: 12, x2: 12, y1: 19, y2: 22 }],
    ['line', { x1: 8, x2: 16, y1: 22, y2: 22 }]
  ],
  MonitorUp: [
    ['rect', { width: 20, height: 14, x: 2, y: 3, rx: 2 }],
    ['path', { d: 'M8 21h8' }],
    ['path', { d: 'M12 17v4' }],
    ['path', { d: 'm9 10 3-3 3 3' }],
    ['path', { d: 'M12 7v6' }]
  ],
  PauseCircle: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['path', { d: 'M10 15V9' }],
    ['path', { d: 'M14 15V9' }]
  ],
  Pencil: [
    ['path', { d: 'M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z' }],
    ['path', { d: 'm15 5 4 4' }]
  ],
  PhoneOff: [
    ['path', { d: 'm2 2 20 20' }],
    ['path', { d: 'M16 14v-1c0-.55.45-1 1-1h3c.55 0 1 .45 1 1v1.5c0 1.38-1.12 2.5-2.5 2.5C10.61 18 6 13.39 6 6.5 6 5.12 7.12 4 8.5 4H10c.55 0 1 .45 1 1v3c0 .55-.45 1-1 1H9' }]
  ],
  RotateCcw: [
    ['path', { d: 'M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8' }],
    ['path', { d: 'M3 3v5h5' }]
  ],
  RotateCw: [
    ['path', { d: 'M21 12a9 9 0 1 1-9-9 9.75 9.75 0 0 1 6.74 2.74L21 8' }],
    ['path', { d: 'M21 3v5h-5' }]
  ],
  Save: [
    ['path', { d: 'M15.2 3a2 2 0 0 1 1.4.6l3.8 3.8a2 2 0 0 1 .6 1.4V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z' }],
    ['path', { d: 'M17 21v-7a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v7' }],
    ['path', { d: 'M7 3v4a1 1 0 0 0 1 1h7' }]
  ],
  Settings: [
    ['circle', { cx: 12, cy: 12, r: 3 }],
    ['path', { d: 'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z' }]
  ],
  Settings2: [
    ['path', { d: 'M20 7h-9' }],
    ['path', { d: 'M14 17H5' }],
    ['circle', { cx: 17, cy: 17, r: 3 }],
    ['circle', { cx: 7, cy: 7, r: 3 }]
  ],
  ShieldCheck: [
    ['path', { d: 'M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z' }],
    ['path', { d: 'm9 12 2 2 4-4' }]
  ],
  SlidersHorizontal: [
    ['line', { x1: 21, x2: 14, y1: 4, y2: 4 }],
    ['line', { x1: 10, x2: 3, y1: 4, y2: 4 }],
    ['line', { x1: 21, x2: 12, y1: 12, y2: 12 }],
    ['line', { x1: 8, x2: 3, y1: 12, y2: 12 }],
    ['line', { x1: 21, x2: 16, y1: 20, y2: 20 }],
    ['line', { x1: 12, x2: 3, y1: 20, y2: 20 }],
    ['line', { x1: 14, x2: 14, y1: 2, y2: 6 }],
    ['line', { x1: 8, x2: 8, y1: 10, y2: 14 }],
    ['line', { x1: 16, x2: 16, y1: 18, y2: 22 }]
  ],
  Smartphone: [
    ['rect', { width: 14, height: 20, x: 5, y: 2, rx: 2 }],
    ['path', { d: 'M12 18h.01' }]
  ],
  Tags: [
    ['path', { d: 'M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z' }],
    ['circle', { cx: 7.5, cy: 7.5, r: .5, fill: 'currentColor' }]
  ],
  Target: [
    ['circle', { cx: 12, cy: 12, r: 10 }],
    ['circle', { cx: 12, cy: 12, r: 6 }],
    ['circle', { cx: 12, cy: 12, r: 2 }]
  ],
  Trash2: [
    ['path', { d: 'M3 6h18' }],
    ['path', { d: 'M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6' }],
    ['path', { d: 'M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2' }],
    ['line', { x1: 10, x2: 10, y1: 11, y2: 17 }],
    ['line', { x1: 14, x2: 14, y1: 11, y2: 17 }]
  ],
  Upload: [
    ['path', { d: 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4' }],
    ['polyline', { points: '17 8 12 3 7 8' }],
    ['line', { x1: 12, x2: 12, y1: 3, y2: 15 }]
  ],
  UserRound: [
    ['circle', { cx: 12, cy: 8, r: 5 }],
    ['path', { d: 'M20 21a8 8 0 0 0-16 0' }]
  ],
  UserX: [
    ['path', { d: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2' }],
    ['circle', { cx: 9, cy: 7, r: 4 }],
    ['path', { d: 'm17 8 5 5' }],
    ['path', { d: 'm22 8-5 5' }]
  ],
  UsersRound: [
    ['path', { d: 'M18 21a8 8 0 0 0-16 0' }],
    ['circle', { cx: 10, cy: 8, r: 5 }],
    ['path', { d: 'M22 20c0-3.37-2-6.5-4-8a5 5 0 0 0-.45-8.3' }]
  ],
  Volume2: [
    ['path', { d: 'M11 4.7a.7.7 0 0 0-1.2-.5L6 7.4H3a1 1 0 0 0-1 1v7.2a1 1 0 0 0 1 1h3l3.8 3.2a.7.7 0 0 0 1.2-.5z' }],
    ['path', { d: 'M16 9a4 4 0 0 1 0 6' }],
    ['path', { d: 'M19.07 4.93a10 10 0 0 1 0 14.14' }]
  ],
  WandSparkles: [
    ['path', { d: 'm21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72Z' }],
    ['path', { d: 'm14 7 3 3' }],
    ['path', { d: 'M5 6v4' }],
    ['path', { d: 'M19 14v4' }],
    ['path', { d: 'M10 2v2' }],
    ['path', { d: 'M7 8H3' }],
    ['path', { d: 'M21 16h-4' }],
    ['path', { d: 'M11 3H9' }]
  ],
  X: [
    ['path', { d: 'M18 6 6 18' }],
    ['path', { d: 'm6 6 12 12' }]
  ],
  Zap: [
    ['path', { d: 'M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z' }]
  ],
  GraduationCap: [
    ['path', { d: 'M21.42 10.922a1 1 0 0 0-.019-1.838L12.83 5.18a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.832l8.57 3.908a2 2 0 0 0 1.66 0z' }],
    ['path', { d: 'M22 10v6' }],
    ['path', { d: 'M6 12.5V16a6 3 0 0 0 12 0v-3.5' }]
  ],
  Play: [
    ['polygon', { points: '6 3 20 12 6 21 6 3' }]
  ],
  Pause: [
    ['rect', { width: 4, height: 16, x: 6, y: 4, rx: 1 }],
    ['rect', { width: 4, height: 16, x: 14, y: 4, rx: 1 }]
  ],
  Eye: [
    ['path', { d: 'M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0' }],
    ['circle', { cx: 12, cy: 12, r: 3 }]
  ],
  Maximize: [
    ['path', { d: 'M8 3H5a2 2 0 0 0-2 2v3' }],
    ['path', { d: 'M21 8V5a2 2 0 0 0-2-2h-3' }],
    ['path', { d: 'M3 16v3a2 2 0 0 0 2 2h3' }],
    ['path', { d: 'M16 21h3a2 2 0 0 0 2-2v-3' }]
  ]
}

function makeIcon(name, fallback) {
  return defineComponent({
    name,
    inheritAttrs: false,
    setup(_, { attrs }) {
      return () => h('svg', {
        ...attrs,
        width: attrs.size || 16,
        height: attrs.size || 16,
        viewBox: '0 0 24 24',
        fill: 'none',
        stroke: 'currentColor',
        'stroke-width': attrs['stroke-width'] || 1.8,
        'stroke-linecap': 'round',
        'stroke-linejoin': 'round',
        'aria-hidden': 'true'
      }, (fallback ? [
        ['circle', { cx: 12, cy: 12, r: 8 }],
        ['path', { d: 'M12 8v8M8 12h8' }]
      ] : shapes[name]).map(([tag, props]) => h(tag, props)))
    }
  })
}

const names = Object.keys(shapes)

export const icons = Object.fromEntries(names.map((name) => [name, makeIcon(name, false)]))
export const EnterpriseIcon = makeIcon('CirclePlus', true)
export const {
  AlertTriangle, Archive, ArrowLeft, ArrowUpRight, AudioWaveform, Bell, BellRing,
  Bookmark, BriefcaseBusiness, Building2, CalendarClock, CalendarDays, CalendarPlus,
  CalendarSync, Camera, Check, CheckCheck, CheckCircle2, ChevronDown, ChevronLeft,
  ChevronRight, ChevronUp, CircleCheck, CircleCheckBig, CirclePause, CircleX, Clock3,
  CloudUpload, Copy, Database, Download, FileCheck2, FileText, GitBranch, Globe2,
  GripVertical, History, KeyRound, LayoutDashboard, Lightbulb, Link2, Mail, MailPlus,
  MapPin, Megaphone, MessageCircle, MessageSquare, MessageSquareText, Mic, MicOff,
  MonitorUp, Paperclip, PauseCircle, Pencil, PhoneOff, Plus, RotateCcw, RotateCw,
  Save, Search, Send, Settings, Settings2, ShieldCheck, SlidersHorizontal, Smile,
  Smartphone, Sparkles, Tags, Target, Timer, Trash2, Upload, UserRound, UserRoundCheck,
  UserX, Users, UsersRound, Video, Volume2, WandSparkles, X, Zap, GraduationCap,
  Play, Pause, Eye, Maximize, Bot
} = icons
