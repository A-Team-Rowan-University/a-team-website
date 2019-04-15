use crate::users::schema::users;

table! {
    chemical (id) {
        id -> Unsigned<Bigint>,
        name -> Varchar,
        purpose -> Varchar,
        company_name -> Varchar,
        ingredients -> Varchar,
        manual_link -> Varchar,
    }
}

table! {
    chemical_inventory (id) {
        id -> Unsigned<Bigint>,
        purchaser_id -> Unsigned<Bigint>,
        custodian_id -> Unsigned<Bigint>,
        chemical_id -> Unsigned<Bigint>,
        storage_location -> Varchar,
        amount -> Varchar,
    }
}

//Cant seem to do this because of multiple points to users, need explicit on clause in queries
//joinable!(chemical_inventory -> users (purchaser_id));
//joinable!(chemical_inventory -> users (custodian_id));
joinable!(chemical_inventory -> chemical (chemical_id));

allow_tables_to_appear_in_same_query!(
    chemical,
    chemical_inventory,
    users,
);
