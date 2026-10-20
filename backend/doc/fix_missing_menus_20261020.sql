-- MySQL dump 10.13  Distrib 8.0.37, for Win64 (x86_64)
--
-- Host: localhost    Database: recruit_agent
-- ------------------------------------------------------
-- Server version	8.0.37

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `sys_menu`
--
-- WHERE:  menu_id IN(2001,2003,2004,2005,2006,2007,2012,2013,2021,2030,2031,2032,2033,2034,2045,2047,2048,2049,2050,2051,2052,2053,2054,2055,2056,2100,2101,2102,2103,2104,2105,2106)

/*!40000 ALTER TABLE `sys_menu` DISABLE KEYS */;
REPLACE INTO `sys_menu` (`menu_id`, `menu_name`, `parent_id`, `order_num`, `path`, `component`, `query`, `route_name`, `is_frame`, `is_cache`, `url`, `target`, `menu_type`, `visible`, `status`, `is_refresh`, `perms`, `icon`, `create_by`, `create_time`, `update_by`, `update_time`, `remark`) VALUES (2001,'用户管理',0,2,'business','Layout',NULL,'',1,0,'#','','M','0','0','1','system','tree','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2003,'企业管理',0,1,'company','Layout',NULL,'',1,0,'#','','M','0','0','1','company','peoples','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2004,'内容运营',0,5,'content','Layout',NULL,'',1,0,'#','','M','0','0','1','operation','documentation','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2005,'用户管理',2001,0,'',NULL,NULL,'',1,0,'#','','F','0','0','1','system:user','#','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2006,'角色权限',2001,0,'',NULL,NULL,'',1,0,'#','','F','0','0','1','system:role','#','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2007,'参数配置',2001,0,'',NULL,NULL,'',1,0,'#','','F','0','0','1','system:config','#','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2012,'认证审核',2003,0,'',NULL,NULL,'',1,0,'#','','F','0','0','1','company:verify','#','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2013,'成员审核',2003,0,'',NULL,NULL,'',1,0,'#','','F','0','0','1','company:member','#','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2021,'分配角色',2006,0,'',NULL,NULL,'',1,0,'#','','F','0','0','1','role:assign','#','admin','2026-09-21 10:57:37','','2026-09-21 10:57:37',''),(2030,'企业审核',2003,1,'company/list','tenant/company/index','','',1,0,'#','','C','0','0','1','company:list','documentation','admin','2026-09-28 10:35:23','',NULL,'企业认证审核列表'),(2031,'实名认证审核',2001,2,'verify','member/verify/index','','',1,0,'#','','C','0','1','1','member:verify','edit','admin','2026-09-28 10:35:23','',NULL,'用户实名认证审核'),(2032,'AI配置',0,4,'ai','Layout','','',1,0,'#','','M','0','0','1','','guide','admin','2026-09-28 10:35:23','',NULL,'AI模型与Prompt配置'),(2033,'模型Provider',2032,1,'provider-list','ai/model/index','','',1,0,'#','','C','0','0','1','ai:model:list','guide','admin','2026-09-28 10:35:23','',NULL,'大模型Provider配置'),(2034,'Prompt版本',2032,2,'prompt-list','ai/prompt/index','','',1,0,'#','','C','0','0','1','ai:prompt:list','log','admin','2026-09-28 10:35:23','',NULL,'Prompt版本管理'),(2045,'用户列表',2001,1,'list','member/user/index',NULL,'',1,0,'#','','C','0','0','1','member:user:list','user','admin','2026-09-28 10:43:28','',NULL,''),(2047,'AI配额',2032,3,'quota','ai/quota/index',NULL,'',1,0,'#','','C','0','0','1','ai:quota:list','server','admin','2026-09-28 10:43:28','',NULL,''),(2048,'AI记分卡',2032,4,'scorecard','ai/scorecard/index',NULL,'',1,0,'#','','C','0','0','1','ai:scorecard:list','chart','admin','2026-09-28 10:43:28','',NULL,''),(2049,'内容分类',2004,1,'category','content/category/index',NULL,'',1,0,'#','','C','0','0','1','content:category:list','tab','admin','2026-09-28 10:43:28','',NULL,''),(2050,'问题管理',2004,2,'question','content/question/index',NULL,'',1,0,'#','','C','0','0','1','content:question:list','question','admin','2026-09-28 10:43:28','',NULL,''),(2051,'反馈处理',2004,3,'feedback','content/feedback/index',NULL,'',1,0,'#','','C','0','0','1','content:feedback:list','message','admin','2026-09-28 10:43:28','',NULL,''),(2052,'帮助中心',2004,4,'help','content/help/index',NULL,'',1,0,'#','','C','0','0','1','content:help:list','documentation','admin','2026-09-28 10:43:28','',NULL,''),(2053,'消息管理',0,6,'msg','Layout',NULL,'',1,0,'#','','M','0','0','1','','message','admin','2026-09-28 10:43:28','',NULL,''),(2054,'消息模板',2053,1,'template','msg/template/index',NULL,'',1,0,'#','','C','0','0','1','msg:template:list','email','admin','2026-09-28 10:43:28','',NULL,''),(2055,'发送记录',2053,2,'record','msg/record/index',NULL,'',1,0,'#','','C','0','0','1','msg:record:list','log','admin','2026-09-28 10:43:28','',NULL,''),(2056,'渠道配置',2053,3,'channel','msg/channel/index',NULL,'',1,0,'#','','C','0','0','1','msg:channel:list','system','admin','2026-09-28 10:43:28','',NULL,''),(2100,'企业用户',2003,2,'user','tenant/user/index',NULL,'',1,0,'#','','C','0','0','1','tenant:user:list','peoples','admin','2026-09-28 14:08:40','',NULL,''),(2101,'广告管理',2004,5,'advert','ad/advert/index','','',1,0,'#','','C','0','0','1','ad:advert:list','eye','admin','2026-10-13 09:48:54','',NULL,'广告管理菜单'),(2102,'广告位管理',2004,6,'slot','ad/slot/index','','',1,0,'#','','C','0','0','1','ad:slot:list','monitor','admin','2026-10-13 09:48:54','',NULL,'广告位管理菜单'),(2103,'广告查询',2102,1,'','','','',1,0,'#','','F','0','0','1','ad:advert:query','#','admin','2026-10-13 09:48:54','',NULL,''),(2104,'广告新增',2103,2,'','','','',1,0,'#','','F','0','0','1','ad:advert:add','#','admin','2026-10-13 09:48:54','',NULL,''),(2105,'广告修改',2104,3,'','','','',1,0,'#','','F','0','0','1','ad:advert:edit','#','admin','2026-10-13 09:48:54','',NULL,''),(2106,'广告删除',2105,4,'','','','',1,0,'#','','F','0','0','1','ad:advert:remove','#','admin','2026-10-13 09:48:54','',NULL,'');
/*!40000 ALTER TABLE `sys_menu` ENABLE KEYS */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-20 11:58:58
