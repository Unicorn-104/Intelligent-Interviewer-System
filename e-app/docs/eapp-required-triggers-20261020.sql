-- DBA-only review/execution; not yet installed on the server due to ERROR 1419.
-- Does not change global binary-log security configuration. Target: recruit_agent, MySQL >= 8.0.29.
USE recruit_agent;
SET NAMES utf8mb4;

SET SESSION lock_wait_timeout=15;

DELIMITER $$

CREATE TRIGGER IF NOT EXISTS `trg_app_record_after_insert` AFTER INSERT ON `t_app_record` FOR EACH ROW
BEGIN
    UPDATE `t_tal` SET tal_status = 1, tal_updated_at = NOW()
    WHERE tal_id = NEW.app_candidate_id AND tal_status = 0;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_tal_status_log_after_update` AFTER UPDATE ON `t_tal` FOR EACH ROW
BEGIN
    IF NEW.tal_status <> OLD.tal_status THEN
        INSERT INTO `t_tal_status_log` (tsl_candidate_id, tsl_from_status, tsl_to_status, tsl_operator_id, tsl_reason, tsl_created_at)
        VALUES (NEW.tal_id, OLD.tal_status, NEW.tal_status, NULL, '状态变更', NOW());
    END IF;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_process_instance_after_update` AFTER UPDATE ON `t_process_instance` FOR EACH ROW
BEGIN
    IF NEW.pin_status <> OLD.pin_status OR
       (NEW.pin_current_stage_id <> IFNULL(OLD.pin_current_stage_id, 0)) THEN
        INSERT INTO `sys_oper_log` (
            aud_user_id, aud_action, aud_object_type, aud_object_id,
            aud_detail, aud_log_type, oper_ip, status, oper_time
        ) VALUES (
            NULL, 'UPDATE_PROCESS_INSTANCE', 'PROCESS_INSTANCE', NEW.pin_id,
            JSON_OBJECT(
                'from_status', OLD.pin_status, 'to_status', NEW.pin_status,
                'from_stage', OLD.pin_current_stage_id, 'to_stage', NEW.pin_current_stage_id
            ),
            2, NULL, 1, NOW()
        );
    END IF;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_exam_record_after_update` AFTER UPDATE ON `t_exam_record` FOR EACH ROW
BEGIN
    IF NEW.erc_status <> OLD.erc_status THEN
        INSERT INTO `sys_oper_log` (
            aud_user_id, aud_action, aud_object_type, aud_object_id,
            aud_detail, aud_log_type, oper_ip, status, oper_time
        ) VALUES (
            NULL, 'UPDATE_EXAM_RECORD', 'EXAM_RECORD', NEW.erc_id,
            JSON_OBJECT('from_status', OLD.erc_status, 'to_status', NEW.erc_status),
            2, NULL, 1, NOW()
        );
    END IF;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_exam_schedule_after_update` AFTER UPDATE ON `t_exam_schedule` FOR EACH ROW
BEGIN
    IF NEW.esd_status <> OLD.esd_status THEN
        INSERT INTO `sys_oper_log` (
            aud_user_id, aud_action, aud_object_type, aud_object_id,
            aud_detail, aud_log_type, oper_ip, status, oper_time
        ) VALUES (
            NULL, 'UPDATE_EXAM_SCHEDULE', 'EXAM_SCHEDULE', NEW.esd_id,
            JSON_OBJECT('from_status', OLD.esd_status, 'to_status', NEW.esd_status),
            2, NULL, 1, NOW()
        );
    END IF;
END$$

CREATE TRIGGER IF NOT EXISTS `trg_offer_approval_after_update` AFTER UPDATE ON `t_offer_approval` FOR EACH ROW
BEGIN
    IF NEW.oap_status <> OLD.oap_status THEN
        INSERT INTO `sys_oper_log` (
            aud_user_id, aud_action, aud_object_type, aud_object_id,
            aud_detail, aud_log_type, oper_ip, status, oper_time
        ) VALUES (
            NEW.oap_approver_id, 'UPDATE_OFFER_APPROVAL', 'OFFER_APPROVAL', NEW.oap_id,
            JSON_OBJECT('from_status', OLD.oap_status, 'to_status', NEW.oap_status),
            2, NULL, 1, NOW()
        );
    END IF;
END$$

DELIMITER ;

SELECT TRIGGER_NAME,EVENT_OBJECT_TABLE FROM INFORMATION_SCHEMA.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() ORDER BY TRIGGER_NAME;
