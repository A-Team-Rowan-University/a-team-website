use diesel;
use diesel::mysql::types::Unsigned;
use diesel::mysql::Mysql;
use diesel::mysql::MysqlConnection;
use diesel::query_builder::AsQuery;
use diesel::query_builder::BoxedSelectStatement;
use diesel::types;
use diesel::ExpressionMethods;
use diesel::NullableExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;
use diesel::TextExpressionMethods;

use crate::errors::{WebdevError, WebdevErrorKind};

use crate::search::Search;

use super::models::{
    Chemical, ChemicalInventory, ChemicalInventoryList,
    ChemicalInventoryRequest, ChemicalInventoryResponse, ChemicalList,
    ChemicalRequest, ChemicalResponse, NewChemical, NewChemicalInventory,
    PartialChemical, PartialChemicalInventory, SearchChemical,
    SearchChemicalInventory,
};

use super::schema::chemical as chemical_schema;
use super::schema::chemical_inventory as chemical_inventory_schema;

pub fn handle_chemical(
    request: ChemicalRequest,
    database_connection: &MysqlConnection,
) -> Result<ChemicalResponse, WebdevError> {
    match request {
        ChemicalRequest::Search(chemical) => {
            search_chemical(chemical, database_connection)
                .map(|c| ChemicalResponse::ManyChemical(c))
        }
        ChemicalRequest::GetChemical(id) => {
            get_chemical(id, database_connection)
                .map(|c| ChemicalResponse::OneChemical(c))
        }
        ChemicalRequest::CreateChemical(chemical) => {
            create_chemical(chemical, database_connection)
                .map(|c| ChemicalResponse::OneChemical(c))
        }
        ChemicalRequest::UpdateChemical(id, chemical) => {
            update_chemical(id, chemical, database_connection)
                .map(|_| ChemicalResponse::NoResponse)
        }
        ChemicalRequest::DeleteChemical(id) => {
            delete_chemical(id, database_connection)
                .map(|_| ChemicalResponse::NoResponse)
        }
    }
}

fn search_chemical(
    chemical_search: SearchChemical,
    database_connection: &MysqlConnection,
) -> Result<ChemicalList, WebdevError> {
    let mut chemical_query = chemical_schema::table.as_query().into_boxed();

    match chemical_search.name {
        Search::Partial(s) => {
            chemical_query = chemical_query
                .filter(chemical_schema::name.like(format!("%%{}%", s)))
        }

        Search::Exact(s) => {
            chemical_query = chemical_query.filter(chemical_schema::name.eq(s))
        }

        Search::NoSearch => {}
    }

    match chemical_search.purpose {
        Search::Partial(s) => {
            chemical_query = chemical_query
                .filter(chemical_schema::purpose.like(format!("%%{}%", s)))
        }

        Search::Exact(s) => {
            chemical_query =
                chemical_query.filter(chemical_schema::purpose.eq(s))
        }

        Search::NoSearch => {}
    }

    match chemical_search.company_name {
        Search::Partial(s) => {
            chemical_query = chemical_query
                .filter(chemical_schema::company_name.like(format!("%%{}%", s)))
        }

        Search::Exact(s) => {
            chemical_query =
                chemical_query.filter(chemical_schema::company_name.eq(s))
        }

        Search::NoSearch => {}
    }

    match chemical_search.ingredients {
        Search::Partial(s) => {
            chemical_query = chemical_query
                .filter(chemical_schema::ingredients.like(format!("%%{}%", s)))
        }

        Search::Exact(s) => {
            chemical_query =
                chemical_query.filter(chemical_schema::ingredients.eq(s))
        }

        Search::NoSearch => {}
    }

    match chemical_search.manual_link {
        Search::Partial(s) => {
            chemical_query = chemical_query
                .filter(chemical_schema::manual_link.like(format!("%{}%", s)))
        }

        Search::Exact(s) => {
            chemical_query =
                chemical_query.filter(chemical_schema::manual_link.eq(s))
        }

        Search::NoSearch => {}
    }

    let found_chemicals =
        chemical_query.load::<Chemical>(database_connection)?;
    let chemical_list = ChemicalList {
        chemicals: found_chemicals,
    };

    Ok(chemical_list)
}

fn get_chemical(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<Chemical, WebdevError> {
    let mut found_chemical = chemical_schema::table
        .filter(chemical_schema::id.eq(id))
        .load::<Chemical>(database_connection)?;

    match found_chemical.pop() {
        Some(chemical) => Ok(chemical),
        None => Err(WebdevError::new(WebdevErrorKind::NotFound)),
    }
}

fn create_chemical(
    chemical: NewChemical,
    database_connection: &MysqlConnection,
) -> Result<Chemical, WebdevError> {
    diesel::insert_into(chemical_schema::table)
        .values(chemical)
        .execute(database_connection)?;

    no_arg_sql_function!(last_insert_id, Unsigned<types::Bigint>);

    let mut inserted_chemicals = chemical_schema::table
        .filter(chemical_schema::id.eq(last_insert_id))
        .load::<Chemical>(database_connection)?;

    if let Some(inserted_chemical) = inserted_chemicals.pop() {
        Ok(inserted_chemical)
    } else {
        Err(WebdevError::new(WebdevErrorKind::Database))
    }
}

fn update_chemical(
    id: u64,
    chemical: PartialChemical,
    database_connection: &MysqlConnection,
) -> Result<(), WebdevError> {
    diesel::update(chemical_schema::table)
        .filter(chemical_schema::id.eq(id))
        .set(&chemical)
        .execute(database_connection)?;
    Ok(())
}

fn delete_chemical(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), WebdevError> {
    diesel::delete(chemical_schema::table.filter(chemical_schema::id.eq(id)))
        .execute(database_connection)?;

    Ok(())
}

pub fn handle_chemical_inventory(
    request: ChemicalInventoryRequest,
    database_connection: &MysqlConnection,
) -> Result<ChemicalInventoryResponse, WebdevError> {
    match request {
        ChemicalInventoryRequest::SearchInventory(inventory) => {
            search_chemical_inventory(inventory, database_connection)
                .map(|c| ChemicalInventoryResponse::ManyInventoryEntries(c))
        }
        ChemicalInventoryRequest::GetInventory(id) => {
            get_chemical_inventory(id, database_connection)
                .map(|c| ChemicalInventoryResponse::OneInventoryEntry(c))
        }
        ChemicalInventoryRequest::CreateInventory(inventory) => {
            create_chemical_inventory(inventory, database_connection)
                .map(|c| ChemicalInventoryResponse::OneInventoryEntry(c))
        }
        ChemicalInventoryRequest::UpdateInventory(id, inventory) => {
            update_chemical_inventory(id, inventory, database_connection)
                .map(|_| ChemicalInventoryResponse::NoResponse)
        }
        ChemicalInventoryRequest::DeleteInventory(id) => {
            delete_chemical_inventory(id, database_connection)
                .map(|_| ChemicalInventoryResponse::NoResponse)
        }
    }
}

fn search_chemical_inventory(
    chemical_inventory_search: SearchChemicalInventory,
    database_connection: &MysqlConnection,
) -> Result<ChemicalInventoryList, WebdevError> {
    let mut chemical_inventory_query =
        chemical_inventory_schema::table.as_query().into_boxed();

    match chemical_inventory_search.purchaser_id {
        Search::Partial(s) => {
            chemical_inventory_query = chemical_inventory_query
                .filter(chemical_inventory_schema::purchaser_id.eq(s))
        }

        Search::Exact(s) => {
            chemical_inventory_query = chemical_inventory_query
                .filter(chemical_inventory_schema::purchaser_id.eq(s))
        }

        Search::NoSearch => {}
    }

    match chemical_inventory_search.custodian_id {
        Search::Partial(s) => {
            chemical_inventory_query = chemical_inventory_query
                .filter(chemical_inventory_schema::custodian_id.eq(s))
        }

        Search::Exact(s) => {
            chemical_inventory_query = chemical_inventory_query
                .filter(chemical_inventory_schema::custodian_id.eq(s))
        }

        Search::NoSearch => {}
    }

    match chemical_inventory_search.chemical_id {
        Search::Partial(s) => {
            chemical_inventory_query = chemical_inventory_query
                .filter(chemical_inventory_schema::chemical_id.eq(s))
        }

        Search::Exact(s) => {
            chemical_inventory_query = chemical_inventory_query
                .filter(chemical_inventory_schema::chemical_id.eq(s))
        }

        Search::NoSearch => {}
    }

    match chemical_inventory_search.storage_location {
        Search::Partial(s) => {
            chemical_inventory_query = chemical_inventory_query.filter(
                chemical_inventory_schema::storage_location
                    .like(format!("%{}%", s)),
            )
        }

        Search::Exact(s) => {
            chemical_inventory_query = chemical_inventory_query
                .filter(chemical_inventory_schema::storage_location.eq(s))
        }

        Search::NoSearch => {}
    }

    match chemical_inventory_search.amount {
        Search::Partial(s) => {
            chemical_inventory_query = chemical_inventory_query.filter(
                chemical_inventory_schema::amount.like(format!("%{}%", s)),
            )
        }

        Search::Exact(s) => {
            chemical_inventory_query = chemical_inventory_query
                .filter(chemical_inventory_schema::amount.eq(s))
        }

        Search::NoSearch => {}
    }

    let found_entries = chemical_inventory_query
        .load::<ChemicalInventory>(database_connection)?;
    let inventory_list = ChemicalInventoryList {
        entries: found_entries,
    };

    Ok(inventory_list)
}

fn get_chemical_inventory(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<ChemicalInventory, WebdevError> {
    let mut found_inventory = chemical_inventory_schema::table
        .filter(chemical_inventory_schema::id.eq(id))
        .load::<ChemicalInventory>(database_connection)?;

    match found_inventory.pop() {
        Some(entry) => Ok(entry),
        None => Err(WebdevError::new(WebdevErrorKind::NotFound)),
    }
}

fn create_chemical_inventory(
    inventory: NewChemicalInventory,
    database_connection: &MysqlConnection,
) -> Result<ChemicalInventory, WebdevError> {
    diesel::insert_into(chemical_inventory_schema::table)
        .values(inventory)
        .execute(database_connection)?;

    no_arg_sql_function!(last_insert_id, Unsigned<types::Bigint>);

    let mut inserted_inventory_entries = chemical_inventory_schema::table
        .filter(chemical_inventory_schema::id.eq(last_insert_id))
        .load::<ChemicalInventory>(database_connection)?;

    if let Some(inserted_entry) = inserted_inventory_entries.pop() {
        Ok(inserted_entry)
    } else {
        Err(WebdevError::new(WebdevErrorKind::Database))
    }
}

fn update_chemical_inventory(
    id: u64,
    inventory: PartialChemicalInventory,
    database_connection: &MysqlConnection,
) -> Result<(), WebdevError> {
    diesel::update(chemical_inventory_schema::table)
        .filter(chemical_inventory_schema::id.eq(id))
        .set(&inventory)
        .execute(database_connection)?;
    Ok(())
}

fn delete_chemical_inventory(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), WebdevError> {
    diesel::delete(
        chemical_inventory_schema::table
            .filter(chemical_inventory_schema::id.eq(id)),
    )
    .execute(database_connection)?;

    Ok(())
}
