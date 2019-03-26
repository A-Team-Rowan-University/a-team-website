pub mod models;
pub mod requests;
pub mod schema;

use self::schema::users as users_schema;
use diesel::expression::AsExpression;
use diesel::expression::Expression;
use diesel::mysql::Mysql;
use diesel::query_builder::InsertStatement;
use diesel::query_builder::ValuesClause;
use rouille;
