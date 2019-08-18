module Users.Users exposing
    ( Id
    , Permission
    , User
    , decoder
    , listDecoder
    , manyUrl
    , permissionAddUrl
    , permissionSearchUrl
    , permissionUrl
    , singleUrl
    , userPermissionListDecoder
    , view
    , viewAddPermission
    , viewEditableInt
    , viewEditableText
    , viewList
    , viewPermission
    )

import Config exposing (..)
import Debug
import Dict exposing (Dict)
import Html exposing (Html, a, button, div, input, p, span, text)
import Html.Attributes exposing (class, href, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as D
import Json.Encode as E
import Network
    exposing
        ( Network(..)
        , RequestChange(..)
        , viewNetwork
        )
import Session exposing (Session, idToken)
import Set exposing (Set)
import Test
import Url.Builder as B


type alias Permission =
    { id : Int
    , permission_name : String
    }


type alias Id =
    Int


type alias User =
    { id : Id
    , first_name : String
    , last_name : String
    , email : String
    , banner_id : Int
    , permissions : List Permission
    }


manyUrl : String
manyUrl =
    B.relative [ apiUrl, "users/" ] []


singleUrl : Id -> String
singleUrl user_id =
    B.relative [ apiUrl, "users", String.fromInt user_id ] []


permissionSearchUrl : Int -> Id -> String
permissionSearchUrl permission_id user_id =
    B.relative [ apiUrl, "user_permission/" ]
        [ B.string "permission_id" ("exact," ++ String.fromInt permission_id)
        , B.string "user_id" ("exact," ++ String.fromInt user_id)
        ]


permissionUrl : Int -> String
permissionUrl permission_id =
    B.relative [ apiUrl, "user_permission", String.fromInt permission_id ] []


permissionAddUrl : String
permissionAddUrl =
    B.relative [ apiUrl, "user_permission/" ] []



-- BEGIN New User


viewList : Dict Id User -> Html msg
viewList users =
    div []
        [ p [ class "title has-text-centered" ] [ text "Users" ]
        , div [ class "columns" ]
            [ div [ class "column is-one-fifth" ]
                [ p [ class "title is-4 has-text-centered" ] [ text "Search" ]
                , p [ class "has-text-centered" ] [ text "Working on it :)" ]
                ]
            , div [ class "column" ]
                [ div [] (List.map view (Dict.values users))
                , a [ class "button is-primary", href "/users/new" ] [ text "New User" ]
                ]
            ]
        ]


view : User -> Html msg
view user =
    a
        [ class "box"
        , href (B.relative [ "users", String.fromInt user.id ] [])
        ]
        [ p [ class "title is-5" ]
            [ text (user.first_name ++ " " ++ user.last_name) ]
        , p [ class "subtitle is-5 columns" ]
            [ span [ class "column" ]
                [ text ("Email: " ++ user.email) ]
            , span [ class "column" ]
                [ text ("Banner ID: " ++ String.fromInt user.banner_id) ]
            ]
        ]


viewPermission : (Permission -> msg) -> User -> Permission -> Html msg
viewPermission onRemove user permission =
    div [ class "columns" ]
        [ span [ class "column" ]
            [ text
                (String.fromInt permission.id ++ ": " ++ permission.permission_name)
            ]
        , div [ class "column" ]
            [ button
                [ class "button is-danger is-pulled-right"
                , onClick (onRemove permission)
                ]
                [ text "Remove" ]
            ]
        ]


viewEditableText : String -> Maybe String -> (String -> msg) -> msg -> Html msg
viewEditableText defaultText editedText onEdit onReset =
    case editedText of
        Nothing ->
            p
                [ onClick (onEdit defaultText) ]
                [ text defaultText ]

        Just edited ->
            div [ class "field has-addons" ]
                [ div [ class "control" ]
                    [ input
                        [ class "input"
                        , value edited
                        , onInput onEdit
                        ]
                        []
                    ]
                , div [ class "control" ]
                    [ button
                        [ class "button is-danger"
                        , onClick onReset
                        ]
                        [ text "Reset" ]
                    ]
                ]


viewEditableInt : Int -> Maybe Int -> (Maybe Int -> msg) -> msg -> Html msg
viewEditableInt default edited onEdit onReset =
    case edited of
        Nothing ->
            p
                [ onClick (onEdit (Just default)) ]
                [ text (String.fromInt default) ]

        Just edit ->
            div [ class "field has-addons" ]
                [ div [ class "control" ]
                    [ input
                        [ class "input"
                        , value (String.fromInt edit)
                        , onInput (\s -> onEdit (String.toInt s))
                        , type_ "number"
                        ]
                        []
                    ]
                , div [ class "control" ]
                    [ button
                        [ class "button is-danger"
                        , onClick onReset
                        ]
                        [ text "Reset" ]
                    ]
                ]


viewAddPermission : Maybe Int -> (Maybe Int -> msg) -> msg -> Html msg
viewAddPermission permission_id onEdit onSubmit =
    case permission_id of
        Nothing ->
            button
                [ class "button is-primary", onClick (onEdit (Just 0)) ]
                [ text "Add" ]

        Just edit ->
            div [ class "field has-addons" ]
                [ div [ class "control" ]
                    [ input
                        [ class "input"
                        , value (String.fromInt edit)
                        , onInput (\s -> onEdit (String.toInt s))
                        , type_ "number"
                        ]
                        []
                    ]
                , div [ class "control" ]
                    [ button
                        [ class "button is-primary"
                        , onClick onSubmit
                        ]
                        [ text "Submit" ]
                    ]
                ]


decoder : D.Decoder User
decoder =
    D.map6 User
        (D.field "id" D.int)
        (D.field "first_name" D.string)
        (D.field "last_name" D.string)
        (D.field "email" D.string)
        (D.field "banner_id" D.int)
        (D.field "permissions" (D.list permissionDecoder))


listDecoder : D.Decoder (List User)
listDecoder =
    D.field "users" (D.list decoder)


permissionDecoder : D.Decoder Permission
permissionDecoder =
    D.map2 Permission
        (D.field "id" D.int)
        (D.field "permission_name" D.string)


userPermissionDecoder : D.Decoder Int
userPermissionDecoder =
    D.field "permission_id" D.int


userPermissionListDecoder : D.Decoder (List Int)
userPermissionListDecoder =
    D.field "entries" (D.list userPermissionDecoder)
