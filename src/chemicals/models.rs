use diesel::Queryable;

use rouille::router;

use serde::Deserialize;
use serde::Serialize;

use url::form_urlencoded;

use log::warn;

use crate::errors::{Error, ErrorKind};

use crate::search::Search;

use super::schema::{chemical, chemical_inventory};

#[derive(Queryable, Serialize, Deserialize)]
pub struct Chemical {
    pub id: u64,
    pub name: String,
    pub purpose: String,
    pub company_name: String,
    pub ingredients: String,
    pub manual_link: String,
}

#[derive(Insertable, Serialize, Deserialize)]
#[table_name = "chemical"]
pub struct NewChemical {
    pub name: String,
    pub purpose: String,
    pub company_name: String,
    pub ingredients: String,
    pub manual_link: String,
}

#[derive(AsChangeset, Serialize, Deserialize)]
#[table_name = "chemical"]
pub struct PartialChemical {
    pub name: Option<String>,
    pub purpose: Option<String>,
    pub company_name: Option<String>,
    pub ingredients: Option<String>,
    pub manual_link: Option<String>,
}

pub struct SearchChemical {
    pub name: Search<String>,
    pub purpose: Search<String>,
    pub company_name: Search<String>,
    pub ingredients: Search<String>,
    pub manual_link: Search<String>,
}

#[derive(Serialize, Deserialize)]
pub struct ChemicalList {
    pub chemicals: Vec<Chemical>,
}

pub enum ChemicalRequest {
    Search(SearchChemical),
    GetChemical(u64),            //id of access name searched
    CreateChemical(NewChemical), //new access type of some name to be created
    UpdateChemical(u64, PartialChemical), //Contains id to be changed to new access_name
    DeleteChemical(u64),                  //if of access to be deleted
}

impl ChemicalRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<ChemicalRequest, Error> {
        let url_queries =
            form_urlencoded::parse(request.raw_query_string().as_bytes());

        router!(request,
            (GET) (/) => {
                let mut name_search = Search::NoSearch;
                let mut purpose_search = Search::NoSearch;
                let mut company_name_search = Search::NoSearch;
                let mut ingredients_search = Search::NoSearch;
                let mut manual_link_search = Search::NoSearch;

                for (field, query) in url_queries {
                    match field.as_ref() as &str {
                        "name" => name_search = Search::from_query(query.as_ref())?,
                        "purpose" => purpose_search = Search::from_query(query.as_ref())?,
                        "company_name" => company_name_search = Search::from_query(query.as_ref())?,
                        "ingredients" => ingredients_search = Search::from_query(query.as_ref())?,
                        "manual_link" => manual_link_search = Search::from_query(query.as_ref())?,
                        _ => return Err(Error::new(ErrorKind::Url)),
                    }
                }

                Ok(ChemicalRequest::Search(SearchChemical {
                    name: name_search,
                    purpose: purpose_search,
                    company_name: company_name_search,
                    ingredients: ingredients_search,
                    manual_link: manual_link_search,
                }))
            },

            (GET) (/{id: u64}) => {
                Ok(ChemicalRequest::GetChemical(id))
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let new_chemical: NewChemical = serde_json::from_reader(request_body)?;

                Ok(ChemicalRequest::CreateChemical(new_chemical))
            },

            (POST) (/{id: u64}) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let update_chemical: PartialChemical = serde_json::from_reader(request_body)?;

                Ok(ChemicalRequest::UpdateChemical(id, update_chemical))
            },

            (DELETE) (/{id: u64}) => {
                Ok(ChemicalRequest::DeleteChemical(id))
            },

            _ => {
                warn!("Could not create a chemical request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        ) //end router
    }
}

pub enum ChemicalResponse {
    OneChemical(Chemical),
    ManyChemical(ChemicalList),
    NoResponse,
}

impl ChemicalResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            ChemicalResponse::OneChemical(chemical) => {
                rouille::Response::json(&chemical)
            }
            ChemicalResponse::ManyChemical(chemicals) => {
                rouille::Response::json(&chemicals)
            }
            ChemicalResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}

#[derive(Queryable, Serialize, Deserialize)]
pub struct ChemicalInventory {
    pub id: u64,
    pub purchaser_id: u64,
    pub custodian_id: u64,
    pub chemical_id: u64,
    pub storage_location: String,
    pub amount: String,
}

#[derive(Insertable, Serialize, Deserialize)]
#[table_name = "chemical_inventory"]
pub struct NewChemicalInventory {
    pub purchaser_id: u64,
    pub custodian_id: u64,
    pub chemical_id: u64,
    pub storage_location: String,
    pub amount: String,
}

#[derive(AsChangeset, Serialize, Deserialize)]
#[table_name = "chemical_inventory"]
pub struct PartialChemicalInventory {
    pub purchaser_id: Option<u64>,
    pub custodian_id: Option<u64>,
    pub chemical_id: Option<u64>,
    pub storage_location: Option<String>,
    pub amount: Option<String>,
}

pub struct SearchChemicalInventory {
    pub purchaser_id: Search<u64>,
    pub custodian_id: Search<u64>,
    pub chemical_id: Search<u64>,
    pub storage_location: Search<String>,
    pub amount: Search<String>,
}

#[derive(Serialize, Deserialize)]
pub struct ChemicalInventoryList {
    pub entries: Vec<ChemicalInventory>,
}

pub enum ChemicalInventoryRequest {
    SearchInventory(SearchChemicalInventory),
    GetInventory(u64),
    CreateInventory(NewChemicalInventory),
    UpdateInventory(u64, PartialChemicalInventory),
    DeleteInventory(u64),
}

impl ChemicalInventoryRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<ChemicalInventoryRequest, Error> {
        let url_queries =
            form_urlencoded::parse(request.raw_query_string().as_bytes());

        router!(request,
            (GET) (/) => {
                let mut purchaser_id_search = Search::NoSearch;
                let mut custodian_id_search = Search::NoSearch;
                let mut chemical_id_search = Search::NoSearch;
                let mut storage_location_search = Search::NoSearch;
                let mut amount_search = Search::NoSearch;

                for (field, query) in url_queries {
                    match field.as_ref() as &str {
                        "purchaser_id" => purchaser_id_search =
                            Search::from_query(query.as_ref())?,
                        "custodian_id" => custodian_id_search =
                            Search::from_query(query.as_ref())?,
                        "chemical_id" => chemical_id_search =
                            Search::from_query(query.as_ref())?,
                        "storage_location" => storage_location_search
                            = Search::from_query(query.as_ref())?,
                        "amount" => amount_search = Search::from_query(query.as_ref())?,
                        _ => return Err(Error::new(ErrorKind::Url)),
                    }
                }

                Ok(ChemicalInventoryRequest::SearchInventory(SearchChemicalInventory {
                    purchaser_id: purchaser_id_search,
                    custodian_id: custodian_id_search,
                    chemical_id: chemical_id_search,
                    storage_location: storage_location_search,
                    amount: amount_search,
                }))
            },

            (GET) (/{permission_id: u64}) => {
                Ok(ChemicalInventoryRequest::GetInventory(permission_id))
            },

            (POST) (/) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let new_chemical_inventory: NewChemicalInventory =
                    serde_json::from_reader(request_body)?;
                Ok(ChemicalInventoryRequest::CreateInventory(new_chemical_inventory))
            },

            (PUT) (/{id: u64}) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let update_chemical_inventory: PartialChemicalInventory =
                    serde_json::from_reader(request_body)?;

                Ok(ChemicalInventoryRequest::UpdateInventory(
                        id,
                        update_chemical_inventory
                ))
            },

            (DELETE) (/{id: u64}) => {
                Ok(ChemicalInventoryRequest::DeleteInventory(id))
            },

            _ => {
                warn!("Could not create a chemical inventory request");
                Err(Error::new(ErrorKind::NotFound))
            }
        ) //end router
    }
}

pub enum ChemicalInventoryResponse {
    OneInventoryEntry(ChemicalInventory),
    ManyInventoryEntries(ChemicalInventoryList),
    NoResponse,
}

impl ChemicalInventoryResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            ChemicalInventoryResponse::OneInventoryEntry(entry) => {
                rouille::Response::json(&entry)
            }
            ChemicalInventoryResponse::ManyInventoryEntries(entries) => {
                rouille::Response::json(&entries)
            }
            ChemicalInventoryResponse::NoResponse => {
                rouille::Response::empty_204()
            }
        }
    }
}
