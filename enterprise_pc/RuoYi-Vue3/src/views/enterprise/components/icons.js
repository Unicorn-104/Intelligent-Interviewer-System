import { defineComponent, h } from 'vue'

const EnterpriseIcon = defineComponent({
  name: 'EnterpriseIcon',
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
    }, [
      h('circle', { cx: 12, cy: 12, r: 8 }),
      h('path', { d: 'M12 8v8M8 12h8' })
    ])
  }
})

const names = [
  'AlertTriangle', 'Archive', 'ArrowLeft', 'ArrowUpRight', 'AudioWaveform', 'Bell', 'BellRing',
  'Bookmark', 'BriefcaseBusiness', 'Building2', 'CalendarClock', 'CalendarDays', 'CalendarPlus',
  'CalendarSync', 'Camera', 'Check', 'CheckCheck', 'CheckCircle2', 'ChevronDown', 'ChevronLeft',
  'ChevronRight', 'ChevronUp', 'CircleCheck', 'CircleCheckBig', 'CirclePause', 'CircleX', 'Clock3',
  'CloudUpload', 'Copy', 'Database', 'Download', 'FileCheck2', 'FileText', 'GitBranch', 'Globe2',
  'GripVertical', 'History', 'KeyRound', 'LayoutDashboard', 'Lightbulb', 'Link2', 'Mail', 'MailPlus',
  'MapPin', 'Megaphone', 'MessageCircle', 'MessageSquare', 'MessageSquareText', 'Mic', 'MicOff',
  'MonitorUp', 'Paperclip', 'PauseCircle', 'Pencil', 'PhoneOff', 'Plus', 'RotateCcw', 'RotateCw',
  'Save', 'Search', 'Send', 'Settings', 'Settings2', 'ShieldCheck', 'SlidersHorizontal', 'Smile',
  'Smartphone', 'Sparkles', 'Tags', 'Target', 'Timer', 'Trash2', 'Upload', 'UserRound', 'UserRoundCheck',
  'UserX', 'Users', 'UsersRound', 'Video', 'Volume2', 'WandSparkles', 'X', 'Zap', 'GraduationCap'
]

export const icons = Object.fromEntries(names.map((name) => [name, EnterpriseIcon]))
export { EnterpriseIcon }
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
  UserX, Users, UsersRound, Video, Volume2, WandSparkles, X, Zap, GraduationCap
} = icons
