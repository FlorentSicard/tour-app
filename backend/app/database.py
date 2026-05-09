from sqlalchemy import text
from sqlmodel import SQLModel, Session, create_engine
from app.config import DATABASE_URL

engine = create_engine(DATABASE_URL, echo=False)


def _migrate_groups_schema():
    with engine.begin() as conn:
        cols = {
            row[0]
            for row in conn.execute(
                text(
                    """
                    SELECT COLUMN_NAME
                    FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'groups'
                    """
                )
            )
        }

        if "owner_id" in cols:
            fk_rows = conn.execute(
                text(
                    """
                    SELECT CONSTRAINT_NAME
                    FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'groups'
                      AND COLUMN_NAME = 'owner_id'
                      AND REFERENCED_TABLE_NAME IS NOT NULL
                    """
                )
            ).fetchall()
            for (fk_name,) in fk_rows:
                conn.execute(text(f"ALTER TABLE `groups` DROP FOREIGN KEY `{fk_name}`"))

            idx_rows = conn.execute(
                text(
                    """
                    SELECT INDEX_NAME
                    FROM INFORMATION_SCHEMA.STATISTICS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'groups'
                      AND COLUMN_NAME = 'owner_id'
                      AND INDEX_NAME <> 'PRIMARY'
                    """
                )
            ).fetchall()
            for (idx_name,) in idx_rows:
                conn.execute(text(f"ALTER TABLE `groups` DROP INDEX `{idx_name}`"))

            conn.execute(text("ALTER TABLE `groups` DROP COLUMN `owner_id`"))

        cols = {
            row[0]
            for row in conn.execute(
                text(
                    """
                    SELECT COLUMN_NAME
                    FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'groups'
                    """
                )
            )
        }

        if "email" not in cols:
            conn.execute(text("ALTER TABLE `groups` ADD COLUMN `email` VARCHAR(255) NULL"))

        if "password_hash" not in cols:
            conn.execute(text("ALTER TABLE `groups` ADD COLUMN `password_hash` VARCHAR(255) NULL"))

        if "created_at" not in cols:
            conn.execute(
                text(
                    "ALTER TABLE `groups` ADD COLUMN `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP"
                )
            )

        if "is_public" in cols:
            conn.execute(text("ALTER TABLE `groups` DROP COLUMN `is_public`"))

        has_unique_email = conn.execute(
            text(
                """
                SELECT COUNT(*)
                FROM INFORMATION_SCHEMA.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'groups'
                  AND COLUMN_NAME = 'email'
                  AND NON_UNIQUE = 0
                """
            )
        ).scalar_one()
        if not has_unique_email:
            conn.execute(text("ALTER TABLE `groups` ADD UNIQUE INDEX `uq_groups_email` (`email`)"))


def _migrate_days_schema():
    with engine.begin() as conn:
        cols = {
            row[0]
            for row in conn.execute(
                text(
                    """
                    SELECT COLUMN_NAME
                    FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'days'
                    """
                )
            )
        }

        if "contact_text" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `contact_text` TEXT NULL"))

        if "finance_text" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `finance_text` TEXT NULL"))

        if "day_note" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `day_note` TEXT NULL"))

        if "address" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `address` VARCHAR(500) NULL"))

        if "promo_sent" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `promo_sent` TINYINT(1) NOT NULL DEFAULT 0"))

        if "coplateau" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `coplateau` TINYINT(1) NOT NULL DEFAULT 0"))

        if "roadmap_sent" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `roadmap_sent` TINYINT(1) NOT NULL DEFAULT 0"))

        if "backline_conversation" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `backline_conversation` TINYINT(1) NOT NULL DEFAULT 0"))

        if "hebergement" not in cols:
            conn.execute(text("ALTER TABLE `days` ADD COLUMN `hebergement` TEXT NULL"))

        conn.execute(
            text(
                """
                UPDATE `days`
                SET `address` = COALESCE(NULLIF(TRIM(`venue`), ''), NULLIF(TRIM(`city`), ''), 'Unknown address')
                WHERE `type` = 'concert' AND (`address` IS NULL OR TRIM(`address`) = '')
                """
            )
        )


def _drop_checklist_schema():
    with engine.begin() as conn:
        tables = {
            row[0]
            for row in conn.execute(
                text(
                    """
                    SELECT TABLE_NAME
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = DATABASE()
                    """
                )
            )
        }

        if "checklist_items" in tables:
            conn.execute(text("DROP TABLE `checklist_items`"))
        if "checklist_templates" in tables:
            conn.execute(text("DROP TABLE `checklist_templates`"))


def _migrate_schedule_schema():
    with engine.begin() as conn:
        cols = {
            row[0]
            for row in conn.execute(
                text(
                    """
                    SELECT COLUMN_NAME
                    FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_SCHEMA = DATABASE()
                      AND TABLE_NAME = 'schedule_items'
                    """
                )
            )
        }

        if "visibility" not in cols:
            conn.execute(
                text(
                    "ALTER TABLE `schedule_items` ADD COLUMN `visibility` VARCHAR(20) NOT NULL DEFAULT 'private'"
                )
            )


def init_db():
    SQLModel.metadata.create_all(engine)
    _migrate_groups_schema()
    _migrate_days_schema()
    _migrate_schedule_schema()
    _drop_checklist_schema()


def get_session():
    with Session(engine) as session:
        yield session
