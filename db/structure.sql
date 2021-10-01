
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `abstract_message_receivers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `abstract_message_receivers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) DEFAULT NULL,
  `message_id` int(11) NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` int(11) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `api_token` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `message_root_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_abstract_message_receivers_on_member_id_and_status` (`member_id`,`status`),
  KEY `index_abstract_message_receivers_on_member_id` (`member_id`),
  KEY `index_abstract_message_receivers_on_message_id` (`message_id`),
  KEY `index_amr_message_root_id_and_message_id` (`message_root_id`,`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `abstract_preferences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `abstract_preferences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `preference_marker_user_id` int(11) NOT NULL,
  `preference_marked_user_id` int(11) NOT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_abstract_preferences_on_preference_marker_user_id` (`preference_marker_user_id`),
  KEY `index_abstract_preferences_on_preference_marked_user_id` (`preference_marked_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `activity_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `activity_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `activity` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_activity_logs_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `admin_view_columns`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_view_columns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `admin_view_id` int(11) DEFAULT NULL,
  `profile_question_id` int(11) DEFAULT NULL,
  `column_key` text COLLATE utf8mb4_unicode_ci,
  `position` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `column_sub_key` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_admin_view_columns_on_admin_view_id` (`admin_view_id`),
  KEY `index_admin_view_columns_on_profile_question_id` (`profile_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `admin_view_user_caches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_view_user_caches` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `admin_view_id` int(11) DEFAULT NULL,
  `user_ids` longtext COLLATE utf8mb4_unicode_ci,
  `last_cached_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_admin_view_user_caches_on_admin_view_id` (`admin_view_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `admin_views`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_views` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `program_id` int(11) NOT NULL,
  `filter_params` text COLLATE utf8mb4_unicode_ci,
  `default_view` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'AdminView',
  `favourite` tinyint(1) DEFAULT '0',
  `favourited_at` datetime DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_admin_views_on_program_id` (`program_id`),
  KEY `index_admin_views_on_role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `announcement_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `announcement_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `announcement_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_announcement_translations_on_announcement_id` (`announcement_id`),
  KEY `index_announcement_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `announcements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `announcements` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `expiration_date` datetime DEFAULT NULL,
  `status` int(11) DEFAULT '0',
  `email_notification` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_announcements_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `answer_choices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `answer_choices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `question_choice_id` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_answer_choices_on_ref_obj_type_and_ref_obj_id` (`ref_obj_type`,`ref_obj_id`),
  KEY `index_answer_choices_on_question_choice_id` (`question_choice_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ar_internal_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ar_internal_metadata` (
  `key` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  `value` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `article_contents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `article_contents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body` longtext COLLATE utf8mb4_unicode_ci,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `embed_code` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` int(11) DEFAULT NULL,
  `published_at` datetime DEFAULT NULL,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `article_list_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `article_list_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `article_content_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_article_list_items_on_article_content_id` (`article_content_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `article_publications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `article_publications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `article_id` int(11) NOT NULL,
  `program_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_article_publications_on_article_id` (`article_id`),
  KEY `index_article_publications_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `articles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `articles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `view_count` int(11) DEFAULT '0',
  `helpful_count` int(11) DEFAULT '0',
  `author_id` int(11) DEFAULT NULL,
  `organization_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `article_content_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `auth_config_setting_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `auth_config_setting_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `auth_config_setting_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `default_section_title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `custom_section_title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `default_section_description` text COLLATE utf8mb4_unicode_ci,
  `custom_section_description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_b34e0ec36dd5fa2b7db847a5ecce4200dbcf1bdd` (`auth_config_setting_id`),
  KEY `index_auth_config_setting_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `auth_config_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `auth_config_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) DEFAULT NULL,
  `show_on_top` int(11) DEFAULT '2',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `auth_config_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `auth_config_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `auth_config_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `password_message` text COLLATE utf8mb4_unicode_ci,
  `title` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_auth_config_translations_on_auth_config_id` (`auth_config_id`),
  KEY `index_auth_config_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `auth_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `auth_configs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) NOT NULL,
  `auth_type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `config` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `regex_string` text COLLATE utf8mb4_unicode_ci,
  `use_email` tinyint(1) DEFAULT '0',
  `logo_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `logo_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `logo_file_size` int(11) DEFAULT NULL,
  `logo_updated_at` datetime DEFAULT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `index_auth_configs_on_organization_id` (`organization_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bulk_matches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bulk_matches` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mentor_view_id` int(11) DEFAULT NULL,
  `mentee_view_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `show_drafted` tinyint(1) DEFAULT '0',
  `show_published` tinyint(1) DEFAULT '0',
  `sort_value` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sort_order` tinyint(1) DEFAULT '1',
  `request_notes` tinyint(1) DEFAULT '1',
  `max_pickable_slots` int(11) DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'BulkMatch',
  `max_suggestion_count` int(11) DEFAULT NULL,
  `default` int(11) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `index_bulk_matches_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `calendar_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calendar_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `slot_time_in_minutes` int(11) DEFAULT NULL,
  `program_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `max_capacity_student_hours` int(11) DEFAULT NULL,
  `max_capacity_student_frequency` int(11) DEFAULT NULL,
  `allow_create_meeting_for_mentor` tinyint(1) DEFAULT '0',
  `advance_booking_time` int(11) DEFAULT '24',
  `allow_mentor_to_configure_availability_slots` tinyint(1) DEFAULT NULL,
  `allow_mentor_to_describe_meeting_preference` tinyint(1) DEFAULT NULL,
  `feedback_survey_delay_not_time_bound` int(11) DEFAULT '15',
  `max_pending_meeting_requests_for_mentee` int(11) DEFAULT '5',
  `max_meetings_for_mentee` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_calendar_settings_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `calendar_sync_error_cases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calendar_sync_error_cases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `scenario` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `details` text COLLATE utf8mb4_unicode_ci,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `calendar_sync_notification_channels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calendar_sync_notification_channels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `channel_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `resource_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_sync_token` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expiration_time` datetime NOT NULL,
  `last_sync_time` datetime DEFAULT NULL,
  `last_notification_received_on` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `scheduling_account_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `calendar_sync_rsvp_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `calendar_sync_rsvp_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `notification_id` int(11) DEFAULT NULL,
  `event_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recurring_event_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rsvp_details` text COLLATE utf8mb4_unicode_ci,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `chr_rake_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `chr_rake_tasks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` text COLLATE utf8mb4_unicode_ci,
  `status` int(11) DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `chronus_docs_app_documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `chronus_docs_app_documents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `description` text COLLATE utf8mb4_unicode_ci,
  `title` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `chronus_versions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `chronus_versions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `item_type` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `item_id` int(11) NOT NULL,
  `event` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `whodunnit` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `object` longtext COLLATE utf8mb4_unicode_ci,
  `object_changes` longtext COLLATE utf8mb4_unicode_ci,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_chronus_versions_on_item_id_and_item_type` (`item_id`,`item_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ckeditor_assets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ckeditor_assets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `data_file_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `data_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `data_file_size` int(11) DEFAULT NULL,
  `type` varchar(25) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `guid` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `locale` tinyint(4) DEFAULT '0',
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `login_required` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_assetable_type` (`type`),
  KEY `fk_program` (`program_id`),
  KEY `index_ckeditor_assets_on_source_audit_key` (`source_audit_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cm_campaign_emails`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cm_campaign_emails` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `campaign_message_id` int(11) NOT NULL,
  `abstract_object_id` int(11) NOT NULL,
  `subject` text COLLATE utf8mb4_unicode_ci,
  `source` text COLLATE utf8mb4_unicode_ci,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_cm_campaign_emails_on_source_audit_key` (`source_audit_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cm_campaign_message_analytics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cm_campaign_message_analytics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `campaign_message_id` int(11) NOT NULL,
  `year_month` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `event_type` int(11) DEFAULT NULL,
  `event_count` int(11) DEFAULT '1',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_campaign_analytics_on_cm_id_and_ym_and_event_type` (`campaign_message_id`,`year_month`,`event_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cm_campaign_message_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cm_campaign_message_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `campaign_message_id` int(11) DEFAULT NULL,
  `abstract_object_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `run_at` datetime DEFAULT NULL,
  `failed` tinyint(1) DEFAULT '0',
  `type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `abstract_object_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `cm_campaign_message_jobs_campaign_message_id_abstract_object_id` (`campaign_message_id`,`abstract_object_id`),
  KEY `cm_campaign_message_jobs_type_absobj_id_cm_id_failed` (`type`,`abstract_object_id`,`campaign_message_id`,`failed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cm_campaign_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cm_campaign_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `campaign_id` int(11) NOT NULL,
  `sender_id` int(11) DEFAULT NULL,
  `duration` int(11) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_jobs_created` tinyint(1) DEFAULT '0',
  `type` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_cm_campaign_messages_on_campaign_id` (`campaign_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cm_campaign_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cm_campaign_statuses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `campaign_id` int(11) DEFAULT NULL,
  `abstract_object_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `started_at` datetime DEFAULT NULL,
  `abstract_object_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `cm_campaign_statuses_type_campaign_id` (`type`,`campaign_id`),
  KEY `cm_campaign_statuses_type_campaign_id_abs_obj_id` (`type`,`campaign_id`,`abstract_object_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cm_campaign_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cm_campaign_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `cm_campaign_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_cm_campaign_translations_on_cm_campaign_id` (`cm_campaign_id`),
  KEY `index_cm_campaign_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cm_campaigns`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cm_campaigns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `state` int(11) NOT NULL DEFAULT '0',
  `trigger_params` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` text COLLATE utf8mb4_unicode_ci,
  `featured` tinyint(1) DEFAULT '0',
  `enabled_at` datetime DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_cm_campaigns_on_program_id` (`program_id`),
  KEY `index_cm_campaigns_on_ref_obj_id` (`ref_obj_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cm_email_event_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cm_email_event_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message_id` int(11) NOT NULL,
  `event_type` int(11) NOT NULL,
  `timestamp` datetime DEFAULT NULL,
  `params` text COLLATE utf8mb4_unicode_ci,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `message_type` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_cm_email_event_logs_on_message_id` (`message_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `coaching_goal_activities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `coaching_goal_activities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `coaching_goal_id` int(11) NOT NULL,
  `progress_value` float DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_coaching_goal_activities_on_coaching_goal_id` (`coaching_goal_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `coaching_goals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `coaching_goals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `due_date` date DEFAULT NULL,
  `group_id` int(11) NOT NULL,
  `connection_membership_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_coaching_goals_on_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `comments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `article_publication_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `body` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_comments_on_article_publication_id` (`article_publication_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `common_answers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `common_answers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `common_question_id` int(11) DEFAULT NULL,
  `answer_text` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `feedback_response_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `survey_id` int(11) DEFAULT NULL,
  `task_id` int(11) DEFAULT NULL,
  `response_id` int(11) DEFAULT NULL,
  `member_meeting_id` int(11) DEFAULT NULL,
  `meeting_occurrence_time` datetime DEFAULT NULL,
  `last_answered_at` datetime DEFAULT NULL,
  `is_draft` tinyint(1) DEFAULT '0',
  `connection_membership_role_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_common_answers_on_common_question_id` (`common_question_id`),
  KEY `index_common_answers_on_feedback_response_id` (`feedback_response_id`),
  KEY `index_common_answers_on_group_id` (`group_id`),
  KEY `index_common_answers_on_user_id` (`user_id`),
  KEY `index_common_answers_on_task_id` (`task_id`),
  KEY `index_common_answers_on_type_and_response_id` (`type`,`response_id`),
  KEY `index_common_answers_on_survey_id_and_type` (`survey_id`,`type`),
  KEY `index_common_answers_on_member_meeting_id_and_occurrence_time` (`member_meeting_id`,`meeting_occurrence_time`),
  KEY `index_common_answers_on_is_draft` (`is_draft`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `common_question_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `common_question_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `common_question_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `question_text` text COLLATE utf8mb4_unicode_ci,
  `help_text` text COLLATE utf8mb4_unicode_ci,
  `question_info` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_common_question_translations_on_common_question_id` (`common_question_id`),
  KEY `index_common_question_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `common_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `common_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `question_type` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `required` tinyint(1) NOT NULL DEFAULT '0',
  `type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `survey_id` int(11) DEFAULT NULL,
  `common_answers_count` int(11) DEFAULT '0',
  `feedback_form_id` int(11) DEFAULT NULL,
  `allow_other_option` tinyint(1) DEFAULT '0',
  `is_admin_only` tinyint(1) DEFAULT NULL,
  `question_mode` int(11) DEFAULT NULL,
  `positive_outcome_options` text COLLATE utf8mb4_unicode_ci,
  `matrix_position` int(11) DEFAULT NULL,
  `matrix_setting` int(11) DEFAULT NULL,
  `matrix_question_id` int(11) DEFAULT NULL,
  `condition` int(11) DEFAULT '0',
  `positive_outcome_options_management_report` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_common_questions_on_common_answers_count` (`common_answers_count`),
  KEY `index_common_questions_on_feedback_form_id` (`feedback_form_id`),
  KEY `index_common_questions_on_program_id_and_type_and_position` (`program_id`,`type`,`position`),
  KEY `index_common_questions_on_survey_id_and_type` (`survey_id`,`type`),
  KEY `index_common_questions_on_matrix_question_id` (`matrix_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `conditional_match_choices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `conditional_match_choices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `question_choice_id` int(11) DEFAULT NULL,
  `profile_question_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_conditional_match_choices_on_question_choice_id` (`question_choice_id`),
  KEY `index_conditional_match_choices_on_profile_question_id` (`profile_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `confidentiality_audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `confidentiality_audit_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci,
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `connection_activities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `connection_activities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) NOT NULL,
  `recent_activity_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_connection_activities_on_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `connection_membership_state_changes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `connection_membership_state_changes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `connection_membership_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `info` text COLLATE utf8mb4_unicode_ci,
  `date_id` int(11) DEFAULT NULL,
  `date_time` datetime DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_membership_state_change_on_membership_id` (`connection_membership_id`),
  KEY `index_connection_membership_state_changes_on_group_id` (`group_id`),
  KEY `index_connection_membership_state_changes_on_user_id` (`user_id`),
  KEY `index_connection_membership_state_changes_on_date_id` (`date_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `connection_memberships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `connection_memberships` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` int(11) NOT NULL DEFAULT '0',
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_status_update_at` datetime DEFAULT NULL,
  `api_token` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `login_count` int(11) DEFAULT '0',
  `role_id` int(11) DEFAULT NULL,
  `owner` tinyint(1) DEFAULT '0',
  `last_visited_tab` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_applied_task_filter` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_connection_memberships_on_api_token` (`api_token`),
  KEY `index_group_students_on_group_id` (`group_id`),
  KEY `index_group_students_on_student_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `connection_private_notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `connection_private_notes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `text` text COLLATE utf8mb4_unicode_ci,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_connection_private_notes_on_created_at` (`created_at`),
  KEY `index_connection_private_notes_on_ref_obj` (`ref_obj_id`,`type`),
  KEY `index_connection_private_notes_on_ref_obj_id` (`ref_obj_id`),
  KEY `index_connection_private_notes_on_type` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `contact_admin_setting_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `contact_admin_setting_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `contact_admin_setting_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `label_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_cd432a2d3455683e275caf13310a0400a6c1a272` (`contact_admin_setting_id`),
  KEY `index_contact_admin_setting_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `contact_admin_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `contact_admin_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `contact_url` text COLLATE utf8mb4_unicode_ci,
  `program_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_contact_admin_settings_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `cron_runner_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cron_runner_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `cron_name` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_cron_runner_logs_on_cron_name` (`cron_name`),
  KEY `index_cron_runner_logs_on_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `customized_term_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `customized_term_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `customized_term_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `term` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `term_downcase` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pluralized_term` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pluralized_term_downcase` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `articleized_term` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `articleized_term_downcase` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_customized_term_translations_on_customized_term_id` (`customized_term_id`),
  KEY `index_customized_term_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `customized_terms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `customized_terms` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_id` int(11) NOT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `term_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_customized_terms_on_ref_obj_id_and_ref_obj_type` (`ref_obj_id`,`ref_obj_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `dashboard_report_sub_sections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `dashboard_report_sub_sections` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `report_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `setting` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_dashboard_report_sub_sections_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `data_imports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `data_imports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) DEFAULT NULL,
  `status` int(11) DEFAULT NULL,
  `failure_message` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_count` int(11) DEFAULT NULL,
  `updated_count` int(11) DEFAULT NULL,
  `suspended_count` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `source_file_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_file_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_file_file_size` int(11) DEFAULT NULL,
  `source_file_updated_at` datetime DEFAULT NULL,
  `log_file_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `log_file_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `log_file_file_size` int(11) DEFAULT NULL,
  `log_file_updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `delayed_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `delayed_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `priority` int(11) DEFAULT '0',
  `attempts` int(11) DEFAULT '0',
  `handler` longtext COLLATE utf8mb4_unicode_ci,
  `last_error` text COLLATE utf8mb4_unicode_ci,
  `run_at` datetime DEFAULT NULL,
  `locked_at` datetime DEFAULT NULL,
  `failed_at` datetime DEFAULT NULL,
  `locked_by` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_priority` int(11) DEFAULT NULL,
  `organization_id` int(11) DEFAULT NULL,
  `queue` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `job_group_id` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_delayed_jobs_on_queue` (`queue`),
  KEY `index_delayed_jobs_on_job_group_id` (`job_group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `educations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `educations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `school_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `degree` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `major` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `graduation_year` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profile_answer_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_educations_on_degree` (`degree`),
  KEY `index_educations_on_profile_answer_id` (`profile_answer_id`),
  KEY `index_educations_on_school_name` (`school_name`),
  KEY `index_educations_on_major` (`major`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `event_invites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `event_invites` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `status` int(11) DEFAULT NULL,
  `reminder` tinyint(1) DEFAULT '0',
  `program_event_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `reminder_sent_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_event_invites_on_user_id` (`user_id`),
  KEY `index_event_invites_on_program_event_id` (`program_event_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `experiences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `experiences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `job_title` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `start_year` int(11) DEFAULT NULL,
  `end_year` int(11) DEFAULT NULL,
  `company` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `start_month` int(11) DEFAULT '0',
  `end_month` int(11) DEFAULT '0',
  `current_job` tinyint(1) DEFAULT '0',
  `profile_answer_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_experiences_on_profile_answer_id` (`profile_answer_id`),
  KEY `index_experiences_on_job_title` (`job_title`),
  KEY `index_experiences_on_company` (`company`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `facilitation_delivery_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `facilitation_delivery_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `facilitation_delivery_loggable_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `last_delivered_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `facilitation_delivery_loggable_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `features`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `features` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `feed_exporter_configurations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `feed_exporter_configurations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `feed_exporter_id` int(11) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT '0',
  `configuration_options` text COLLATE utf8mb4_unicode_ci,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `feed_exporters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `feed_exporters` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `frequency` float DEFAULT '1',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sftp_account_name` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `feed_import_configurations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `feed_import_configurations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) DEFAULT NULL,
  `sftp_user_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `frequency` int(11) DEFAULT NULL,
  `configuration_options` text COLLATE utf8mb4_unicode_ci,
  `source_options` text COLLATE utf8mb4_unicode_ci,
  `enabled` tinyint(1) DEFAULT '0',
  `preprocessor` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `feedback_forms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `feedback_forms` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `form_type` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_feedback_forms_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `feedback_responses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `feedback_responses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `feedback_form_id` int(11) NOT NULL,
  `group_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `recipient_id` int(11) DEFAULT NULL,
  `rating` float DEFAULT '0.5',
  PRIMARY KEY (`id`),
  KEY `index_feedback_responses_on_feedback_form_id` (`feedback_form_id`),
  KEY `index_feedback_responses_on_group_id` (`group_id`),
  KEY `index_feedback_responses_on_user_id` (`user_id`),
  KEY `index_feedback_responses_on_recipient_id` (`recipient_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `flags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `content_id` int(11) DEFAULT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci,
  `user_id` int(11) DEFAULT NULL,
  `resolver_id` int(11) DEFAULT NULL,
  `resolved_at` datetime DEFAULT NULL,
  `status` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `forums`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `forums` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `topics_count` int(11) DEFAULT '0',
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_forums_on_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `group_checkins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_checkins` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `comment` text COLLATE utf8mb4_unicode_ci,
  `checkin_ref_obj_id` int(11) DEFAULT NULL,
  `checkin_ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `duration` int(11) DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `group_id` int(11) DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_group_checkins_on_checkin_ref_obj_id` (`checkin_ref_obj_id`),
  KEY `index_group_checkins_on_checkin_ref_obj_type` (`checkin_ref_obj_type`),
  KEY `index_group_checkins_on_program_id` (`program_id`),
  KEY `index_group_checkins_on_user_id` (`user_id`),
  KEY `index_group_checkins_on_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `group_closure_reason_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_closure_reason_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `group_closure_reason_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_b1f8d1b118866e9372a294c1539af9336686ce69` (`group_closure_reason_id`),
  KEY `index_group_closure_reason_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `group_closure_reasons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_closure_reasons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `is_deleted` tinyint(1) DEFAULT '0',
  `is_completed` tinyint(1) DEFAULT '0',
  `is_default` tinyint(1) DEFAULT '0',
  `program_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_group_closure_reasons_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `group_membership_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_membership_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) NOT NULL,
  `role_id` int(11) NOT NULL,
  `max_limit` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `allow_join` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_group_membership_settings_on_group_id` (`group_id`),
  KEY `index_group_membership_settings_on_role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `group_state_changes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_state_changes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) DEFAULT NULL,
  `from_state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `to_state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `date_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_group_state_changes_on_group_id` (`group_id`),
  KEY `index_group_state_changes_on_date_id` (`date_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `group_view_columns`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_view_columns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group_view_id` int(11) DEFAULT NULL,
  `profile_question_id` int(11) DEFAULT NULL,
  `column_key` text COLLATE utf8mb4_unicode_ci,
  `position` int(11) DEFAULT NULL,
  `connection_question_id` int(11) DEFAULT NULL,
  `ref_obj_type` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `role_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_group_view_columns_on_group_view_id` (`group_view_id`),
  KEY `index_group_view_columns_on_profile_question_id` (`profile_question_id`),
  KEY `index_group_view_columns_on_connection_question_id` (`connection_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `group_views`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `group_views` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_group_views_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` int(11) DEFAULT '0',
  `termination_reason` text COLLATE utf8mb4_unicode_ci,
  `terminator_id` int(11) DEFAULT NULL,
  `closed_at` datetime DEFAULT NULL,
  `expiry_time` datetime DEFAULT NULL,
  `termination_mode` int(11) DEFAULT NULL,
  `last_activity_at` datetime DEFAULT NULL,
  `logo_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `logo_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `logo_file_size` int(11) DEFAULT NULL,
  `logo_updated_at` datetime DEFAULT NULL,
  `global` tinyint(1) DEFAULT '0',
  `last_member_activity_at` datetime DEFAULT NULL,
  `published_at` datetime DEFAULT NULL,
  `creator_id` int(11) DEFAULT NULL,
  `bulk_match_id` int(11) DEFAULT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `mentoring_model_id` int(11) DEFAULT NULL,
  `pending_at` datetime DEFAULT NULL,
  `version` int(11) DEFAULT '1',
  `closure_reason_id` int(11) DEFAULT NULL,
  `start_date` datetime DEFAULT NULL,
  `auto_publish_failure_mail_sent_time` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_groups_on_global` (`global`),
  KEY `index_groups_on_last_activity_at` (`last_activity_at`),
  KEY `index_groups_on_last_member_activity_at` (`last_member_activity_at`),
  KEY `index_groups_on_name` (`name`),
  KEY `index_groups_on_mentoring_model_id` (`mentoring_model_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `instruction_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `instruction_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `instruction_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_instruction_translations_on_instruction_id` (`instruction_id`),
  KEY `index_instruction_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `instructions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `instructions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `job_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `job_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_id` int(11) DEFAULT NULL,
  `loggable_object_id` int(11) DEFAULT NULL,
  `loggable_object_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `action_type` int(11) DEFAULT NULL,
  `version_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `job_uuid` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_job_logs_on_loggable_object_type_and_loggable_object_id` (`loggable_object_type`,`loggable_object_id`),
  KEY `index_job_logs_on_ref_obj_type_and_ref_obj_id` (`ref_obj_type`,`ref_obj_id`),
  KEY `index_job_logs_on_job_uuid` (`job_uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `languages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `languages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `display_title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `language_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `location_lookups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `location_lookups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `address_text` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_location_lookups_on_location_id` (`location_id`),
  KEY `index_location_lookups_on_address_text` (`address_text`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `city` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `state` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `country` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lat` float DEFAULT NULL,
  `lng` float DEFAULT NULL,
  `full_address` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci DEFAULT NULL,
  `reliable` tinyint(1) DEFAULT '0',
  `user_answers_count` int(11) DEFAULT '0',
  `profile_answers_count` int(11) DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cleanup_status` int(11) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_locations_on_profile_answers_count` (`profile_answers_count`),
  KEY `index_locations_on_user_answers_count` (`user_answers_count`),
  KEY `index_locations_on_city` (`city`),
  KEY `index_locations_on_state` (`state`),
  KEY `index_locations_on_country` (`country`),
  KEY `index_locations_on_city_and_state_and_country` (`city`,`state`,`country`),
  KEY `index_locations_on_state_and_country` (`state`,`country`),
  KEY `index_locations_on_full_address` (`full_address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `login_identifiers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `login_identifiers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) DEFAULT NULL,
  `auth_config_id` int(11) DEFAULT NULL,
  `identifier` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_login_identifiers_on_member_id` (`member_id`),
  KEY `index_login_identifiers_on_auth_config_id` (`auth_config_id`),
  KEY `index_login_identifiers_on_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `login_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `login_tokens` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `member_id` bigint(20) DEFAULT NULL,
  `token_code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_used_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_login_tokens_on_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mailer_template_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mailer_template_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mailer_template_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `subject` text COLLATE utf8mb4_unicode_ci,
  `source` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_mailer_template_translations_on_mailer_template_id` (`mailer_template_id`),
  KEY `index_mailer_template_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mailer_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mailer_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `uid` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT '1',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `campaign_message_id` int(11) DEFAULT NULL,
  `copied_content` int(11) DEFAULT NULL,
  `content_changer_member_id` int(11) DEFAULT NULL,
  `content_updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mailer_templates_on_campaign_message_id` (`campaign_message_id`),
  KEY `index_mailer_templates_on_content_changer_member_id` (`content_changer_member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mailer_widget_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mailer_widget_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mailer_widget_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `source` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_mailer_widget_translations_on_mailer_widget_id` (`mailer_widget_id`),
  KEY `index_mailer_widget_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mailer_widgets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mailer_widgets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `uid` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `managers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `managers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `first_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profile_answer_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `member_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_managers_on_profile_answer_id` (`profile_answer_id`),
  KEY `index_managers_on_member_id` (`member_id`),
  KEY `index_managers_on_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `match_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `match_configs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mentor_question_id` int(11) DEFAULT NULL,
  `student_question_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `weight` float NOT NULL DEFAULT '1',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `threshold` float DEFAULT '0',
  `operator` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'lt',
  `matching_type` int(11) DEFAULT '0',
  `matching_details_for_display` text COLLATE utf8mb4_unicode_ci,
  `matching_details_for_matching` text COLLATE utf8mb4_unicode_ci,
  `show_match_label` tinyint(1) NOT NULL DEFAULT '0',
  `prefix` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_match_configs_on_program_id` (`program_id`),
  KEY `index_match_configs_on_student_question_id` (`student_question_id`),
  KEY `index_match_configs_on_mentor_question_id` (`mentor_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `matching_documents`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `matching_documents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `record_id` int(11) DEFAULT NULL,
  `mentor` tinyint(1) DEFAULT NULL,
  `data_fields` json DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_on_program_id` (`program_id`),
  KEY `index_on_program_id_and_is_mentor_and_record_id` (`program_id`,`mentor`,`record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `meeting_proposed_slots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meeting_proposed_slots` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `meeting_request_id` int(11) NOT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `location` text COLLATE utf8mb4_unicode_ci,
  `proposer_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_meeting_proposed_slots_on_meeting_request_id` (`meeting_request_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `meetings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `meetings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `group_id` int(11) DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `topic` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `location` text COLLATE utf8mb4_unicode_ci,
  `owner_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `program_id` int(11) NOT NULL,
  `ics_sequence` int(11) DEFAULT '0',
  `meeting_request_id` int(11) DEFAULT NULL,
  `calendar_time_available` tinyint(1) DEFAULT '1',
  `active` tinyint(1) DEFAULT '1',
  `schedule` text COLLATE utf8mb4_unicode_ci,
  `recurrent` tinyint(1) DEFAULT '0',
  `state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mentee_id` int(11) DEFAULT NULL,
  `state_marked_at` datetime DEFAULT NULL,
  `calendar_event_id` varchar(1024) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `scheduling_email` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `time_zone` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_meetings_on_group_id` (`group_id`),
  KEY `index_meetings_on_program_id` (`program_id`),
  KEY `index_meetings_on_start_time` (`start_time`),
  KEY `index_meetings_on_meeting_request_id` (`meeting_request_id`),
  KEY `index_meetings_on_mentee_id` (`mentee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `member_languages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `member_languages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) NOT NULL,
  `language_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_member_languages_on_member_id` (`member_id`),
  KEY `index_member_languages_on_language_id` (`language_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `member_meeting_responses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `member_meeting_responses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `meeting_occurrence_time` datetime DEFAULT NULL,
  `member_meeting_id` int(11) DEFAULT NULL,
  `attending` int(11) DEFAULT '2',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `rsvp_change_source` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_member_meeting_responses_on_member_meeting_id` (`member_meeting_id`),
  KEY `index_member_meeting_responses_on_meeting_occurrence_time` (`meeting_occurrence_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `member_meetings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `member_meetings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) NOT NULL,
  `meeting_id` int(11) NOT NULL,
  `attending` int(11) DEFAULT '2',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reminder_time` datetime DEFAULT NULL,
  `reminder_sent` tinyint(1) DEFAULT '0',
  `feedback_request_sent` tinyint(1) DEFAULT '0',
  `feedback_request_sent_time` datetime DEFAULT NULL,
  `api_token` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rsvp_change_source` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_member_meetings_on_meeting_id` (`meeting_id`),
  KEY `index_member_meetings_on_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) NOT NULL,
  `admin` tinyint(1) DEFAULT '0',
  `state` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `crypted_password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remember_token` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `remember_token_expires_at` datetime DEFAULT NULL,
  `salt` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `time_zone` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `first_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `api_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT '',
  `calendar_api_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `failed_login_attempts` int(11) DEFAULT '0',
  `imported_at` datetime DEFAULT NULL,
  `account_locked_at` datetime DEFAULT NULL,
  `password_updated_at` datetime DEFAULT NULL,
  `will_set_availability_slots` tinyint(1) DEFAULT '0',
  `availability_not_set_message` text COLLATE utf8mb4_unicode_ci,
  `terms_and_conditions_accepted` datetime DEFAULT NULL,
  `browser_warning_shown_at` datetime DEFAULT NULL,
  `calendar_sync_count` int(11) DEFAULT '0',
  `encryption_type` varchar(25) COLLATE utf8mb4_unicode_ci DEFAULT 'sha2',
  `linkedin_access_token` text COLLATE utf8mb4_unicode_ci,
  `last_suspended_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_members_on_api_key_and_organization_id` (`api_key`,`organization_id`),
  KEY `index_members_on_calendar_api_key_and_organization_id` (`calendar_api_key`,`organization_id`),
  KEY `index_members_on_email` (`email`),
  KEY `index_members_on_chronus_user_id_and_organization_id` (`organization_id`),
  KEY `index_members_on_source_audit_key` (`source_audit_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `membership_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `membership_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` smallint(6) DEFAULT '0',
  `response_text` text COLLATE utf8mb4_unicode_ci,
  `admin_id` int(11) DEFAULT NULL,
  `accepted_as` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `response_subject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `first_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `joined_directly` tinyint(1) DEFAULT '0',
  `member_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mem_req_on_prog_id_status_created_at` (`program_id`,`status`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentor_offers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentor_offers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `mentor_id` int(11) DEFAULT NULL,
  `student_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  `response` text COLLATE utf8mb4_unicode_ci,
  `status` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `closed_by_id` int(11) DEFAULT NULL,
  `closed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentor_offers_on_mentor_id_and_status` (`mentor_id`,`status`),
  KEY `index_mentor_offers_on_student_id_and_status` (`student_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentor_recommendations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentor_recommendations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `status` int(11) DEFAULT NULL,
  `sender_id` int(11) DEFAULT NULL,
  `receiver_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentor_recommendations_on_program_id` (`program_id`),
  KEY `index_mentor_recommendations_on_sender_id` (`sender_id`),
  KEY `index_mentor_recommendations_on_receiver_id` (`receiver_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentor_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentor_requests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` int(11) DEFAULT '0',
  `sender_id` int(11) DEFAULT NULL,
  `receiver_id` int(11) DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  `response_text` text COLLATE utf8mb4_unicode_ci,
  `group_id` int(11) DEFAULT NULL,
  `show_in_profile` tinyint(1) DEFAULT '1',
  `type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT 'MentorRequest',
  `closed_by_id` int(11) DEFAULT NULL,
  `closed_at` datetime DEFAULT NULL,
  `sender_role_id` int(11) DEFAULT NULL,
  `reminder_sent_time` datetime DEFAULT NULL,
  `accepted_at` datetime DEFAULT NULL,
  `acceptance_message` text COLLATE utf8mb4_unicode_ci,
  `rejection_type` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentor_requests_on_program_id_and_status` (`program_id`,`status`),
  KEY `index_mentor_requests_on_sender_id_and_type` (`sender_id`,`type`),
  KEY `index_mentor_requests_on_receiver_id_and_type` (`receiver_id`,`type`),
  KEY `index_mentor_requests_on_sender_role_id` (`sender_role_id`),
  KEY `index_mentor_requests_on_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_activities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_activities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `progress_value` float DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  `connection_membership_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `member_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_activities_on_ref_obj_id_and_ref_obj_type` (`ref_obj_id`,`ref_obj_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_facilitation_template_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_facilitation_template_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mentoring_model_facilitation_template_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_92ebb01901c49a7d43d1a795068fcd5422edf5f7` (`mentoring_model_facilitation_template_id`),
  KEY `index_aa164b4c20ca2ce5af1f067d7a489aa5d935ea16` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_facilitation_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_facilitation_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `send_on` int(11) DEFAULT NULL,
  `mentoring_model_id` int(11) DEFAULT NULL,
  `milestone_template_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `specific_date` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_facilitation_templates_on_milestone_template_id` (`milestone_template_id`),
  KEY `mentoring_model_facilitation_templates_on_mentoring_model_id` (`mentoring_model_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_goal_template_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_goal_template_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mentoring_model_goal_template_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_a8d0cfc98e0cb211edfab4dbe3550db0d748ad9a` (`mentoring_model_goal_template_id`),
  KEY `index_mentoring_model_goal_template_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_goal_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_goal_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mentoring_model_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `mentoring_model_goal_templates_on_mentoring_model_id` (`mentoring_model_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_goal_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_goal_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mentoring_model_goal_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_d6fc63b82ba381b00d7db730a8170ffdf61c2d29` (`mentoring_model_goal_id`),
  KEY `index_mentoring_model_goal_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_goals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_goals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `from_template` tinyint(1) DEFAULT '0',
  `group_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `mentoring_model_goal_template_id` int(11) DEFAULT NULL,
  `template_version` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_goals_on_group_id` (`group_id`),
  KEY `index_mentoring_model_goals_on_mentoring_model_goal_template_id` (`mentoring_model_goal_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_links`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_links` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `child_template_id` int(11) DEFAULT NULL,
  `parent_template_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_links_on_child_template_id` (`child_template_id`),
  KEY `index_mentoring_model_links_on_parent_template_id` (`parent_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_milestone_template_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_milestone_template_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mentoring_model_milestone_template_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_baf317c01a59858928373b38948a69a135c2f720` (`mentoring_model_milestone_template_id`),
  KEY `index_mentoring_model_milestone_template_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_milestone_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_milestone_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mentoring_model_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `position` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `mentoring_model_milestone_templates_on_mentoring_model_id` (`mentoring_model_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_milestone_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_milestone_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mentoring_model_milestone_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_6d5772998debfa931355b3a20459c2c58cb93357` (`mentoring_model_milestone_id`),
  KEY `index_mentoring_model_milestone_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_milestones`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_milestones` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `from_template` tinyint(1) DEFAULT '0',
  `group_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `mentoring_model_milestone_template_id` int(11) DEFAULT NULL,
  `template_version` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_milestones_on_group_id` (`group_id`),
  KEY `index_mentoring_model_milestones_on_milestone_template_id` (`mentoring_model_milestone_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_task_comment_scraps`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_task_comment_scraps` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mentoring_model_task_comment_id` int(11) DEFAULT NULL,
  `scrap_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_task_comment_scrap_on_comment_id` (`mentoring_model_task_comment_id`),
  KEY `index_mentoring_model_task_comment_scraps_on_scrap_id` (`scrap_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_task_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_task_comments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `sender_id` int(11) DEFAULT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `mentoring_model_task_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_task_comments_on_mentoring_model_task_id` (`mentoring_model_task_id`),
  KEY `index_mentoring_model_task_comments_on_program_id` (`program_id`),
  KEY `index_mentoring_model_task_comments_on_sender_id` (`sender_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_task_template_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_task_template_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mentoring_model_task_template_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_b66345c65f50f257bc05c277be5d60964bc13841` (`mentoring_model_task_template_id`),
  KEY `index_mentoring_model_task_template_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_task_templates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_task_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mentoring_model_id` int(11) DEFAULT NULL,
  `milestone_template_id` int(11) DEFAULT NULL,
  `goal_template_id` int(11) DEFAULT NULL,
  `required` tinyint(1) DEFAULT '0',
  `duration` int(11) DEFAULT NULL,
  `associated_id` int(11) DEFAULT NULL,
  `action_item_type` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `specific_date` datetime DEFAULT NULL,
  `action_item_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_task_templates_on_milestone_template_id` (`milestone_template_id`),
  KEY `index_mentoring_model_task_templates_on_goal_template_id` (`goal_template_id`),
  KEY `index_mentoring_model_task_templates_on_role_id` (`role_id`),
  KEY `index_mentoring_model_task_templates_on_associated_id` (`associated_id`),
  KEY `mentoring_model_task_templates_on_mentoring_model_id` (`mentoring_model_id`),
  KEY `index_mentoring_model_task_templates_on_action_item` (`action_item_type`,`action_item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_task_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_task_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mentoring_model_task_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_ec8d5a7ea2ebc48b2e61860ab36fe70f4e0cb1df` (`mentoring_model_task_id`),
  KEY `index_mentoring_model_task_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_tasks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_tasks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `connection_membership_id` int(11) DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `milestone_id` int(11) DEFAULT NULL,
  `goal_id` int(11) DEFAULT NULL,
  `required` tinyint(1) DEFAULT NULL,
  `due_date` datetime DEFAULT NULL,
  `status` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `action_item_type` int(11) DEFAULT NULL,
  `from_template` tinyint(1) DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `completed_date` date DEFAULT NULL,
  `mentoring_model_task_template_id` int(11) DEFAULT NULL,
  `action_item_id` int(11) DEFAULT NULL,
  `unassigned_from_template` tinyint(1) DEFAULT '0',
  `due_date_altered` tinyint(1) DEFAULT NULL,
  `completed_by` int(11) DEFAULT NULL,
  `template_version` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_tasks_on_connection_membership_id` (`connection_membership_id`),
  KEY `index_mentoring_model_tasks_on_goal_id` (`goal_id`),
  KEY `index_mentoring_model_tasks_on_milestone_id` (`milestone_id`),
  KEY `index_mentoring_model_tasks_on_mentoring_model_task_template_id` (`mentoring_model_task_template_id`),
  KEY `index_mentoring_model_tasks_on_group_id_and_status` (`group_id`,`status`),
  KEY `index_mentoring_model_tasks_on_action_item` (`action_item_type`,`action_item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_model_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_model_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `mentoring_model_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `forum_help_text` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_mentoring_model_translations_on_mentoring_model_id` (`mentoring_model_id`),
  KEY `index_mentoring_model_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_models`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_models` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `default` tinyint(1) DEFAULT '0',
  `program_id` int(11) DEFAULT NULL,
  `mentoring_period` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `version` int(11) DEFAULT '1',
  `should_sync` tinyint(1) DEFAULT NULL,
  `mentoring_model_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'base',
  `allow_due_date_edit` tinyint(1) DEFAULT '0',
  `goal_progress_type` int(11) DEFAULT '0',
  `allow_messaging` tinyint(1) NOT NULL DEFAULT '1',
  `allow_forum` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_mentoring_models_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_slots`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_slots` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `location` text COLLATE utf8mb4_unicode_ci,
  `repeats` int(11) DEFAULT NULL,
  `member_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `repeats_end_date` date DEFAULT NULL,
  `repeats_on_week` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `repeats_by_month_date` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `index_mentoring_slots_on_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mentoring_tips`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mentoring_tips` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message` text COLLATE utf8mb4_unicode_ci,
  `enabled` tinyint(1) DEFAULT '1',
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `sender_id` int(11) DEFAULT NULL,
  `sender_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sender_email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `group_id` int(11) DEFAULT NULL,
  `parent_id` int(11) DEFAULT NULL,
  `type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `auto_email` tinyint(1) DEFAULT '0',
  `root_id` int(11) NOT NULL DEFAULT '0',
  `posted_via_email` tinyint(1) DEFAULT '0',
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `campaign_message_id` int(11) DEFAULT NULL,
  `context_program_id` int(11) DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_messages_on_parent_id` (`parent_id`),
  KEY `index_messages_on_group_id` (`group_id`),
  KEY `index_messages_on_root_id_and_id` (`root_id`,`id`),
  KEY `index_messages_on_program_id_and_type_and_created_at` (`program_id`,`type`,`created_at`),
  KEY `index_messages_on_sender_id_and_group_id` (`sender_id`,`group_id`),
  KEY `index_messages_on_campaign_message_id` (`campaign_message_id`),
  KEY `index_messages_on_created_at` (`created_at`),
  KEY `index_message_on_ref_obj` (`ref_obj_id`,`ref_obj_type`),
  KEY `index_messages_on_source_audit_key` (`source_audit_key`),
  KEY `index_messages_on_sender_id_and_auto_email` (`sender_id`,`auto_email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `mobile_devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mobile_devices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) DEFAULT NULL,
  `device_token` text COLLATE utf8mb4_unicode_ci,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `mobile_auth_token` text COLLATE utf8mb4_unicode_ci,
  `badge_count` int(11) DEFAULT '0',
  `platform` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_mobile_devices_on_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `moderatorships`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `moderatorships` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `forum_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_moderatorships_on_forum_id` (`forum_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `notification_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notification_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `messages_notification` int(11) DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `o_auth_credentials`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `o_auth_credentials` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `access_token` text COLLATE utf8mb4_unicode_ci,
  `refresh_token` text COLLATE utf8mb4_unicode_ci,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ref_obj_id` (`ref_obj_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `object_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `object_permissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `object_role_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `object_role_permissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  `object_permission_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_object_role_permissions_on_ref_obj` (`ref_obj_id`,`ref_obj_type`),
  KEY `index_object_role_permissions_on_role_id` (`role_id`),
  KEY `index_object_role_permissions_on_object_permission_id` (`object_permission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `one_time_flags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `one_time_flags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message_tag` text COLLATE utf8mb4_unicode_ci,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `ref_obj_id` int(11) NOT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_one_time_flags_on_ref_obj_type` (`ref_obj_type`),
  KEY `index_one_time_flags_on_ref_obj_id` (`ref_obj_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `organization_features`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `organization_features` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) DEFAULT NULL,
  `feature_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `index_features_on_program_id` (`organization_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `organization_languages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `organization_languages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `enabled` int(11) DEFAULT '0',
  `language_id` int(11) NOT NULL,
  `organization_id` int(11) NOT NULL,
  `default` tinyint(1) NOT NULL DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `display_title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `language_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_organization_languages_on_language_id` (`language_id`),
  KEY `index_organization_languages_on_organization_id` (`organization_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `page_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `page_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `page_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `content` longtext COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_page_translations_on_page_id` (`page_id`),
  KEY `index_page_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `visibility` int(11) DEFAULT '0',
  `use_in_sub_programs` tinyint(1) DEFAULT '0',
  `published` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `passwords`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `passwords` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reset_code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expiration_date` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `member_id` int(11) DEFAULT NULL,
  `email_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `pending_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `pending_notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_creator_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `action_type` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `initiator_id` int(11) DEFAULT NULL,
  `ref_obj_creator_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_pending_notification_on_creator_type_and_id` (`ref_obj_creator_type`,`ref_obj_creator_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `permissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_permissions_on_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `posts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `topic_id` int(11) DEFAULT NULL,
  `body` longtext COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `ancestry` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `published` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `index_posts_on_ancestry` (`ancestry`),
  KEY `index_posts_on_forum_id` (`created_at`),
  KEY `index_posts_on_topic_id` (`topic_id`,`created_at`),
  KEY `index_posts_on_user_id` (`user_id`,`created_at`),
  KEY `index_posts_on_published` (`published`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `profile_answers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `profile_answers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `profile_question_id` int(11) DEFAULT NULL,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `answer_text` text COLLATE utf8mb4_unicode_ci,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_id` int(11) NOT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `processed` tinyint(1) DEFAULT '0',
  `zencoder_output_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `not_applicable` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_profile_answers_on_location_id` (`location_id`),
  KEY `index_profile_answers_on_ref_obj_type_and_ref_obj_id` (`ref_obj_type`,`ref_obj_id`),
  KEY `index_profile_answers_on_ref_obj_type` (`ref_obj_type`),
  KEY `index_profile_answers_on_ref_obj_id` (`ref_obj_id`),
  KEY `index_profile_answers_on_ref_obj_type_and_profile_question_id` (`ref_obj_type`,`profile_question_id`),
  KEY `index_profile_answers_on_profile_question_id` (`profile_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `profile_pictures`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `profile_pictures` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `image_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `image_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `image_file_size` int(11) DEFAULT NULL,
  `image_updated_at` datetime DEFAULT NULL,
  `image_remote_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `member_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `not_applicable` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_profile_pictures_on_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `profile_question_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `profile_question_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `profile_question_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `question_text` text COLLATE utf8mb4_unicode_ci,
  `help_text` text COLLATE utf8mb4_unicode_ci,
  `question_info` text COLLATE utf8mb4_unicode_ci,
  `conditional_match_text` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_profile_question_translations_on_profile_question_id` (`profile_question_id`),
  KEY `index_profile_question_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `profile_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `profile_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) DEFAULT NULL,
  `question_type` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `section_id` int(11) DEFAULT NULL,
  `profile_answers_count` int(11) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `allow_other_option` tinyint(1) DEFAULT '0',
  `options_count` int(11) DEFAULT NULL,
  `conditional_question_id` int(11) DEFAULT NULL,
  `text_only_option` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_profile_questions_on_organization_id_and_position` (`organization_id`,`position`),
  KEY `index_profile_questions_on_profile_answers_count` (`profile_answers_count`),
  KEY `index_profile_questions_on_section_id` (`section_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `profile_views`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `profile_views` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `viewed_by_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_profile_views_on_user_id` (`user_id`),
  KEY `index_profile_views_on_viewed_by_id` (`viewed_by_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_ab_tests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_ab_tests` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `test` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `enabled` tinyint(1) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_program_ab_tests_on_test` (`test`),
  KEY `index_program_ab_tests_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_activities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_activities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `activity_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_program_activities_on_activity_id` (`activity_id`),
  KEY `index_program_activities_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_asset_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_asset_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `program_asset_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `logo_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `logo_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `logo_file_size` int(11) DEFAULT NULL,
  `banner_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `banner_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `banner_file_size` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_program_asset_translations_on_program_asset_id` (`program_asset_id`),
  KEY `index_program_asset_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_assets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_assets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `logo_updated_at` datetime DEFAULT NULL,
  `banner_updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `mobile_logo_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile_logo_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile_logo_file_size` int(11) DEFAULT NULL,
  `mobile_logo_updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_domains`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_domains` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `domain` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `subdomain` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_default` tinyint(1) NOT NULL DEFAULT '1',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_program_domains_on_domain_and_subdomain` (`domain`,`subdomain`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_event_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_event_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `program_event_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_program_event_translations_on_program_event_id` (`program_event_id`),
  KEY `index_program_event_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_event_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_event_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `program_event_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_program_event_users_on_user_id` (`user_id`),
  KEY `index_program_event_users_on_program_event_id` (`program_event_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_events` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `location` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `status` int(11) DEFAULT '0',
  `program_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `email_notification` tinyint(1) DEFAULT '0',
  `time_zone` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_view_id` int(11) DEFAULT NULL,
  `admin_view_title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_view_fetched_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_program_events_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_invitations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_invitations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `code` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `redeemed_at` datetime DEFAULT NULL,
  `sent_to` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expires_on` datetime DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `use_count` int(11) DEFAULT '0',
  `message` text COLLATE utf8mb4_unicode_ci,
  `sent_on` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role_type` int(11) DEFAULT NULL,
  `locale` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_on_code_for_program_invitations` (`code`),
  KEY `index_on_program_id_for_program_invitations` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_languages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_languages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_language_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `program_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `program_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `allow_mentoring_requests_message` text COLLATE utf8mb4_unicode_ci,
  `zero_match_score_message` text COLLATE utf8mb4_unicode_ci,
  `agreement` text COLLATE utf8mb4_unicode_ci,
  `privacy_policy` text COLLATE utf8mb4_unicode_ci,
  `browser_warning` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_program_translations_on_program_id` (`program_id`),
  KEY `index_program_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `programs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `programs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `allow_one_to_many_mentoring` tinyint(1) DEFAULT NULL,
  `mentoring_period` int(11) DEFAULT NULL,
  `analytics_script` text COLLATE utf8mb4_unicode_ci,
  `sort_users_by` tinyint(4) DEFAULT '0',
  `default_max_connections_limit` int(11) DEFAULT '5',
  `min_preferred_mentors` int(11) DEFAULT '0',
  `max_connections_for_mentee` int(11) DEFAULT NULL,
  `theme_id` int(11) DEFAULT NULL,
  `allow_mentoring_requests` tinyint(1) DEFAULT '1',
  `inactivity_tracking_period` int(11) DEFAULT '2592000',
  `mentor_request_style` int(11) DEFAULT '2',
  `footer_code` text COLLATE utf8mb4_unicode_ci,
  `type` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `parent_id` int(11) DEFAULT NULL,
  `root` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `programs_count` int(11) DEFAULT NULL,
  `logout_path` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ssl_only` tinyint(1) DEFAULT '0',
  `active` tinyint(1) DEFAULT '1',
  `mentor_offer_needs_acceptance` tinyint(1) DEFAULT '1',
  `base_program_id` int(11) DEFAULT NULL,
  `subscription_type` int(11) DEFAULT '1',
  `allow_users_to_leave_connection` tinyint(1) DEFAULT '0',
  `allow_to_change_connection_expiry_date` tinyint(1) DEFAULT '0',
  `allow_mentee_withdraw_mentor_request` tinyint(1) DEFAULT '0',
  `published` tinyint(1) DEFAULT '1',
  `max_pending_requests_for_mentee` int(11) DEFAULT NULL,
  `fluid_layout` tinyint(1) DEFAULT '0',
  `cannot_edit_admin_task_owner` tinyint(1) DEFAULT '1',
  `account_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `allow_private_journals` tinyint(1) DEFAULT '1',
  `allow_connection_feedback` tinyint(1) DEFAULT '1',
  `allow_preference_mentor_request` tinyint(1) DEFAULT '1',
  `show_multiple_role_option` tinyint(1) DEFAULT '0',
  `can_update_root` tinyint(1) NOT NULL DEFAULT '0',
  `email_from_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `allow_users_to_mark_connection_public` tinyint(1) DEFAULT '0',
  `engagement_type` int(11) DEFAULT NULL,
  `prevent_manager_matching` tinyint(1) DEFAULT '0',
  `allow_non_match_connection` tinyint(1) DEFAULT '0',
  `manager_matching_level` int(11) DEFAULT '1',
  `connection_limit_permission` tinyint(4) DEFAULT '3',
  `hybrid_templates_enabled` tinyint(1) DEFAULT '0',
  `program_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `number_of_licenses` int(11) DEFAULT NULL,
  `needs_meeting_request_reminder` tinyint(1) DEFAULT '0',
  `meeting_request_reminder_duration` int(11) DEFAULT '3',
  `needs_mentoring_request_reminder` tinyint(1) DEFAULT '0',
  `mentoring_request_reminder_duration` int(11) DEFAULT '3',
  `programs_listing_visibility` int(11) DEFAULT '0',
  `mentor_request_expiration_days` int(11) DEFAULT NULL,
  `needs_project_request_reminder` tinyint(1) DEFAULT '0',
  `project_request_reminder_duration` int(11) DEFAULT '3',
  `show_text_type_answers_per_reviewer_category` tinyint(1) DEFAULT '1',
  `position` int(11) DEFAULT NULL,
  `meeting_request_auto_expiration_days` int(11) DEFAULT NULL,
  `auto_terminate_reason_id` int(11) DEFAULT NULL,
  `allow_mentoring_mode_change` int(11) DEFAULT '0',
  `admin_access_to_mentoring_area` int(11) DEFAULT '0',
  `ssl_certificate_available` tinyint(1) DEFAULT '0',
  `creation_way` int(11) DEFAULT NULL,
  `prevent_past_mentor_matching` tinyint(1) DEFAULT '0',
  `email_theme_override` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `white_label` tinyint(1) DEFAULT '0',
  `favicon_link` text COLLATE utf8mb4_unicode_ci,
  `rollout_enabled` tinyint(1) DEFAULT '0',
  `display_custom_terms_only` tinyint(1) DEFAULT '0',
  `processing_weekly_digest` tinyint(1) DEFAULT '0',
  `allow_user_to_send_message_outside_mentoring_area` tinyint(1) DEFAULT '1',
  `audit_user_communication` tinyint(1) DEFAULT '0',
  `allow_track_admins_to_access_all_users` tinyint(1) DEFAULT '0',
  `allow_end_users_to_see_match_scores` tinyint(1) DEFAULT '1',
  `circle_request_auto_expiration_days` int(11) DEFAULT NULL,
  `allow_circle_start_date` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_programs_on_type_and_parent_id_and_root` (`type`,`parent_id`,`root`),
  KEY `index_programs_on_type_and_subdomain_and_domain` (`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `progress_status_counts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `progress_status_counts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `progress_status_id` int(11) DEFAULT NULL,
  `count` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `progress_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `progress_statuses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `for` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `completed_count` int(11) DEFAULT NULL,
  `maximum` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `publications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `publications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `publisher` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `authors` text COLLATE utf8mb4_unicode_ci,
  `description` text COLLATE utf8mb4_unicode_ci,
  `profile_answer_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `day` int(11) DEFAULT NULL,
  `month` int(11) DEFAULT NULL,
  `year` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_publications_on_profile_answer_id` (`profile_answer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `push_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `push_notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) NOT NULL,
  `notification_params` text COLLATE utf8mb4_unicode_ci,
  `unread` tinyint(1) DEFAULT '1',
  `ref_obj_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `notification_type` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_push_notifications_on_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `qa_answers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `qa_answers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `qa_question_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  `score` int(11) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_qa_answers_on_qa_question_id` (`qa_question_id`),
  KEY `index_qa_answers_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `qa_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `qa_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `summary` text COLLATE utf8mb4_unicode_ci,
  `description` text COLLATE utf8mb4_unicode_ci,
  `qa_answers_count` int(11) DEFAULT '0',
  `views` int(11) DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_qa_questions_on_updated_at` (`updated_at`),
  KEY `index_qa_questions_on_user_id` (`user_id`),
  KEY `index_qa_questions_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `question_choice_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `question_choice_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `question_choice_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `text` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_question_choice_translations_on_question_choice_id` (`question_choice_id`),
  KEY `index_question_choice_translations_on_locale` (`locale`),
  KEY `index_question_choice_translations_on_text` (`text`(191))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `question_choices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `question_choices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `is_other` tinyint(1) DEFAULT '0',
  `position` int(11) DEFAULT '0',
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_question_choices_on_ref_obj_type_and_ref_obj_id` (`ref_obj_type`,`ref_obj_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ratings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `ratings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `rating` int(11) DEFAULT '0',
  `rateable_type` varchar(15) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `rateable_id` int(11) NOT NULL DEFAULT '0',
  `user_id` int(11) NOT NULL DEFAULT '0',
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_ratings_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `received_mails`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `received_mails` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `message_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `stripped_text` text COLLATE utf8mb4_unicode_ci,
  `from_email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `to_email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `data` text COLLATE utf8mb4_unicode_ci,
  `response` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sender_match` tinyint(1) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `recent_activities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recent_activities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `action_type` int(11) NOT NULL,
  `for_id` int(11) DEFAULT NULL,
  `target` int(11) NOT NULL,
  `organization_id` int(11) DEFAULT NULL,
  `message` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_recent_activities_on_action_type` (`action_type`),
  KEY `index_recent_activities_on_for_id` (`for_id`),
  KEY `index_recent_activities_on_member_id` (`member_id`),
  KEY `index_recent_activities_on_target` (`target`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `recommendation_preferences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recommendation_preferences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `position` int(11) DEFAULT NULL,
  `mentor_recommendation_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_recommendation_preferences_on_user_id` (`user_id`),
  KEY `index_recommendation_preferences_on_mentor_recommendation_id` (`mentor_recommendation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `report_alerts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `report_alerts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `description` text COLLATE utf8mb4_unicode_ci,
  `filter_params` text COLLATE utf8mb4_unicode_ci,
  `operator` int(11) DEFAULT NULL,
  `target` int(11) DEFAULT NULL,
  `metric_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `default_alert` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_report_alerts_on_metric_id` (`metric_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `report_metrics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `report_metrics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `section_id` int(11) DEFAULT NULL,
  `abstract_view_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `position` int(11) DEFAULT '1000',
  `default_metric` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_report_metrics_on_section_id` (`section_id`),
  KEY `index_report_metrics_on_abstract_view_id` (`abstract_view_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `report_sections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `report_sections` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `program_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `position` int(11) DEFAULT '1000',
  `default_section` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_report_sections_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `report_view_columns`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `report_view_columns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `report_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `column_key` text COLLATE utf8mb4_unicode_ci,
  `position` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_report_view_columns_on_program_id_and_report_type` (`program_id`,`report_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resource_publications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resource_publications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `resource_id` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `show_in_quick_links` tinyint(1) DEFAULT '0',
  `admin_view_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_resource_publications_on_program_id` (`program_id`),
  KEY `index_resource_publications_on_resource_id` (`resource_id`),
  KEY `index_resource_publications_on_admin_view_id` (`admin_view_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resource_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resource_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `resource_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_resource_translations_on_resource_id` (`resource_id`),
  KEY `index_resource_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `resources` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `default` tinyint(1) NOT NULL DEFAULT '0',
  `view_count` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `role_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `role_permissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `role_id` int(11) NOT NULL,
  `permission_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_role_permissions_on_permission_id` (`permission_id`),
  KEY `index_role_permissions_on_role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `role_question_privacy_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `role_question_privacy_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `role_question_id` int(11) DEFAULT NULL,
  `role_id` int(11) DEFAULT NULL,
  `setting_type` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_role_question_privacy_settings_on_role_question_id` (`role_question_id`),
  KEY `index_role_question_privacy_settings_on_role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `role_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `role_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `role_id` int(11) DEFAULT NULL,
  `required` tinyint(1) NOT NULL DEFAULT '0',
  `private` int(11) DEFAULT '1',
  `filterable` tinyint(1) DEFAULT '1',
  `profile_question_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `in_summary` tinyint(1) DEFAULT '0',
  `available_for` int(11) DEFAULT '1',
  `admin_only_editable` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_role_questions_on_profile_question_id` (`profile_question_id`),
  KEY `index_role_questions_on_role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `role_references`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `role_references` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_id` int(11) NOT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_role_references_on_ref_obj_id_and_ref_obj_type` (`ref_obj_id`,`ref_obj_type`),
  KEY `index_role_references_on_role_id` (`role_id`),
  KEY `index_role_references_on_role_id_and_ref_obj_type` (`role_id`,`ref_obj_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `role_resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `role_resources` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `role_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `resource_publication_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_role_resources_on_resource_publication_id` (`resource_publication_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `role_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `role_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `role_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `eligibility_message` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_role_translations_on_role_id` (`role_id`),
  KEY `index_role_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `roles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `program_id` int(11) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `default` int(11) DEFAULT NULL,
  `join_directly` tinyint(1) DEFAULT NULL,
  `membership_request` tinyint(1) DEFAULT NULL,
  `invitation` tinyint(1) DEFAULT NULL,
  `join_directly_only_with_sso` tinyint(1) DEFAULT NULL,
  `administrative` tinyint(1) DEFAULT '0',
  `for_mentoring` tinyint(1) DEFAULT '0',
  `eligibility_rules` tinyint(1) DEFAULT NULL,
  `can_be_added_by_owners` tinyint(1) DEFAULT '1',
  `slot_config` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_roles_on_name` (`name`),
  KEY `index_roles_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `rollout_emails`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rollout_emails` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `action_type` int(11) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_rollout_emails_on_ref_obj_id_and_ref_obj_type` (`ref_obj_id`,`ref_obj_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `scheduling_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `scheduling_accounts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `section_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `section_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `section_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_section_translations_on_section_id` (`section_id`),
  KEY `index_section_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sections` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `default_field` tinyint(1) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_sections_on_program_id_and_position` (`program_id`,`position`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `security_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `security_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `can_contain_login_name` tinyint(1) DEFAULT '1',
  `password_expiration_frequency` int(11) DEFAULT '0',
  `email_domain` text COLLATE utf8mb4_unicode_ci,
  `auto_reactivate_account` float DEFAULT '24',
  `reactivation_email_enabled` tinyint(1) DEFAULT '1',
  `program_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `login_expiry_period` int(11) DEFAULT '120',
  `maximum_login_attempts` int(11) DEFAULT '0',
  `can_show_remember_me` tinyint(1) DEFAULT '1',
  `allowed_ips` text COLLATE utf8mb4_unicode_ci,
  `password_history_limit` int(11) DEFAULT NULL,
  `sanitization_version` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'v2',
  `linkedin_token` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `linkedin_secret` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `allow_search_engine_indexing` tinyint(1) DEFAULT '1',
  `allow_vulnerable_content_by_admin` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `index_security_settings_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sessions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `session_id` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `data` text COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `member_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_sessions_on_session_id` (`session_id`),
  KEY `index_sessions_on_updated_at` (`updated_at`),
  KEY `index_sessions_on_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `simple_captcha_data`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `simple_captcha_data` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `key` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `value` varchar(6) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `solution_packs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `solution_packs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `created_by` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_solution_packs_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `subscriptions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `subscriptions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_subscriptions_on_ref_obj_id` (`ref_obj_id`),
  KEY `index_subscriptions_on_ref_obj_type` (`ref_obj_type`),
  KEY `index_subscriptions_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `supplementary_matching_pairs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `supplementary_matching_pairs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `mentor_role_question_id` int(11) NOT NULL,
  `student_role_question_id` int(11) NOT NULL,
  `program_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_supplementary_matching_pairs_on_program_id` (`program_id`),
  KEY `index_supplementary_matching_pairs_on_mentor_role_question_id` (`mentor_role_question_id`),
  KEY `index_supplementary_matching_pairs_on_student_role_question_id` (`student_role_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `survey_response_columns`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `survey_response_columns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `survey_id` int(11) DEFAULT NULL,
  `profile_question_id` int(11) DEFAULT NULL,
  `column_key` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `position` int(11) DEFAULT NULL,
  `survey_question_id` int(11) DEFAULT NULL,
  `ref_obj_type` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_survey_response_columns_on_survey_id` (`survey_id`),
  KEY `index_survey_response_columns_on_profile_question_id` (`profile_question_id`),
  KEY `index_survey_response_columns_on_survey_question_id` (`survey_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `survey_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `survey_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `survey_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_survey_translations_on_survey_id` (`survey_id`),
  KEY `index_survey_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `surveys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `surveys` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `due_date` date DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `total_responses` int(11) NOT NULL DEFAULT '0',
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `edit_mode` int(11) DEFAULT NULL,
  `form_type` int(11) DEFAULT NULL,
  `role_name` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `progress_report` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_surveys_on_role_name` (`role_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `taggings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `taggings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `tag_id` int(11) DEFAULT NULL,
  `tagger_id` int(11) DEFAULT NULL,
  `tagger_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `taggable_id` int(11) DEFAULT NULL,
  `taggable_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `context` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `taggings_idx` (`tag_id`,`taggable_id`,`taggable_type`,`context`,`tagger_id`,`tagger_type`),
  KEY `index_taggings_on_taggable_id_and_taggable_type_and_context` (`taggable_id`,`taggable_type`,`context`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `taggings_count` int(11) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `tags_name_idx` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `temp_members`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `temp_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) DEFAULT NULL,
  `batch` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `temp_profile_answer_locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `temp_profile_answer_locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `profile_answer_id` int(11) DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `full_address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `temp_profile_objects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `temp_profile_objects` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `themes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `themes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `css_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `css_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `css_file_size` int(11) DEFAULT NULL,
  `css_updated_at` datetime DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `vars_list` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_competencies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_competencies` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_competencies_on_organization_id` (`organization_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_competency_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_competency_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `three_sixty_competency_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_17c100414096f3356dae7f3bce523b024e247d54` (`three_sixty_competency_id`),
  KEY `index_three_sixty_competency_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_question_translations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_question_translations` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `three_sixty_question_id` int(11) NOT NULL,
  `locale` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `title` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_bdc5b6c77729d72c3ae2bab7b4c54d2fb520546f` (`three_sixty_question_id`),
  KEY `index_three_sixty_question_translations_on_locale` (`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_competency_id` int(11) DEFAULT NULL,
  `question_type` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `organization_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_questions_on_competency_id` (`three_sixty_competency_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_reviewer_groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_reviewer_groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `threshold` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_reviewer_groups_on_organization_id` (`organization_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_survey_answers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_survey_answers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_survey_question_id` int(11) NOT NULL,
  `three_sixty_survey_reviewer_id` int(11) NOT NULL,
  `answer_text` text COLLATE utf8mb4_unicode_ci,
  `answer_value` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_answer_on_sur_question_id` (`three_sixty_survey_question_id`),
  KEY `index_three_sixty_answers_on_survey_reviewer_id` (`three_sixty_survey_reviewer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_survey_assessee_competency_infos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_survey_assessee_competency_infos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_survey_assessee_id` int(11) NOT NULL,
  `three_sixty_competency_id` int(11) NOT NULL,
  `three_sixty_reviewer_group_id` int(11) NOT NULL,
  `average_value` float NOT NULL DEFAULT '0',
  `answer_count` int(11) NOT NULL DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_asse_comp_info_on_survey_assessee_id` (`three_sixty_survey_assessee_id`),
  KEY `index_three_sixty_asse_comp_info_on_question_id` (`three_sixty_competency_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_survey_assessee_question_infos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_survey_assessee_question_infos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_survey_assessee_id` int(11) NOT NULL,
  `three_sixty_question_id` int(11) NOT NULL,
  `average_value` float NOT NULL DEFAULT '0',
  `answer_count` int(11) NOT NULL DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `three_sixty_reviewer_group_id` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_asse_que_info_on_survey_assessee_id` (`three_sixty_survey_assessee_id`),
  KEY `index_three_sixty_asse_que_info_on_question_id` (`three_sixty_question_id`),
  KEY `index_three_sixty_saqi_on_rg_id_and_q_id` (`three_sixty_reviewer_group_id`,`three_sixty_question_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_survey_assessees`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_survey_assessees` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_survey_id` int(11) NOT NULL,
  `member_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_survey_assessees_on_survey_id` (`three_sixty_survey_id`),
  KEY `index_three_sixty_survey_assessees_on_member_id` (`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_survey_competencies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_survey_competencies` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_survey_id` int(11) NOT NULL,
  `three_sixty_competency_id` int(11) NOT NULL,
  `position` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_survey_comp_on_survey_id` (`three_sixty_survey_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_survey_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_survey_questions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_survey_competency_id` int(11) DEFAULT NULL,
  `three_sixty_question_id` int(11) NOT NULL,
  `position` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `three_sixty_survey_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_survey_ques_on_survey_comp_id` (`three_sixty_survey_competency_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_survey_reviewer_groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_survey_reviewer_groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_survey_id` int(11) NOT NULL,
  `three_sixty_reviewer_group_id` int(11) NOT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_sur_revi_grp_on_survey_id` (`three_sixty_survey_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_survey_reviewers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_survey_reviewers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `three_sixty_survey_assessee_id` int(11) NOT NULL,
  `three_sixty_survey_reviewer_group_id` int(11) NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `invitation_code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `invite_sent` tinyint(1) NOT NULL DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `inviter_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_sur_reviewers_on_sur_assessee_id` (`three_sixty_survey_assessee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `three_sixty_surveys`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `three_sixty_surveys` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `organization_id` int(11) NOT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expiry_date` date DEFAULT NULL,
  `issue_date` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `program_id` int(11) DEFAULT NULL,
  `reviewers_addition_type` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_three_sixty_surveys_on_organization_id` (`organization_id`),
  KEY `index_three_sixty_surveys_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `topics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `topics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `forum_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hits` int(11) DEFAULT '0',
  `posts_count` int(11) DEFAULT '0',
  `sticky_position` int(11) DEFAULT '0',
  `body` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_topics_on_forum_id` (`forum_id`),
  KEY `index_topics_on_forum_id_and_replied_at` (`forum_id`),
  KEY `index_topics_on_sticky_and_replied_at` (`forum_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `translation_imports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `translation_imports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `program_id` int(11) DEFAULT NULL,
  `info` text COLLATE utf8mb4_unicode_ci,
  `local_csv_file_path` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_activities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_activities` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `activity` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `happened_at` datetime DEFAULT NULL,
  `member_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `organization_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `roles` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `current_connection_status` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `past_connection_status` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `join_date` datetime DEFAULT NULL,
  `mentor_request_style` int(11) DEFAULT NULL,
  `program_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `account_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `browser_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `platform_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `device_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `context_place` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `context_object` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_user_activities_on_activity` (`activity`),
  KEY `index_user_activities_on_happened_at` (`happened_at`),
  KEY `index_user_activities_on_member_id` (`member_id`),
  KEY `index_user_activities_on_organization_id` (`organization_id`),
  KEY `index_user_activities_on_user_id` (`user_id`),
  KEY `index_user_activities_on_program_id` (`program_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_csv_imports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_csv_imports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `member_id` int(11) DEFAULT NULL,
  `program_id` int(11) DEFAULT NULL,
  `info` text COLLATE utf8mb4_unicode_ci,
  `local_csv_file_path` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_content_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_file_size` int(11) DEFAULT NULL,
  `attachment_updated_at` datetime DEFAULT NULL,
  `imported` tinyint(1) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_favorites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_favorites` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `favorite_id` int(11) NOT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `position` int(11) DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mentor_request_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_user_favorites_on_mentor_request_id` (`mentor_request_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_notification_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_notification_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `notification_setting_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `disabled` tinyint(1) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_user_notification_settings_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `max_capacity_hours` int(11) DEFAULT NULL,
  `max_capacity_frequency` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `max_meeting_slots` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_user_settings_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_state_changes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_state_changes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `info` text COLLATE utf8mb4_unicode_ci,
  `date_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `date_time` datetime DEFAULT NULL,
  `connection_membership_info` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `index_user_state_changes_on_user_id` (`user_id`),
  KEY `index_user_state_changes_on_date_id` (`date_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_stats`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `user_stats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `average_rating` float DEFAULT '0.5',
  `rating_count` int(11) DEFAULT '0',
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_user_stats_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `state` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active',
  `activated_at` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `admin_notes` text COLLATE utf8mb4_unicode_ci,
  `program_id` int(11) DEFAULT NULL,
  `last_seen_at` datetime DEFAULT NULL,
  `max_connections_limit` int(11) DEFAULT NULL,
  `state_changer_id` int(11) DEFAULT NULL,
  `state_change_reason` text COLLATE utf8mb4_unicode_ci,
  `qa_answers_count` int(11) DEFAULT '0',
  `profile_updated_at` datetime DEFAULT NULL,
  `member_id` int(11) NOT NULL,
  `primary_home_tab` int(11) DEFAULT '0',
  `hide_profile_completion_bar` tinyint(1) DEFAULT '0',
  `creation_source` int(11) DEFAULT '0',
  `mentoring_mode` int(11) DEFAULT '3',
  `track_reactivation_state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `global_reactivation_state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `group_notification_setting` int(11) DEFAULT '0',
  `last_group_update_sent_time` datetime DEFAULT '2000-01-01 00:00:00',
  `program_notification_setting` int(11) DEFAULT '3',
  `last_program_update_sent_time` datetime DEFAULT '2000-01-01 00:00:00',
  `last_deactivated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_users_on_created_at` (`created_at`),
  KEY `index_users_on_member_id_and_global` (`member_id`),
  KEY `index_users_on_member_id_and_program_id` (`member_id`,`program_id`),
  KEY `index_users_on_state` (`state`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `versions_old`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `versions_old` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `versioned_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `versioned_id` int(11) DEFAULT NULL,
  `user_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `user_name` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `modifications` text COLLATE utf8mb4_unicode_ci,
  `number` int(11) DEFAULT NULL,
  `reverted_from` int(11) DEFAULT NULL,
  `tag` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_versions_old_on_versioned_id_and_versioned_type` (`versioned_id`,`versioned_type`),
  KEY `index_versions_old_on_user_id_and_user_type` (`user_id`,`user_type`),
  KEY `index_versions_old_on_user_name` (`user_name`),
  KEY `index_versions_old_on_number` (`number`),
  KEY `index_versions_old_on_created_at` (`created_at`),
  KEY `index_versions_old_on_tag` (`tag`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `viewed_objects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `viewed_objects` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ref_obj_type` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_viewed_objects_on_ref_obj_type_and_ref_obj_id` (`ref_obj_type`,`ref_obj_id`),
  KEY `index_viewed_objects_on_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `vulnerable_content_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vulnerable_content_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `original_content` text COLLATE utf8mb4_unicode_ci,
  `sanitized_content` text COLLATE utf8mb4_unicode_ci,
  `member_id` int(11) DEFAULT NULL,
  `ref_obj_id` int(11) DEFAULT NULL,
  `ref_obj_type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_obj_column` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source_audit_key` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

INSERT INTO `schema_migrations` (version) VALUES
('20110201060400'),
('20110320092458'),
('20120427095520'),
('20120428155650'),
('20120428160135'),
('20120510093017'),
('20120516055416'),
('20120519152352'),
('20120521084017'),
('20120531155631'),
('20120613123806'),
('20120621062726'),
('20120621063254'),
('20120621063518'),
('20120621150958'),
('20120623092233'),
('20120625063247'),
('20120626042950'),
('20120626172126'),
('20120628040319'),
('20120703101402'),
('20120706135919'),
('20120709080514'),
('20120711095546'),
('20120807062320'),
('20120823105016'),
('20120823130024'),
('20120827084145'),
('20120827090734'),
('20120828105112'),
('20120903081527'),
('20120904150607'),
('20120912061129'),
('20120912071011'),
('20120913122559'),
('20120917061123'),
('20120924091827'),
('20120924113030'),
('20120926050020'),
('20121003064827'),
('20121006084302'),
('20121009080044'),
('20121012033345'),
('20121012134836'),
('20121014152856'),
('20121015081457'),
('20121017081326'),
('20121018055342'),
('20121023101613'),
('20121025122047'),
('20121025143538'),
('20121025145507'),
('20121026063528'),
('20121029104159'),
('20121030102848'),
('20121101053319'),
('20121102123250'),
('20121108115017'),
('20121114102717'),
('20121114112417'),
('20121116161832'),
('20121119092308'),
('20121120092233'),
('20121120153816'),
('20121121044524'),
('20121121133711'),
('20121123145602'),
('20121129085546'),
('20121203052008'),
('20121206064329'),
('20121206091025'),
('20121206130225'),
('20121206142140'),
('20121212092045'),
('20121213142840'),
('20121214084935'),
('20121219115908'),
('20121219140240'),
('20121226055946'),
('20121226112853'),
('20121226200454'),
('20121227153043'),
('20130102072732'),
('20130102155605'),
('20130103105741'),
('20130104114602'),
('20130105125303'),
('20130108044149'),
('20130109121015'),
('20130116091531'),
('20130119124454'),
('20130123143947'),
('20130127125444'),
('20130128112132'),
('20130129044745'),
('20130130091118'),
('20130130144916'),
('20130131092642'),
('20130131101630'),
('20130131104238'),
('20130201053021'),
('20130201122259'),
('20130201122716'),
('20130201141153'),
('20130203063419'),
('20130203104304'),
('20130204132930'),
('20130207131939'),
('20130212115820'),
('20130215073829'),
('20130222045414'),
('20130228065758'),
('20130306061228'),
('20130307062901'),
('20130307093048'),
('20130311151627'),
('20130311151949'),
('20130311152418'),
('20130313095329'),
('20130314061530'),
('20130315092207'),
('20130326095838'),
('20130326112314'),
('20130402115736'),
('20130410124930'),
('20130410145907'),
('20130412080203'),
('20130419065605'),
('20130419081060'),
('20130424122832'),
('20130425123741'),
('20130425124310'),
('20130426055825'),
('20130429155107'),
('20130430101442'),
('20130502070933'),
('20130513085452'),
('20130514065645'),
('20130515151640'),
('20130516115620'),
('20130517131610'),
('20130517132507'),
('20130520141658'),
('20130523114834'),
('20130524082254'),
('20130524144654'),
('20130527122252'),
('20130528061115'),
('20130528084648'),
('20130529031112'),
('20130529040609'),
('20130529041607'),
('20130529043234'),
('20130529103358'),
('20130529130202'),
('20130604092500'),
('20130605065902'),
('20130606090223'),
('20130606091028'),
('20130606091200'),
('20130606102517'),
('20130606125844'),
('20130606133357'),
('20130611094910'),
('20130612114624'),
('20130614124903'),
('20130619123226'),
('20130620085756'),
('20130620132930'),
('20130624101747'),
('20130624132445'),
('20130704103632'),
('20130708064828'),
('20130709084216'),
('20130709094322'),
('20130712103326'),
('20130715164523'),
('20130726143241'),
('20130726145338'),
('20130729063724'),
('20130730133131'),
('20130731084821'),
('20130731131827'),
('20130801041708'),
('20130801093551'),
('20130805101115'),
('20130806144150'),
('20130807113609'),
('20130807152940'),
('20130813114306'),
('20130820180640'),
('20130821162538'),
('20130830045926'),
('20130830062106'),
('20130901112223'),
('20130905092115'),
('20130911122606'),
('20130911145938'),
('20130916095906'),
('20130916102136'),
('20130916103001'),
('20130920111958'),
('20130923123910'),
('20130924091445'),
('20130925040705'),
('20130925114133'),
('20130926060014'),
('20130930094723'),
('20131001094947'),
('20131002155451'),
('20131003121815'),
('20131006073146'),
('20131007072057'),
('20131008135924'),
('20131008194351'),
('20131009103037'),
('20131010102527'),
('20131010135958'),
('20131015053354'),
('20131024074719'),
('20131026194019'),
('20131029121845'),
('20131107071513'),
('20131111110716'),
('20131113063219'),
('20131114001908'),
('20131119051720'),
('20131126122948'),
('20131127054335'),
('20131128135623'),
('20131202043408'),
('20131202085912'),
('20131202131459'),
('20131206084103'),
('20131209125832'),
('20131210111252'),
('20131212110120'),
('20131217133759'),
('20131218051954'),
('20131218091026'),
('20131226114239'),
('20131226143401'),
('20131227113729'),
('20140106121854'),
('20140108094322'),
('20140114130533'),
('20140115052203'),
('20140115073716'),
('20140120064223'),
('20140120154057'),
('20140121080315'),
('20140122115131'),
('20140122115841'),
('20140122160117'),
('20140127064033'),
('20140130091458'),
('20140204172354'),
('20140205143530'),
('20140206084404'),
('20140206134607'),
('20140207101546'),
('20140207104619'),
('20140211093222'),
('20140211114510'),
('20140212054924'),
('20140212135411'),
('20140212141613'),
('20140213093909'),
('20140214093909'),
('20140214095342'),
('20140215054043'),
('20140217152022'),
('20140218050413'),
('20140218053628'),
('20140218061149'),
('20140218092401'),
('20140218191618'),
('20140218195455'),
('20140219042714'),
('20140219102824'),
('20140219113158'),
('20140220044213'),
('20140220094128'),
('20140220095030'),
('20140221053430'),
('20140224050345'),
('20140224121558'),
('20140224133130'),
('20140224162039'),
('20140226082705'),
('20140226083431'),
('20140226084219'),
('20140227100807'),
('20140227121823'),
('20140227154049'),
('20140227155009'),
('20140228063149'),
('20140228091243'),
('20140303054429'),
('20140304103636'),
('20140304110708'),
('20140304111002'),
('20140304190031'),
('20140305034916'),
('20140310094702'),
('20140311110108'),
('20140311123052'),
('20140312220058'),
('20140313054912'),
('20140317072958'),
('20140317135631'),
('20140318091557'),
('20140324054036'),
('20140324055152'),
('20140324055702'),
('20140326071857'),
('20140326072541'),
('20140326072553'),
('20140401040455'),
('20140402073511'),
('20140402130816'),
('20140403111212'),
('20140407070908'),
('20140411040919'),
('20140414095352'),
('20140416113554'),
('20140422102046'),
('20140422185430'),
('20140423111340'),
('20140424190725'),
('20140424191724'),
('20140425513854'),
('20140427172023'),
('20140428082259'),
('20140428105043'),
('20140429142909'),
('20140505140048'),
('20140506063517'),
('20140507124220'),
('20140507154143'),
('20140508103737'),
('20140513084520'),
('20140514192248'),
('20140515070223'),
('20140515133117'),
('20140516100243'),
('20140518105507'),
('20140519065811'),
('20140520130937'),
('20140521121749'),
('20140522091239'),
('20140523060543'),
('20140524083844'),
('20140526090730'),
('20140526095446'),
('20140529054949'),
('20140529055047'),
('20140529061428'),
('20140529061445'),
('20140530130025'),
('20140604072054'),
('20140604114407'),
('20140605143123'),
('20140605202805'),
('20140607191541'),
('20140609134123'),
('20140610073918'),
('20140611060752'),
('20140611122517'),
('20140612070317'),
('20140613060149'),
('20140616062044'),
('20140616064436'),
('20140616071404'),
('20140616104533'),
('20140616131719'),
('20140617084009'),
('20140617091226'),
('20140617112204'),
('20140624060314'),
('20140625141103'),
('20140626064518'),
('20140704070441'),
('20140705111733'),
('20140705134054'),
('20140707072332'),
('20140707080157'),
('20140707080410'),
('20140707174908'),
('20140708140451'),
('20140709071204'),
('20140709111123'),
('20140709134128'),
('20140709154649'),
('20140714190527'),
('20140715093512'),
('20140717122622'),
('20140717124611'),
('20140718062752'),
('20140718070513'),
('20140721061216'),
('20140721061428'),
('20140721113417'),
('20140722140332'),
('20140722143208'),
('20140723060713'),
('20140728064807'),
('20140728091632'),
('20140728105204'),
('20140730115636'),
('20140801140200'),
('20140804092753'),
('20140805170740'),
('20140807090828'),
('20140807090829'),
('20140807133707'),
('20140807142327'),
('20140807142507'),
('20140808054335'),
('20140808054336'),
('20140808102444'),
('20140809071924'),
('20140811072600'),
('20140811073239'),
('20140811080719'),
('20140815163018'),
('20140818075733'),
('20140818114646'),
('20140819061421'),
('20140819141421'),
('20140819141449'),
('20140821115752'),
('20140825071045'),
('20140825074806'),
('20140825114326'),
('20140825130852'),
('20140827072627'),
('20140827072842'),
('20140827072843'),
('20140827072844'),
('20140827094254'),
('20140827125008'),
('20140901043720'),
('20140901124454'),
('20140902124241'),
('20140902131853'),
('20140902131854'),
('20140904013828'),
('20140904063849'),
('20140908071016'),
('20140908083406'),
('20140911130426'),
('20140915083414'),
('20140917061243'),
('20140917122900'),
('20140918063819'),
('20140918135104'),
('20140918135105'),
('20140919054155'),
('20140920105328'),
('20140924113638'),
('20140927054315'),
('20140929114547'),
('20141005154400'),
('20141010184922'),
('20141014134526'),
('20141016140635'),
('20141017082000'),
('20141020071641'),
('20141020071642'),
('20141027115631'),
('20141027133507'),
('20141027133509'),
('20141028082455'),
('20141028105943'),
('20141028113742'),
('20141031065107'),
('20141103055346'),
('20141103141253'),
('20141104072504'),
('20141105142503'),
('20141106062706'),
('20141106140336'),
('20141106143244'),
('20141114063941'),
('20141117144603'),
('20141118141529'),
('20141119101221'),
('20141120051946'),
('20141120130028'),
('20141120140536'),
('20141120191545'),
('20141121061955'),
('20141121065207'),
('20141125043022'),
('20141125081617'),
('20141125101647'),
('20141125102601'),
('20141126095044'),
('20141201084332'),
('20141202113212'),
('20141203081705'),
('20141203142920'),
('20141203163430'),
('20141205091426'),
('20141208093132'),
('20141208093133'),
('20141210060636'),
('20141210110011'),
('20141210163352'),
('20141211070813'),
('20141212092017'),
('20141215063031'),
('20141215085843'),
('20141217112215'),
('20141217120223'),
('20141219072250'),
('20141219114251'),
('20141222090004'),
('20141223083529'),
('20141223083749'),
('20150108120151'),
('20150109102625'),
('20150110095856'),
('20150112115520'),
('20150116092835'),
('20150128081815'),
('20150130031030'),
('20150203071419'),
('20150205120637'),
('20150209101809'),
('20150211084146'),
('20150216045106'),
('20150216093023'),
('20150216101348'),
('20150217051721'),
('20150223055145'),
('20150226141757'),
('20150227141514'),
('20150303093800'),
('20150309122254'),
('20150316050054'),
('20150316144708'),
('20150317144828'),
('20150319162007'),
('20150320102225'),
('20150320133730'),
('20150323122252'),
('20150323123841'),
('20150323142505'),
('20150324090619'),
('20150330071539'),
('20150401141006'),
('20150406133349'),
('20150410112004'),
('20150413060838'),
('20150415145408'),
('20150424094820'),
('20150430094246'),
('20150507070747'),
('20150507091844'),
('20150508110913'),
('20150508123749'),
('20150511091627'),
('20150512135311'),
('20150512135811'),
('20150515093128'),
('20150521143554'),
('20150522123908'),
('20150522142846'),
('20150526062030'),
('20150526071422'),
('20150526113558'),
('20150526124011'),
('20150611103600'),
('20150624063713'),
('20150629075316'),
('20150706020941'),
('20150707061559'),
('20150707062000'),
('20150707063000'),
('20150715140031'),
('20150722103153'),
('20150724135052'),
('20150724142954'),
('20150728060121'),
('20150804062328'),
('20150805141037'),
('20150805151925'),
('20150810060437'),
('20150813130856'),
('20150817060912'),
('20150825123923'),
('20150831051833'),
('20150907071856'),
('20150921071540'),
('20150924075923'),
('20151012071713'),
('20151015085244'),
('20151017181834'),
('20151018124348'),
('20151019081155'),
('20151102093857'),
('20151119085326'),
('20151209105324'),
('20151223120400'),
('20151230050715'),
('20151231062455'),
('20151231065807'),
('20160106125121'),
('20160107133411'),
('20160120140433'),
('20160207095604'),
('20160401111059'),
('20160510182512'),
('20160521053541'),
('20160525120351'),
('20160526123932'),
('20160602131728'),
('20160613093819'),
('20160613113938'),
('20160616102003'),
('20160616122501'),
('20160616135559'),
('20160620081444'),
('20160622053144'),
('20160622073232'),
('20160624111750'),
('20160624113028'),
('20160628052625'),
('20160628100036'),
('20160701110605'),
('20160706145952'),
('20160706151428'),
('20160707111432'),
('20160707130714'),
('20160707130715'),
('20160707130716'),
('20160707130717'),
('20160713061204'),
('20160725143413'),
('20160728062412'),
('20160811103349'),
('20160816075220'),
('20160824102210'),
('20160830101807'),
('20160909074420'),
('20160925121813'),
('20161005074609'),
('20161005091921'),
('20161012121420'),
('20161021050312'),
('20161101135646'),
('20161107122917'),
('20161115060540'),
('20161116084551'),
('20161121141855'),
('20161125144253'),
('20161128161921'),
('20161202123035'),
('20161206093227'),
('20161208084615'),
('20161215222639'),
('20161219031914'),
('20161220080335'),
('20161223133127'),
('20161226073448'),
('20161226090937'),
('20170111125454'),
('20170112185401'),
('20170116092424'),
('20170123184455'),
('20170124085629'),
('20170201120117'),
('20170207134358'),
('20170207142345'),
('20170209144228'),
('20170214105247'),
('20170215121059'),
('20170216154523'),
('20170217080116'),
('20170308094414'),
('20170317100507'),
('20170331112947'),
('20170403055412'),
('20170413080624'),
('20170417112132'),
('20170420081338'),
('20170420094750'),
('20170423114623'),
('20170423145416'),
('20170424093257'),
('20170426043529'),
('20170426062523'),
('20170502123429'),
('20170502124553'),
('20170502135028'),
('20170508060848'),
('20170508094826'),
('20170509082447'),
('20170510055906'),
('20170518120236'),
('20170522135017'),
('20170524054501'),
('20170530084254'),
('20170530104305'),
('20170531084357'),
('20170601135808'),
('20170607083401'),
('20170608071148'),
('20170615055655'),
('20170615072713'),
('20170627095533'),
('20170628100925'),
('20170630093356'),
('20170703080347'),
('20170706114235'),
('20170707063625'),
('20170707064142'),
('20170710054455'),
('20170711044653'),
('20170711095709'),
('20170711102903'),
('20170711130802'),
('20170712103612'),
('20170712140322'),
('20170712142736'),
('20170713065440'),
('20170713122008'),
('20170713143248'),
('20170714052134'),
('20170714125908'),
('20170714125953'),
('20170714133628'),
('20170715070320'),
('20170715070321'),
('20170716141742'),
('20170717144336'),
('20170719071336'),
('20170719140117'),
('20170719140353'),
('20170720054059'),
('20170720143920'),
('20170724053125'),
('20170724061924'),
('20170724072823'),
('20170724074221'),
('20170725054923'),
('20170725125848'),
('20170725170601'),
('20170726045645'),
('20170726091621'),
('20170726154138'),
('20170727055329'),
('20170727063705'),
('20170727105422'),
('20170728065021'),
('20170728071904'),
('20170730061348'),
('20170801064006'),
('20170803070747'),
('20170803074211'),
('20170804061606'),
('20170804140831'),
('20170808060054'),
('20170808095427'),
('20170808121838'),
('20170809072755'),
('20170809150012'),
('20170810073445'),
('20170814035437'),
('20170814124412'),
('20170818144503'),
('20170821154749'),
('20170823045021'),
('20170828085037'),
('20170829055650'),
('20170829083048'),
('20170830071015'),
('20170830104853'),
('20170831101155'),
('20170831125048'),
('20170901063038'),
('20170901091700'),
('20170901130005'),
('20170904092118'),
('20170904103627'),
('20170904121049'),
('20170905090803'),
('20170906065658'),
('20170906131124'),
('20170907055307'),
('20170907060444'),
('20170907062531'),
('20170907080837'),
('20170908053722'),
('20170908140050'),
('20170908141748'),
('20170908142358'),
('20170908171738'),
('20170909111518'),
('20170911153953'),
('20170913070308'),
('20170918064549'),
('20170920095240'),
('20170920105437'),
('20171011061016'),
('20171011064029'),
('20171011080807'),
('20171020061008'),
('20171020195552'),
('20171021023931'),
('20171021023949'),
('20171023161704'),
('20171023225655'),
('20171025064420'),
('20171025101422'),
('20171031090027'),
('20171031105405'),
('20171106073013'),
('20171108083928'),
('20171114161704'),
('20171115154359'),
('20171115171930'),
('20171116051011'),
('20171116054631'),
('20171116065758'),
('20171116070905'),
('20171116070906'),
('20171117125620'),
('20171120061311'),
('20171120130046'),
('20171120134359'),
('20171121124044'),
('20171127103651'),
('20171127105641'),
('20171127115459'),
('20171128092717'),
('20171204082732'),
('20171204120811'),
('20171208053619'),
('20171212064625'),
('20171213140150'),
('20171214064537'),
('20171219080604'),
('20171220075157'),
('20171221105235'),
('20171227053257'),
('20171227060716'),
('20171229155134'),
('20171229155919'),
('20180102145945'),
('20180102151555'),
('20180102154153'),
('20180102154237'),
('20180103113046'),
('20180108160735'),
('20180109094227'),
('20180110140849'),
('20180111143031'),
('20180111174618'),
('20180116100919'),
('20180119062255'),
('20180123105418'),
('20180123153641'),
('20180129053050'),
('20180130121554'),
('20180130123907'),
('20180130124558'),
('20180130132313'),
('20180131075429'),
('20180131081224'),
('20180131084841'),
('20180131085440'),
('20180131132705'),
('20180205054528'),
('20180206151506'),
('20180212072735'),
('20180213081535'),
('20180214140957'),
('20180219053037'),
('20180220064328'),
('20180222142727'),
('20180226131741'),
('20180227083657'),
('20180228072653'),
('20180305053318'),
('20180308060722'),
('20180308082233'),
('20180312091654'),
('20180312110008'),
('20180313075455'),
('20180314125318'),
('20180315061411'),
('20180315115106'),
('20180319123507'),
('20180321085448'),
('20180326090558'),
('20180326131850'),
('20180403100647'),
('20180403105300'),
('20180405085847'),
('20180405091554'),
('20180409070624'),
('20180410021845'),
('20180410124943'),
('20180411103229'),
('20180412054539'),
('20180413033602'),
('20180413062241'),
('20180413135156'),
('20180413141501'),
('20180417054748'),
('20180417082810'),
('20180417101805'),
('20180425045039'),
('20180425072420'),
('20180427042640'),
('20180503075559'),
('20180507115133'),
('20180509105445'),
('20180511044643'),
('20180511142944'),
('20180516102913'),
('20180517065949'),
('20180524051155'),
('20180524073728'),
('20180525090424'),
('20180530060045'),
('20180619055820'),
('20180620145746'),
('20180628182232'),
('20180703135140'),
('20180703143121');


