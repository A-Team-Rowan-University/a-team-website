module Users exposing
    ( Access
    , DetailMsg
    , DetailState
    , Id
    , New
    , NewConfig
    , Partial
    , User
    , decoder
    , initDetail
    , listDecoder
    , newEncoder
    , updateDetail
    , view
    , viewAccess
    , viewAddAccess
    , viewDetail
    , viewEditableInt
    , viewEditableText
    , viewList
    , viewNew
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
        , Notification(..)
        , RequestChange(..)
        , viewNetwork
        )
import Session exposing (Session, idToken)
import Test
import Url.Builder as B


type alias Access =
    { id : Int
    , access_name : String
    }


type alias Id =
    Int


type alias User =
    { id : Id
    , first_name : String
    , last_name : String
    , email : String
    , banner_id : Int
    , accesses : List Access
    }


type alias New =
    { first_name : String
    , last_name : String
    , banner_id : Int
    , email : String
    , accesses : List Int
    }


type alias Partial r =
    { r
        | first_name : Maybe String
        , last_name : Maybe String
        , banner_id : Maybe Int
        , email : Maybe String
    }



-- BEGIN New User


type alias NewConfig msg =
    { onEditFirstName : String -> msg
    , onEditLastName : String -> msg
    , onEditEmail : String -> msg
    , onEditBannerId : Maybe Int -> msg
    , onEditAccess : Maybe Int -> msg
    , onAddAccess : msg
    , onRemoveAccess : Int -> msg
    , onSubmit : msg
    }


viewNew :
    NewConfig msg
    -> New
    -> Maybe Int
    -> Html msg
viewNew config user access_id =
    div []
        [ p [ class "title has-text-centered" ]
            [ text "New User" ]
        , p [ class "columns" ]
            [ span [ class "column" ]
                [ p [ class "subtitle has-text-centered" ]
                    [ text "User Details" ]
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
                        , onInput
                            (\s -> String.toInt s |> config.onEditBannerId)
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
                [ p [ class "subtitle has-text-centered" ]
                    [ text "User Permissions" ]
                , div [ class "box" ]
                    (List.map
                        (\id ->
                            div [ class "columns" ]
                                [ span [ class "column" ]
                                    [ String.fromInt id |> text ]
                                , div [ class "column" ]
                                    [ button
                                        [ class
                                            "button is-danger is-pulled-right"
                                        , onClick
                                            (config.onRemoveAccess id)
                                        ]
                                        [ text "Remove" ]
                                    ]
                                ]
                        )
                        user.accesses
                    )
                , viewAddAccess
                    access_id
                    config.onEditAccess
                    config.onAddAccess
                ]
            ]
        ]



-- END New User
-- BEGIN User Detail


type alias DetailState =
    { first_name : Maybe String
    , last_name : Maybe String
    , banner_id : Maybe Int
    , email : Maybe String
    , access_edits : Maybe Int
    , error : Maybe String
    }


initDetail : DetailState
initDetail =
    { first_name = Nothing
    , last_name = Nothing
    , banner_id = Nothing
    , email = Nothing
    , access_edits = Nothing
    , error = Nothing
    }


type DetailMsg
    = EditFirstName String
    | ResetFirstName
    | EditLastName String
    | ResetLastName
    | EditEmail String
    | ResetEmail
    | EditBannerId (Maybe Int)
    | ResetBannerId
    | EditAccess (Maybe Int)
    | AddAccess
    | AddedAccess Int (Result Http.Error ())
    | RemoveAccess Access
    | FinishRemoveAccess Int (Result Http.Error (Maybe Int))
    | RemovedAccess (Result Http.Error ())
    | Submit
    | Submitted (Result Http.Error ())


type alias DetailResponse =
    { state : DetailState
    , cmd : Cmd DetailMsg
    , request : Maybe RequestChange
    , reload : Bool
    , notifications : List Notification
    }


updateDetail :
    String
    -> DetailState
    -> DetailMsg
    -> Id
    -> DetailResponse
updateDetail id_token state msg user_id =
    case msg of
        EditFirstName first_name ->
            { state = { state | first_name = Just first_name }
            , cmd = Cmd.none
            , request = Nothing
            , reload = False
            , notifications = []
            }

        ResetFirstName ->
            { state = { state | first_name = Nothing }
            , cmd = Cmd.none
            , request = Nothing
            , reload = False
            , notifications = []
            }

        EditLastName last_name ->
            { state = { state | last_name = Just last_name }
            , cmd = Cmd.none
            , request = Nothing
            , reload = False
            , notifications = []
            }

        ResetLastName ->
            { state = { state | last_name = Nothing }
            , cmd = Cmd.none
            , request = Nothing
            , reload = False
            , notifications = []
            }

        EditBannerId banner_id ->
            case banner_id of
                Just id ->
                    { state = { state | banner_id = Just id }
                    , cmd = Cmd.none
                    , request = Nothing
                    , reload = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , request = Nothing
                    , reload = False
                    , notifications = []
                    }

        ResetBannerId ->
            { state = { state | banner_id = Nothing }
            , cmd = Cmd.none
            , request = Nothing
            , reload = False
            , notifications = []
            }

        EditEmail email ->
            { state = { state | email = Just email }
            , cmd = Cmd.none
            , request = Nothing
            , reload = False
            , notifications = []
            }

        ResetEmail ->
            { state = { state | email = Nothing }
            , cmd = Cmd.none
            , request = Nothing
            , reload = False
            , notifications = []
            }

        Submit ->
            let
                tracker =
                    "edit user " ++ String.fromInt user_id
            in
            { state = state
            , cmd =
                Http.request
                    { method = "PUT"
                    , headers = [ Http.header "id_token" id_token ]
                    , url =
                        B.relative
                            [ apiUrl
                            , "users"
                            , String.fromInt user_id
                            ]
                            []
                    , body = Http.jsonBody (partialEncoder state)
                    , expect = Http.expectWhatever Submitted
                    , timeout = Nothing
                    , tracker = Just tracker
                    }
            , request = Just (AddRequest tracker)
            , reload = False
            , notifications = []
            }

        Submitted result ->
            let
                tracker =
                    "edit user " ++ String.fromInt user_id
            in
            case result of
                Ok _ ->
                    { state = initDetail
                    , cmd = Cmd.none
                    , request = Just (RemoveRequest tracker)
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , request = Just (RemoveRequest tracker)
                    , reload = False
                    , notifications =
                        [ NError
                            "There was a network error submitting edits"
                        ]
                    }

        RemoveAccess access ->
            let
                tracker =
                    "find user access "
                        ++ String.fromInt access.id
                        ++ " "
                        ++ String.fromInt user_id
            in
            { state = state
            , cmd =
                Http.request
                    { method = "GET"
                    , headers = [ Http.header "id_token" id_token ]
                    , url =
                        B.relative [ apiUrl, "user_access/" ]
                            [ B.string "access_id"
                                ("exact," ++ String.fromInt access.id)
                            , B.string "user_id"
                                ("exact," ++ String.fromInt user_id)
                            ]
                    , body = Http.emptyBody
                    , expect =
                        Http.expectJson
                            (FinishRemoveAccess access.id)
                            (D.map List.head userAccessListDecoder)
                    , timeout = Nothing
                    , tracker = Just tracker
                    }
            , request = Just (AddRequest tracker)
            , reload = False
            , notifications = []
            }

        FinishRemoveAccess access_id user_access_result ->
            case user_access_result of
                Ok (Just id) ->
                    let
                        tracker =
                            "remove user access " ++ String.fromInt id
                    in
                    { state = state
                    , cmd =
                        Http.request
                            { method = "DELETE"
                            , headers = [ Http.header "id_token" id_token ]
                            , url =
                                B.relative
                                    [ apiUrl
                                    , "user_access"
                                    , String.fromInt id
                                    ]
                                    []
                            , body = Http.emptyBody
                            , expect = Http.expectWhatever RemovedAccess
                            , timeout = Nothing
                            , tracker = Just tracker
                            }
                    , request = Just (AddRequest tracker)
                    , reload = False
                    , notifications = []
                    }

                Ok Nothing ->
                    let
                        tracker =
                            "find user access "
                                ++ String.fromInt access_id
                                ++ " "
                                ++ String.fromInt user_id
                    in
                    { state = { state | access_edits = Nothing }
                    , cmd = Cmd.none
                    , request = Just (RemoveRequest tracker)
                    , reload = True
                    , notifications =
                        [ NWarning
                            """
                            The user access dissapeared while I was
                            trying to remove it! Strange, but probably
                            fine
                            """
                        ]
                    }

                Err e ->
                    let
                        tracker =
                            "find user access "
                                ++ String.fromInt access_id
                                ++ " "
                                ++ String.fromInt user_id
                    in
                    { state = state
                    , cmd = Cmd.none
                    , request = Just (RemoveRequest tracker)
                    , reload = False
                    , notifications =
                        [ NError
                            """
                            There was a network error finding the access
                            to remove
                            """
                        ]
                    }

        RemovedAccess result ->
            let
                tracker =
                    "edit user " ++ String.fromInt user_id
            in
            case result of
                Ok _ ->
                    { state = { state | access_edits = Nothing }
                    , cmd = Cmd.none
                    , request = Just (RemoveRequest tracker)
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , request = Just (RemoveRequest tracker)
                    , reload = False
                    , notifications =
                        [ NError
                            "There was a network error submitting edits"
                        ]
                    }

        EditAccess access_id ->
            case access_id of
                Just id ->
                    { state = { state | access_edits = Just id }
                    , cmd = Cmd.none
                    , request = Nothing
                    , reload = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , request = Nothing
                    , reload = False
                    , notifications = []
                    }

        AddAccess ->
            case state.access_edits of
                Just new_access ->
                    let
                        tracker =
                            "add access "
                                ++ String.fromInt new_access
                                ++ " "
                                ++ String.fromInt user_id
                    in
                    { state = state
                    , cmd =
                        Http.request
                            { method = "POST"
                            , headers = [ Http.header "id_token" id_token ]
                            , url = B.relative [ apiUrl, "user_access/" ] []
                            , body =
                                Http.jsonBody
                                    (E.object
                                        [ ( "access_id", E.int new_access )
                                        , ( "user_id", E.int user_id )
                                        , ( "permission_level", E.null )
                                        ]
                                    )
                            , expect =
                                Http.expectWhatever
                                    (AddedAccess new_access)
                            , timeout = Nothing
                            , tracker = Just tracker
                            }
                    , request = Just (AddRequest tracker)
                    , reload = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , request = Nothing
                    , reload = False
                    , notifications = []
                    }

        AddedAccess new_access result ->
            let
                tracker =
                    "add access "
                        ++ String.fromInt new_access
                        ++ " "
                        ++ String.fromInt user_id
            in
            case result of
                Ok _ ->
                    { state = initDetail
                    , cmd = Cmd.none
                    , request = Just (RemoveRequest tracker)
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , request = Just (RemoveRequest tracker)
                    , reload = False
                    , notifications =
                        [ NError
                            "There was a network error submitting edits"
                        ]
                    }


viewDetail :
    User
    -> DetailState
    -> Html DetailMsg
viewDetail user state =
    div []
        [ p [ class "title has-text-centered" ]
            [ text (user.first_name ++ " " ++ user.last_name) ]
        , p [ class "columns" ]
            [ span [ class "column" ]
                [ p [ class "subtitle has-text-centered" ]
                    [ text "User Details" ]
                , div [ class "box" ]
                    [ span [] [ text "First Name: " ]
                    , viewEditableText
                        user.first_name
                        state.first_name
                        EditFirstName
                        ResetFirstName
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Last Name: " ]
                    , viewEditableText
                        user.last_name
                        state.last_name
                        EditLastName
                        ResetLastName
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Email: " ]
                    , viewEditableText
                        user.email
                        state.email
                        EditEmail
                        ResetEmail
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Banner ID: " ]
                    , viewEditableInt
                        user.banner_id
                        state.banner_id
                        EditBannerId
                        ResetBannerId
                    ]
                , button
                    [ class "button is-primary"
                    , onClick Submit
                    ]
                    [ text "Submit edits" ]
                ]
            , div [ class "column" ]
                [ p [ class "subtitle has-text-centered" ] [ text "User Permissions" ]
                , div [ class "box" ] (List.map (viewAccess RemoveAccess user) user.accesses)
                , viewAddAccess state.access_edits EditAccess AddAccess
                ]
            ]
        ]


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


viewAddAccess : Maybe Int -> (Maybe Int -> msg) -> msg -> Html msg
viewAddAccess access_id onEdit onSubmit =
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


decoder : D.Decoder User
decoder =
    D.map6 User
        (D.field "id" D.int)
        (D.field "first_name" D.string)
        (D.field "last_name" D.string)
        (D.field "email" D.string)
        (D.field "banner_id" D.int)
        (D.field "accesses" (D.list accessDecoder))


listDecoder : D.Decoder (List User)
listDecoder =
    D.field "users" (D.list decoder)


accessDecoder : D.Decoder Access
accessDecoder =
    D.map2 Access
        (D.field "id" D.int)
        (D.field "access_name" D.string)


userAccessDecoder : D.Decoder Int
userAccessDecoder =
    D.field "permission_id" D.int


userAccessListDecoder : D.Decoder (List Int)
userAccessListDecoder =
    D.field "entries" (D.list userAccessDecoder)


partialEncoder : Partial r -> E.Value
partialEncoder user =
    E.object
        ([]
            |> (\l ->
                    case user.first_name of
                        Just first_name ->
                            ( "first_name", E.string first_name ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case user.last_name of
                        Just last_name ->
                            ( "last_name", E.string last_name ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case user.banner_id of
                        Just banner_id ->
                            ( "banner_id", E.int banner_id ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case user.email of
                        Just email ->
                            ( "email", E.string email ) :: l

                        Nothing ->
                            l
               )
        )


newEncoder : New -> E.Value
newEncoder user =
    E.object
        [ ( "first_name", E.string user.first_name )
        , ( "last_name", E.string user.last_name )
        , ( "banner_id", E.int user.banner_id )
        , ( "email", E.string user.email )
        , ( "accesses", E.list E.int user.accesses )
        ]
