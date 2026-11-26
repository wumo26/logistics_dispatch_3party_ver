-- Public structural snapshot; import only into a new, empty schema.

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
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin_sticky_notes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `admin_id` bigint NOT NULL,
  `color` varchar(20) NOT NULL,
  `content` varchar(2000) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `sort_order` int NOT NULL,
  `title` varchar(120) DEFAULT NULL,
  `updated_at` datetime(6) NOT NULL,
  `version` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_admin_sticky_notes_owner_sort` (`admin_id`,`sort_order`,`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin_users` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `account` varchar(60) NOT NULL,
  `password` varchar(100) NOT NULL,
  `name` varchar(60) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `ai_api_key_encrypted` varchar(512) DEFAULT NULL,
  `ai_api_key_last4` varchar(4) DEFAULT NULL,
  `ai_api_key_updated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_users_account` (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance_records` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `driver_shift_id` bigint NOT NULL,
  `driver_id` bigint NOT NULL,
  `work_date` date NOT NULL,
  `clock_in_at` datetime(6) NOT NULL,
  `clock_out_at` datetime(6) DEFAULT NULL,
  `break_used` bit(1) NOT NULL DEFAULT b'0',
  `break_started_at` datetime(6) DEFAULT NULL,
  `break_ends_at` datetime(6) DEFAULT NULL,
  `overtime_started_at` datetime(6) DEFAULT NULL,
  `regular_work_minutes` int NOT NULL DEFAULT '0',
  `overtime_minutes` int NOT NULL DEFAULT '0',
  `total_work_minutes` int NOT NULL DEFAULT '0',
  `status` enum('CLOCKED_OUT','ON_BREAK','OVERTIME','WORKING') NOT NULL,
  `version` bigint NOT NULL DEFAULT '0',
  `punctuality_status` enum('LATE','LATE_EXCUSED','LEAVE_COVERED','LEAVE_REQUIRED','ON_TIME') NOT NULL DEFAULT 'ON_TIME',
  `late_minutes` int NOT NULL DEFAULT '0',
  `late_excused` bit(1) NOT NULL DEFAULT b'0',
  `leave_required` bit(1) NOT NULL DEFAULT b'0',
  `leave_required_minutes` int NOT NULL DEFAULT '0',
  `covered_leave_request_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_attendance_shift` (`driver_shift_id`),
  KEY `idx_attendance_driver_date` (`driver_id`,`work_date`),
  CONSTRAINT `fk_attendance_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_attendance_shift` FOREIGN KEY (`driver_shift_id`) REFERENCES `driver_shifts` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `delivery_records` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `arrived_at` datetime(6) DEFAULT NULL,
  `delivered_at` datetime(6) DEFAULT NULL,
  `delivered_box_count` int DEFAULT NULL,
  `expected_box_count` int DEFAULT NULL,
  `shortage_box_count` int DEFAULT NULL,
  `damaged_box_count` int DEFAULT NULL,
  `replacement_required_box_count` int DEFAULT NULL,
  `route_id` bigint DEFAULT NULL,
  `driver_id` bigint DEFAULT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `attempt_date` date DEFAULT NULL,
  `lat` double DEFAULT NULL,
  `lng` double DEFAULT NULL,
  `no_signature` bit(1) NOT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `order_id` bigint NOT NULL,
  `photo_url` varchar(500) DEFAULT NULL,
  `handled_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_delivery_records_order` (`order_id`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dispatch_templates` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_dispatch_templates_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `distance_matrix_cache` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `distance` int NOT NULL,
  `duration` int NOT NULL,
  `from_id` bigint NOT NULL,
  `from_type` enum('STORE','WAREHOUSE') NOT NULL,
  `to_id` bigint NOT NULL,
  `to_type` enum('STORE','WAREHOUSE') NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_matrix_from_to` (`from_type`,`from_id`,`to_type`,`to_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `driver_account_applications` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `account` varchar(60) NOT NULL,
  `password_hash` varchar(100) NOT NULL,
  `national_id_masked` varchar(10) NOT NULL,
  `name` varchar(50) NOT NULL,
  `phone` varchar(30) NOT NULL,
  `status` enum('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  `applied_at` datetime(6) NOT NULL,
  `reviewed_by` varchar(50) DEFAULT NULL,
  `reviewed_at` datetime(6) DEFAULT NULL,
  `rejection_reason` varchar(500) DEFAULT NULL,
  `approved_driver_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_driver_account_applications_account` (`account`),
  KEY `idx_driver_account_applications_status_applied` (`status`,`applied_at`),
  KEY `fk_driver_account_applications_driver` (`approved_driver_id`),
  CONSTRAINT `fk_driver_account_applications_driver` FOREIGN KEY (`approved_driver_id`) REFERENCES `drivers` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `driver_leave_request_events` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `actor_account` varchar(60) NOT NULL,
  `actor_id` bigint NOT NULL,
  `actor_type` enum('ADMIN','DRIVER','SYSTEM') NOT NULL,
  `driver_id` bigint NOT NULL,
  `event_type` enum('APPROVED','AUTO_NO_SHOW_CREATED','DRIVER_EXPLANATION_SUBMITTED','PLANNED_CREATED','REJECTED','SUBMITTED','TYPE_CHANGED') NOT NULL,
  `leave_request_id` bigint NOT NULL,
  `new_leave_type` enum('ABSENT','ANNUAL','BEREAVEMENT','MENSTRUAL','PERSONAL','SICK','SPECIAL') DEFAULT NULL,
  `new_status` enum('APPROVED','PENDING','REJECTED') DEFAULT NULL,
  `occurred_at` datetime(6) NOT NULL,
  `old_leave_type` enum('ABSENT','ANNUAL','BEREAVEMENT','MENSTRUAL','PERSONAL','SICK','SPECIAL') DEFAULT NULL,
  `old_status` enum('APPROVED','PENDING','REJECTED') DEFAULT NULL,
  `reason` varchar(500) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_leave_event_request_time` (`leave_request_id`,`occurred_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `driver_leave_requests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `decision_reason` varchar(500) DEFAULT NULL,
  `driver_id` bigint NOT NULL,
  `driver_read_at` datetime(6) DEFAULT NULL,
  `driver_shift_id` bigint NOT NULL,
  `full_day` bit(1) NOT NULL,
  `last_updated_at` datetime(6) NOT NULL,
  `leave_end` time DEFAULT NULL,
  `leave_start` time DEFAULT NULL,
  `leave_type` enum('ABSENT','ANNUAL','BEREAVEMENT','MENSTRUAL','PERSONAL','SICK','SPECIAL') NOT NULL,
  `request_reason` varchar(500) NOT NULL,
  `requested_at` datetime(6) NOT NULL,
  `requested_leave_type` enum('ABSENT','ANNUAL','BEREAVEMENT','MENSTRUAL','PERSONAL','SICK','SPECIAL') NOT NULL,
  `reviewed_at` datetime(6) DEFAULT NULL,
  `reviewed_by` varchar(60) DEFAULT NULL,
  `reviewed_by_admin_id` bigint DEFAULT NULL,
  `status` enum('APPROVED','PENDING','REJECTED') NOT NULL,
  `submission_source` enum('ADMIN','DRIVER','SYSTEM') NOT NULL,
  `type_change_reason` varchar(500) DEFAULT NULL,
  `type_changed_at` datetime(6) DEFAULT NULL,
  `type_changed_by` varchar(60) DEFAULT NULL,
  `type_changed_by_admin_id` bigint DEFAULT NULL,
  `version` bigint NOT NULL,
  `work_date` date NOT NULL,
  `batch_id` varchar(36) DEFAULT NULL,
  `request_mode` enum('PREPLANNED','TEMPORARY','MAKEUP','SYSTEM_NO_SHOW','ADMIN_PLANNED_PARTIAL') NOT NULL DEFAULT 'TEMPORARY',
  `evidence_photo_url` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_driver_leave_driver_date` (`driver_id`,`work_date`),
  KEY `idx_driver_leave_shift` (`driver_shift_id`),
  KEY `idx_driver_leave_status_requested` (`status`,`requested_at`),
  KEY `idx_driver_leave_batch` (`batch_id`,`work_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `driver_messages` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `content` varchar(1000) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `driver_id` bigint NOT NULL,
  `read_at` datetime(6) DEFAULT NULL,
  `sender_admin_id` bigint DEFAULT NULL,
  `sender_type` enum('ADMIN','DRIVER') NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `driver_shifts` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `schedule_month_id` bigint NOT NULL,
  `driver_id` bigint NOT NULL,
  `work_date` date NOT NULL,
  `shift_type` enum('UNASSIGNED','WORK','DAY_OFF','LEAVE') NOT NULL DEFAULT 'UNASSIGNED',
  `work_start` time DEFAULT NULL,
  `work_end` time DEFAULT NULL,
  `overtime_minutes` int NOT NULL DEFAULT '0',
  `change_reason` varchar(255) DEFAULT NULL,
  `last_modified_at` datetime(6) NOT NULL,
  `version` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_driver_shifts_driver_date` (`driver_id`,`work_date`),
  KEY `idx_driver_shifts_month_date` (`schedule_month_id`,`work_date`),
  CONSTRAINT `fk_driver_shifts_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_driver_shifts_month` FOREIGN KEY (`schedule_month_id`) REFERENCES `schedule_months` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `drivers` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `account` varchar(60) NOT NULL,
  `is_active` bit(1) NOT NULL,
  `max_overtime_minutes` int DEFAULT NULL,
  `name` varchar(50) NOT NULL,
  `password` varchar(100) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `rest_duration` int NOT NULL,
  `work_end` time NOT NULL,
  `work_start` time NOT NULL,
  `profile_photo_url` varchar(500) DEFAULT NULL,
  `warehouse_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKqpri8sn139f15suhc00v30tse` (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `emergency_leave_requests` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `driver_id` bigint NOT NULL,
  `work_date` date NOT NULL,
  `attendance_record_id` bigint NOT NULL,
  `route_id` bigint NOT NULL,
  `vehicle_id` bigint NOT NULL,
  `reason` varchar(500) NOT NULL,
  `status` enum('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  `replacement_driver_id` bigint DEFAULT NULL,
  `transferred_order_count` int NOT NULL DEFAULT '0',
  `gps_override_granted` bit(1) NOT NULL DEFAULT b'0',
  `requested_at` datetime(6) NOT NULL,
  `reviewed_by` varchar(60) DEFAULT NULL,
  `reviewed_at` datetime(6) DEFAULT NULL,
  `rejection_reason` varchar(500) DEFAULT NULL,
  `route_reassigned_at` datetime(6) DEFAULT NULL,
  `clocked_out_at` datetime(6) DEFAULT NULL,
  `version` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_emergency_leave_driver_date` (`driver_id`,`work_date`),
  KEY `idx_emergency_leave_status_requested` (`status`,`requested_at`),
  KEY `fk_emergency_leave_attendance` (`attendance_record_id`),
  KEY `fk_emergency_leave_route` (`route_id`),
  KEY `fk_emergency_leave_vehicle` (`vehicle_id`),
  KEY `fk_emergency_leave_replacement_driver` (`replacement_driver_id`),
  CONSTRAINT `fk_emergency_leave_attendance` FOREIGN KEY (`attendance_record_id`) REFERENCES `attendance_records` (`id`),
  CONSTRAINT `fk_emergency_leave_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_emergency_leave_replacement_driver` FOREIGN KEY (`replacement_driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_emergency_leave_route` FOREIGN KEY (`route_id`) REFERENCES `routes` (`id`),
  CONSTRAINT `fk_emergency_leave_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `exception_cases` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `created_at` datetime(6) NOT NULL,
  `description` varchar(1000) DEFAULT NULL,
  `handled_at` datetime(6) DEFAULT NULL,
  `handled_by` varchar(50) DEFAULT NULL,
  `order_id` bigint DEFAULT NULL,
  `delivery_record_id` bigint DEFAULT NULL,
  `follow_up_order_id` bigint DEFAULT NULL,
  `review_available_at` datetime(6) DEFAULT NULL,
  `queued_at` datetime(6) DEFAULT NULL,
  `resolution` varchar(1000) DEFAULT NULL,
  `status` enum('CLOSED','OPEN') NOT NULL,
  `type` enum('DRIVER_REPORT','NO_SIGNATURE','PHONE_HANDLED','DAMAGE','SHORTAGE','SHORTAGE_AND_DAMAGE','LOADING_MISMATCH') NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_exception_cases_status_created` (`status`,`created_at`),
  KEY `idx_exception_cases_due` (`status`,`queued_at`,`review_available_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `flyway_schema_history` (
  `installed_rank` int NOT NULL,
  `version` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `script` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `checksum` int DEFAULT NULL,
  `installed_by` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `installed_on` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `execution_time` int NOT NULL,
  `success` tinyint(1) NOT NULL,
  PRIMARY KEY (`installed_rank`),
  KEY `flyway_schema_history_s_idx` (`success`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `fuel_price_history` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `fuel_type` enum('GASOLINE_92','GASOLINE_95','GASOLINE_98','DIESEL','OTHER') NOT NULL,
  `price_per_liter` decimal(8,3) NOT NULL,
  `effective_from` datetime(6) NOT NULL,
  `source` varchar(100) NOT NULL,
  `fetched_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_fuel_price_type_effective` (`fuel_type`,`effective_from`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `gps_pings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `driver_id` bigint NOT NULL,
  `lat` double NOT NULL,
  `lng` double NOT NULL,
  `timestamp` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_gps_driver_time` (`driver_id`,`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mileage_logs` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `date` date NOT NULL,
  `driver_id` bigint NOT NULL,
  `end_odometer` int DEFAULT NULL,
  `end_time` datetime(6) DEFAULT NULL,
  `start_odometer` int DEFAULT NULL,
  `start_time` datetime(6) DEFAULT NULL,
  `route_id` bigint DEFAULT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `gps_distance_km` double DEFAULT NULL,
  `gps_distance_status` varchar(50) DEFAULT NULL,
  `mileage_settled_at` datetime(6) DEFAULT NULL,
  `actual_distance_km` int DEFAULT NULL,
  `mileage_photo_url` varchar(512) DEFAULT NULL,
  `mileage_photo_recorded_at` datetime(6) DEFAULT NULL,
  `end_mileage_photo_url` varchar(512) DEFAULT NULL,
  `end_mileage_photo_recorded_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mileage_logs_driver_date` (`driver_id`,`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_items` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `order_id` bigint NOT NULL,
  `product_code` varchar(50) DEFAULT NULL,
  `item_name` varchar(100) NOT NULL,
  `expected_quantity` int NOT NULL,
  `unit` varchar(20) NOT NULL DEFAULT '件',
  `sequence` int NOT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `loaded_quantity` int DEFAULT NULL,
  `checked_at` datetime(6) DEFAULT NULL,
  `checked_by_driver_id` bigint DEFAULT NULL,
  `loading_notes` varchar(255) DEFAULT NULL,
  `loading_mismatch_reported` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`id`),
  KEY `idx_order_items_order_sequence` (`order_id`,`sequence`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `orders` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `assigned_driver_id` bigint DEFAULT NULL,
  `assigned_vehicle_id` bigint DEFAULT NULL,
  `box_count` int NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `delivery_date` date NOT NULL,
  `item_description` varchar(255) DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `order_number` varchar(30) NOT NULL,
  `route_id` bigint DEFAULT NULL,
  `sequence` int DEFAULT NULL,
  `source_vendor` varchar(100) DEFAULT NULL,
  `status` enum('PENDING_CONFIRM','CONFIRMED','IN_DELIVERY','COMPLETED','CANCELLED','FAILED','NO_SIGNATURE','LOADED') NOT NULL,
  `order_type` enum('NORMAL','REDELIVERY','REPLENISHMENT') NOT NULL DEFAULT 'NORMAL',
  `parent_order_id` bigint DEFAULT NULL,
  `retry_count` int NOT NULL DEFAULT '0',
  `store_id` bigint NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `warehouse_id` bigint NOT NULL,
  `loaded_at` datetime(6) DEFAULT NULL,
  `loading_notes` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKnthkiu7pgmnqnu86i2jyoe2v7` (`order_number`),
  KEY `fk_orders_parent` (`parent_order_id`),
  CONSTRAINT `fk_orders_parent` FOREIGN KEY (`parent_order_id`) REFERENCES `orders` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `pre_trip_inspections` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `route_id` bigint NOT NULL,
  `driver_id` bigint NOT NULL,
  `vehicle_id` bigint NOT NULL,
  `route_version` int NOT NULL,
  `work_date` date NOT NULL,
  `alcohol_mg_l` decimal(3,2) NOT NULL,
  `alcohol_tested` bit(1) NOT NULL,
  `headlights` bit(1) NOT NULL,
  `taillights` bit(1) NOT NULL,
  `turn_signals` bit(1) NOT NULL,
  `brake_lights` bit(1) NOT NULL,
  `front_left_tire` bit(1) NOT NULL,
  `front_right_tire` bit(1) NOT NULL,
  `rear_left_tire` bit(1) NOT NULL,
  `rear_right_tire` bit(1) NOT NULL,
  `dashcam` bit(1) NOT NULL,
  `alcohol_photo` varchar(255) NOT NULL,
  `vehicle_photo` varchar(255) NOT NULL,
  `dashcam_photo` varchar(255) NOT NULL,
  `passed` bit(1) NOT NULL,
  `submitted_at` datetime(6) NOT NULL,
  `invalidated_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pre_trip_route` (`route_id`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `route_leg_mileages` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `accepted_segment_count` int NOT NULL DEFAULT '0',
  `calculation_status` varchar(50) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `delivery_record_id` bigint DEFAULT NULL,
  `driver_id` bigint NOT NULL,
  `ended_at` datetime(6) NOT NULL,
  `from_store_id` bigint DEFAULT NULL,
  `from_type` enum('STORE','WAREHOUSE') NOT NULL,
  `gps_point_count` int NOT NULL DEFAULT '0',
  `mileage_log_id` bigint NOT NULL,
  `order_id` bigint DEFAULT NULL,
  `route_id` bigint NOT NULL,
  `sequence` int NOT NULL,
  `started_at` datetime(6) NOT NULL,
  `system_distance_km` double DEFAULT NULL,
  `to_store_id` bigint DEFAULT NULL,
  `to_type` enum('STORE','WAREHOUSE') NOT NULL,
  `vehicle_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_route_leg_mileage_log_sequence` (`mileage_log_id`,`sequence`),
  KEY `idx_route_leg_route_sequence` (`route_id`,`sequence`),
  KEY `idx_route_leg_driver_time` (`driver_id`,`started_at`,`ended_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `route_template_stores` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `template_id` bigint NOT NULL,
  `store_id` bigint NOT NULL,
  `sequence` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tpl_stores_tpl_store` (`template_id`,`store_id`),
  KEY `idx_tpl_stores_tpl_seq` (`template_id`,`sequence`),
  KEY `fk_tpl_stores_store` (`store_id`),
  CONSTRAINT `fk_tpl_stores_store` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`),
  CONSTRAINT `fk_tpl_stores_template` FOREIGN KEY (`template_id`) REFERENCES `route_templates` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `route_templates` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `warehouse_id` bigint NOT NULL,
  `default_vehicle_id` bigint DEFAULT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `is_active` bit(1) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_route_templates_wh_name` (`warehouse_id`,`name`),
  KEY `fk_route_templates_vehicle` (`default_vehicle_id`),
  CONSTRAINT `fk_route_templates_vehicle` FOREIGN KEY (`default_vehicle_id`) REFERENCES `vehicles` (`id`),
  CONSTRAINT `fk_route_templates_warehouse` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `route_vehicle_segments` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `route_id` bigint NOT NULL,
  `segment_no` int NOT NULL,
  `vehicle_id` bigint NOT NULL,
  `driver_id` bigint DEFAULT NULL,
  `source_mileage_log_id` bigint DEFAULT NULL,
  `start_time` datetime(6) DEFAULT NULL,
  `end_time` datetime(6) DEFAULT NULL,
  `start_odometer_km` decimal(12,1) DEFAULT NULL,
  `end_odometer_km` decimal(12,1) DEFAULT NULL,
  `start_lat` double DEFAULT NULL,
  `start_lng` double DEFAULT NULL,
  `end_lat` double DEFAULT NULL,
  `end_lng` double DEFAULT NULL,
  `planned_distance_m` bigint DEFAULT NULL,
  `actual_distance_m` bigint DEFAULT NULL,
  `fuel_type_snapshot` enum('GASOLINE_92','GASOLINE_95','GASOLINE_98','DIESEL','ELECTRIC','OTHER') DEFAULT NULL,
  `fuel_efficiency_km_per_liter` decimal(8,3) DEFAULT NULL,
  `fuel_price_per_liter_snapshot` decimal(8,3) DEFAULT NULL,
  `estimated_fuel_liters` decimal(12,3) DEFAULT NULL,
  `estimated_fuel_cost` decimal(12,2) DEFAULT NULL,
  `actual_fuel_liters` decimal(12,3) DEFAULT NULL,
  `actual_fuel_cost` decimal(12,2) DEFAULT NULL,
  `calculation_basis` enum('PLANNED_DISTANCE','ODOMETER','GPS','MANUAL') NOT NULL DEFAULT 'PLANNED_DISTANCE',
  `start_reason` enum('INITIAL','VEHICLE_REPLACEMENT','RECOVERY') NOT NULL DEFAULT 'INITIAL',
  `end_reason` enum('COMPLETED','BREAKDOWN','VEHICLE_REPLACEMENT','CANCELLED') DEFAULT NULL,
  `status` enum('PLANNED','ACTIVE','COMPLETED','INTERRUPTED') NOT NULL DEFAULT 'PLANNED',
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_route_vehicle_segments_route_no` (`route_id`,`segment_no`),
  UNIQUE KEY `uk_route_vehicle_segments_mileage` (`source_mileage_log_id`),
  KEY `idx_route_vehicle_segments_vehicle_time` (`vehicle_id`,`start_time`),
  KEY `fk_route_vehicle_segments_driver` (`driver_id`),
  CONSTRAINT `fk_route_vehicle_segments_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_route_vehicle_segments_mileage` FOREIGN KEY (`source_mileage_log_id`) REFERENCES `mileage_logs` (`id`),
  CONSTRAINT `fk_route_vehicle_segments_route` FOREIGN KEY (`route_id`) REFERENCES `routes` (`id`),
  CONSTRAINT `fk_route_vehicle_segments_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `routes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `date` date NOT NULL,
  `driver_id` bigint DEFAULT NULL,
  `template_id` bigint DEFAULT NULL,
  `estimated_fuel_cost` double DEFAULT NULL,
  `actual_distance_m` bigint DEFAULT NULL,
  `actual_fuel_liters` decimal(12,3) DEFAULT NULL,
  `actual_fuel_cost` decimal(12,2) DEFAULT NULL,
  `estimated_work_minutes` int DEFAULT NULL,
  `load_rate` double DEFAULT NULL,
  `status` enum('DRAFT','PUBLISHED') NOT NULL,
  `total_distance` double DEFAULT NULL,
  `estimated_fuel_liters` decimal(12,3) DEFAULT NULL,
  `vehicle_id` bigint NOT NULL,
  `version` int NOT NULL,
  `warehouse_id` bigint NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_routes_dispatch_template` (`template_id`),
  CONSTRAINT `fk_routes_dispatch_template` FOREIGN KEY (`template_id`) REFERENCES `dispatch_templates` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `schedule_months` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `schedule_month` date NOT NULL,
  `status` enum('DRAFT','PUBLISHED') NOT NULL DEFAULT 'DRAFT',
  `generated_at` datetime(6) NOT NULL,
  `published_at` datetime(6) DEFAULT NULL,
  `version` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_schedule_months_month` (`schedule_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stores` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `address` varchar(255) DEFAULT NULL,
  `contact_name` varchar(50) DEFAULT NULL,
  `lat` double NOT NULL,
  `lng` double NOT NULL,
  `name` varchar(100) NOT NULL,
  `notes` varchar(500) DEFAULT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `receiving_end` time NOT NULL,
  `receiving_start` time NOT NULL,
  `status` enum('ACTIVE','SUSPENDED') NOT NULL,
  `store_code` varchar(20) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKde7abdc4t7p11hmkx9fw4qa4` (`store_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `template_routes` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `template_id` bigint NOT NULL,
  `warehouse_id` bigint NOT NULL,
  `vehicle_id` bigint DEFAULT NULL,
  `driver_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tpl_routes_tpl_vehicle` (`template_id`,`vehicle_id`),
  UNIQUE KEY `uk_tpl_routes_tpl_driver` (`template_id`,`driver_id`),
  KEY `fk_dispatch_template_routes_warehouse` (`warehouse_id`),
  KEY `fk_dispatch_template_routes_vehicle` (`vehicle_id`),
  KEY `fk_tpl_routes_driver` (`driver_id`),
  CONSTRAINT `fk_dispatch_template_routes_template` FOREIGN KEY (`template_id`) REFERENCES `dispatch_templates` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dispatch_template_routes_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`),
  CONSTRAINT `fk_dispatch_template_routes_warehouse` FOREIGN KEY (`warehouse_id`) REFERENCES `warehouses` (`id`),
  CONSTRAINT `fk_tpl_routes_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `template_stops` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `template_route_id` bigint NOT NULL,
  `store_id` bigint NOT NULL,
  `sequence` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_template_stops` (`template_route_id`,`store_id`),
  KEY `idx_template_stops_seq` (`template_route_id`,`sequence`),
  KEY `fk_dispatch_template_stops_store` (`store_id`),
  CONSTRAINT `fk_dispatch_template_stops_route` FOREIGN KEY (`template_route_id`) REFERENCES `template_routes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dispatch_template_stops_store` FOREIGN KEY (`store_id`) REFERENCES `stores` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vehicle_maintenance_policies` (
  `tonnage` decimal(6,2) NOT NULL,
  `minor_interval_km` int NOT NULL,
  `major_interval_km` int NOT NULL,
  `retirement_km` int NOT NULL,
  PRIMARY KEY (`tonnage`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vehicle_maintenance_records` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `vehicle_id` bigint NOT NULL,
  `type` varchar(10) NOT NULL,
  `status` varchar(12) NOT NULL,
  `sent_at` datetime(6) DEFAULT NULL,
  `sent_odometer_km` int DEFAULT NULL,
  `completed_at` datetime(6) DEFAULT NULL,
  `completed_odometer_km` int DEFAULT NULL,
  `cancelled_at` datetime(6) DEFAULT NULL,
  `recorded_by` varchar(100) DEFAULT NULL,
  `completed_by` varchar(100) DEFAULT NULL,
  `active_vehicle_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_vehicle_maintenance_active_vehicle` (`active_vehicle_id`),
  KEY `idx_vehicle_maintenance_vehicle` (`vehicle_id`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vehicle_maintenance_settings` (
  `id` bigint NOT NULL,
  `warning_km` int NOT NULL DEFAULT '500',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vehicle_replacement_events` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `route_id` bigint NOT NULL,
  `old_vehicle_id` bigint NOT NULL,
  `new_vehicle_id` bigint DEFAULT NULL,
  `driver_id` bigint DEFAULT NULL,
  `old_segment_id` bigint NOT NULL,
  `new_segment_id` bigint DEFAULT NULL,
  `occurred_at` datetime(6) NOT NULL,
  `lat` double DEFAULT NULL,
  `lng` double DEFAULT NULL,
  `reason` varchar(500) NOT NULL,
  `replacement_deadhead_distance_m` bigint DEFAULT NULL,
  `towing_cost` decimal(12,2) DEFAULT NULL,
  `status` enum('PENDING','DISPATCHED','COMPLETED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  `created_by` varchar(50) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `completed_at` datetime(6) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_vehicle_replacement_route_time` (`route_id`,`occurred_at`),
  KEY `fk_vehicle_replacement_old_vehicle` (`old_vehicle_id`),
  KEY `fk_vehicle_replacement_new_vehicle` (`new_vehicle_id`),
  KEY `fk_vehicle_replacement_driver` (`driver_id`),
  KEY `fk_vehicle_replacement_old_segment` (`old_segment_id`),
  KEY `fk_vehicle_replacement_new_segment` (`new_segment_id`),
  CONSTRAINT `fk_vehicle_replacement_driver` FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`),
  CONSTRAINT `fk_vehicle_replacement_new_segment` FOREIGN KEY (`new_segment_id`) REFERENCES `route_vehicle_segments` (`id`),
  CONSTRAINT `fk_vehicle_replacement_new_vehicle` FOREIGN KEY (`new_vehicle_id`) REFERENCES `vehicles` (`id`),
  CONSTRAINT `fk_vehicle_replacement_old_segment` FOREIGN KEY (`old_segment_id`) REFERENCES `route_vehicle_segments` (`id`),
  CONSTRAINT `fk_vehicle_replacement_old_vehicle` FOREIGN KEY (`old_vehicle_id`) REFERENCES `vehicles` (`id`),
  CONSTRAINT `fk_vehicle_replacement_route` FOREIGN KEY (`route_id`) REFERENCES `routes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `vehicles` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `capacity` int NOT NULL,
  `fuel_consumption` double DEFAULT NULL,
  `fuel_type` enum('GASOLINE_92','GASOLINE_95','GASOLINE_98','DIESEL','ELECTRIC','OTHER') DEFAULT NULL,
  `plate_number` varchar(20) NOT NULL,
  `status` enum('AVAILABLE','MAINTENANCE','MINOR_MAINTENANCE','MAJOR_MAINTENANCE','RETIRED') NOT NULL,
  `vehicle_type` varchar(50) DEFAULT NULL,
  `warehouse_id` bigint NOT NULL,
  `cumulative_mileage_km` double NOT NULL DEFAULT '0',
  `current_odometer_km` int DEFAULT NULL,
  `tonnage` decimal(6,2) DEFAULT NULL,
  `last_minor_maintenance_km` int DEFAULT NULL,
  `last_major_maintenance_km` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKh6kd0awsaislk5n2f3ea1hhuq` (`plate_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `warehouses` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `address` varchar(255) DEFAULT NULL,
  `is_active` bit(1) NOT NULL,
  `lat` double NOT NULL,
  `lng` double NOT NULL,
  `name` varchar(100) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `warehouse_code` varchar(20) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK1bidj95gewy1e3q54xbdrxykv` (`warehouse_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
