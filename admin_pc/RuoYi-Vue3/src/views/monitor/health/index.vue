<template>
  <div class="app-container">
    <el-card shadow="never">
      <el-empty description="暂无告警数据，系统运行正常">
        <template #image>
          <div style="font-size:48px;color:#67c23a;">✓</div>
        </template>
        <template #description>
          <p style="font-size:16px;font-weight:600;color:#303133;">系统运行正常</p>
          <p style="font-size:13px;color:#909399;">暂无 CPU / 内存 / 磁盘 / 服务异常告警</p>
        </template>
      </el-empty>
    </el-card>
  </div>
</template>

<script setup name="HealthAlert">
</script>
