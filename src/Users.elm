module Users exposing (Access, NewUser, NewUserConfig, PartialUser, User, UserDetailConfig, UserId, viewAccess, viewAddUserAccess, viewEditableInt, viewEditableText, viewNewUser, viewUser, viewUserDetail, viewUserList)

import Dict exposing (Dict)
import Html exposing (Html, a, button, div, input, p, span, text)
import Html.Attributes exposing (class, href, type_, value)
import Html.Events exposing (onClick, onInput)
import Network exposing (..)
import Url.Builder as B


type alias Access =
    { id : Int
    , access_name : String
    }


type alias UserId =
    Int


type alias User =
    { id : UserId
    , first_name : String
    , last_name : String
    , email : String
    , banner_id : Int
    , accesses : List Access
    }


type alias NewUser =
    { first_name : String
    , last_name : String
    , banner_id : Int
    , email : String
    , accesses : List Int
    }


type alias PartialUser =
    { first_name : Maybe String
    , last_name : Maybe String
    , banner_id : Maybe Int
    , email : Maybe String
    }


type alias UsersPageState r =
    { r
        | users : Dict UserId User
        , edit_user : PartialUser
        , edit_user_new_access : Maybe Int
        , new_user : NewUser
        , new_user_new_access : Maybe Int
    }


viewUser : User -> Html msg
viewUser user =
    a [ class "box", href (B.relative [ "users", String.fromInt user.id ] []) ]
        [ p [ class "title is-5" ] [ text (user.first_name ++ " " ++ user.last_name) ]
        , p [ class "subtitle is-5 columns" ]
            [ span [ class "column" ]
                [ text ("Email: " ++ user.email) ]
            , span [ class "column" ]
                [ text ("Banner ID: " ++ String.fromInt user.banner_id) ]
            ]
        ]


viewAccess : (Access -> msg) -> User -> Access -> Html msg
viewAccess onRemove user access =
    div [ class "columns" ]
        [ span [ class "column" ] [ text (String.fromInt access.id ++ ": " ++ access.access_name) ]
        , div [ class "column" ]
            [ button
                [ class "button is-danger is-pulled-right"
                , onClick (onRemove access)
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


viewAddUserAccess : Maybe Int -> (Maybe Int -> msg) -> msg -> Html msg
viewAddUserAccess access_id onEdit onSubmit =
    case access_id of
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


type alias NewUserConfig msg =
    { onEditFirstName : String -> msg
    , onEditLastName : String -> msg
    , onEditEmail : String -> msg
    , onEditBannerId : Maybe Int -> msg
    , onEditAccess : Maybe Int -> msg
    , onAddAccess : msg
    , onRemoveAccess : Int -> msg
    , onSubmit : msg
    }


viewNewUser :
    NewUserConfig msg
    -> NewUser
    -> Maybe Int
    -> Html msg
viewNewUser config user access_id =
    div []
        [ p [ class "title has-text-centered" ]
            [ text "New User" ]
        , p [ class "columns" ]
            [ span [ class "column" ]
                [ p [ class "subtitle has-text-centered" ] [ text "User Details" ]
                , div [ class "box" ]
                    [ span [] [ text "First Name: " ]
                    , input
                        [ class "input"
                        , value user.first_name
                        , onInput config.onEditFirstName
                        ]
                        []
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Last Name: " ]
                    , input
                        [ class "input"
                        , value user.last_name
                        , onInput config.onEditLastName
                        ]
                        []
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Email: " ]
                    , input
                        [ class "input"
                        , value user.email
                        , onInput config.onEditEmail
                        ]
                        []
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Banner ID: " ]
                    , input
                        [ class "input"
                        , type_ "number"
                        , value (String.fromInt user.banner_id)
                        , onInput (\s -> String.toInt s |> config.onEditBannerId)
                        ]
                        []
                    ]
                , button
                    [ class "button is-primary"
                    , onClick config.onSubmit
                    ]
                    [ text "Submit new user" ]
                ]
            , div [ class "column" ]
                [ p [ class "subtitle has-text-centered" ] [ text "User Permissions" ]
                , div [ class "box" ]
                    (List.map
                        (\id ->
                            div [ class "columns" ]
                                [ span [ class "column" ] [ String.fromInt id |> text ]
                                , div [ class "column" ]
                                    [ button
                                        [ class "button is-danger is-pulled-right"
                                        , onClick (config.onRemoveAccess id)
                                        ]
                                        [ text "Remove" ]
                                    ]
                                ]
                        )
                        user.accesses
                    )
                , viewAddUserAccess access_id config.onEditAccess config.onAddAccess
                ]
            ]
        ]


type alias UserDetailConfig msg =
    { onEditFirstName : String -> msg
    , onResetFirstName : msg
    , onEditLastName : String -> msg
    , onResetLastName : msg
    , onEditEmail : String -> msg
    , onResetEmail : msg
    , onEditBannerId : Maybe Int -> msg
    , onResetBannerId : msg
    , onEditAccess : Maybe Int -> msg
    , onAddAccess : msg
    , onRemoveAccess : Access -> msg
    , onSubmit : msg
    }


viewUserDetail :
    UserDetailConfig msg
    -> User
    -> PartialUser
    -> Maybe Int
    -> Network ()
    -> Html msg
viewUserDetail config user user_edit user_access users_status =
    div []
        [ viewNetwork (\a -> div [] []) users_status
        , p [ class "title has-text-centered" ]
            [ text (user.first_name ++ " " ++ user.last_name) ]
        , p [ class "columns" ]
            [ span [ class "column" ]
                [ p [ class "subtitle has-text-centered" ] [ text "User Details" ]
                , div [ class "box" ]
                    [ span [] [ text "First Name: " ]
                    , viewEditableText
                        user.first_name
                        user_edit.first_name
                        config.onEditFirstName
                        config.onResetFirstName
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Last Name: " ]
                    , viewEditableText
                        user.last_name
                        user_edit.last_name
                        config.onEditLastName
                        config.onResetLastName
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Email: " ]
                    , viewEditableText
                        user.email
                        user_edit.email
                        config.onEditEmail
                        config.onResetEmail
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Banner ID: " ]
                    , viewEditableInt
                        user.banner_id
                        user_edit.banner_id
                        config.onEditBannerId
                        config.onResetBannerId
                    ]
                , button
                    [ class "button is-primary"
                    , onClick config.onSubmit
                    ]
                    [ text "Submit edits" ]
                ]
            , div [ class "column" ]
                [ p [ class "subtitle has-text-centered" ] [ text "User Permissions" ]
                , div [ class "box" ] (List.map (viewAccess config.onRemoveAccess user) user.accesses)
                , viewAddUserAccess user_access config.onEditAccess config.onAddAccess
                ]
            ]
        ]


viewUserList : Dict UserId User -> Network () -> Html msg
viewUserList users users_status =
    div []
        [ viewNetwork (\a -> div [] []) users_status
        , p [ class "title has-text-centered" ] [ text "Users" ]
        , div [ class "columns" ]
            [ div [ class "column is-one-fifth" ]
                [ p [ class "title is-4 has-text-centered" ] [ text "Search" ]
                , p [ class "has-text-centered" ] [ text "Working on it :)" ]
                ]
            , div [ class "column" ]
                [ div [] (List.map viewUser (Dict.values users))
                , a [ class "button is-primary", href "/users/new" ] [ text "New User" ]
                ]
            ]
        ]
