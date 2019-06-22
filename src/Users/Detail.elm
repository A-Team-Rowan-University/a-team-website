module Users.Detail exposing (Msg, Response, State, init, update, view)

import Html exposing (Html, button, div, p, span, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Network exposing (Notification(..), RequestChange(..))
import Users.Users as Users


type alias Partial r =
    { r
        | first_name : Maybe String
        , last_name : Maybe String
        , banner_id : Maybe Int
        , email : Maybe String
    }


type alias State =
    { first_name : Maybe String
    , last_name : Maybe String
    , banner_id : Maybe Int
    , email : Maybe String
    , access_edits : Maybe Int
    }


init : State
init =
    { first_name = Nothing
    , last_name = Nothing
    , banner_id = Nothing
    , email = Nothing
    , access_edits = Nothing
    }


type Msg
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
    | RemoveAccess Users.Access
    | FinishRemoveAccess Int (Result Http.Error (Maybe Int))
    | RemovedAccess Int (Result Http.Error ())
    | Submit
    | Submitted (Result Http.Error ())


type alias Response =
    { state : State
    , cmd : Cmd Msg
    , requests : List RequestChange
    , reload : Bool
    , notifications : List Notification
    }


update :
    String -- ID Token
    -> State -- User detail state
    -> Msg -- User detail msg
    -> Users.Id -- id of the user being edited
    -> Response -- The response
update id_token state msg user_id =
    case msg of
        EditFirstName first_name ->
            { state = { state | first_name = Just first_name }
            , cmd = Cmd.none
            , requests = []
            , reload = False
            , notifications = []
            }

        ResetFirstName ->
            { state = { state | first_name = Nothing }
            , cmd = Cmd.none
            , requests = []
            , reload = False
            , notifications = []
            }

        EditLastName last_name ->
            { state = { state | last_name = Just last_name }
            , cmd = Cmd.none
            , requests = []
            , reload = False
            , notifications = []
            }

        ResetLastName ->
            { state = { state | last_name = Nothing }
            , cmd = Cmd.none
            , requests = []
            , reload = False
            , notifications = []
            }

        EditBannerId banner_id ->
            case banner_id of
                Just id ->
                    { state = { state | banner_id = Just id }
                    , cmd = Cmd.none
                    , requests = []
                    , reload = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = []
                    , reload = False
                    , notifications = []
                    }

        ResetBannerId ->
            { state = { state | banner_id = Nothing }
            , cmd = Cmd.none
            , requests = []
            , reload = False
            , notifications = []
            }

        EditEmail email ->
            { state = { state | email = Just email }
            , cmd = Cmd.none
            , requests = []
            , reload = False
            , notifications = []
            }

        ResetEmail ->
            { state = { state | email = Nothing }
            , cmd = Cmd.none
            , requests = []
            , reload = False
            , notifications = []
            }

        Submit ->
            { state = state
            , cmd =
                Http.request
                    { method = "PUT"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = Users.singleUrl user_id
                    , body = Http.jsonBody (partialEncoder state)
                    , expect = Http.expectWhatever Submitted
                    , timeout = Nothing
                    , tracker = Users.singleUrl user_id |> Just
                    }
            , requests = [ Users.singleUrl user_id |> AddRequest ]
            , reload = False
            , notifications = []
            }

        Submitted result ->
            case result of
                Ok _ ->
                    { state = init
                    , cmd = Cmd.none
                    , requests =
                        [ Users.singleUrl user_id
                            |> RemoveRequest
                        ]
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ Users.singleUrl user_id
                            |> RemoveRequest
                        ]
                    , reload = False
                    , notifications =
                        [ NError
                            "There was a network error submitting edits"
                        ]
                    }

        RemoveAccess access ->
            { state = state
            , cmd =
                Http.request
                    { method = "GET"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = Users.accessSearchUrl access.id user_id
                    , body = Http.emptyBody
                    , expect =
                        Http.expectJson
                            (FinishRemoveAccess access.id)
                            (Decode.map List.head Users.userAccessListDecoder)
                    , timeout = Nothing
                    , tracker =
                        Users.accessSearchUrl access.id user_id |> Just
                    }
            , requests =
                [ Users.accessSearchUrl access.id user_id
                    |> AddRequest
                ]
            , reload = False
            , notifications = []
            }

        FinishRemoveAccess access_id user_access_result ->
            case user_access_result of
                Ok (Just id) ->
                    { state = state
                    , cmd =
                        Http.request
                            { method = "DELETE"
                            , headers =
                                [ Http.header "id_token" id_token
                                ]
                            , url = Users.accessUrl access_id
                            , body = Http.emptyBody
                            , expect =
                                Http.expectWhatever
                                    (RemovedAccess access_id)
                            , timeout = Nothing
                            , tracker = Users.accessUrl access_id |> Just
                            }
                    , requests =
                        [ Users.accessSearchUrl access_id user_id
                            |> RemoveRequest
                        , Users.accessUrl access_id
                            |> AddRequest
                        ]
                    , reload = False
                    , notifications = []
                    }

                Ok Nothing ->
                    { state = { state | access_edits = Nothing }
                    , cmd = Cmd.none
                    , requests =
                        [ Users.accessSearchUrl access_id user_id
                            |> RemoveRequest
                        ]
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
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ Users.accessSearchUrl access_id user_id
                            |> RemoveRequest
                        ]
                    , reload = False
                    , notifications =
                        [ NError
                            """
                            There was a network error finding the access
                            to remove
                            """
                        ]
                    }

        RemovedAccess access_id result ->
            case result of
                Ok _ ->
                    { state = { state | access_edits = Nothing }
                    , cmd = Cmd.none
                    , requests =
                        [ Users.accessUrl access_id
                            |> RemoveRequest
                        ]
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ Users.accessUrl access_id
                            |> RemoveRequest
                        ]
                    , reload = False
                    , notifications =
                        [ NError
                            "There was a network error removing the access"
                        ]
                    }

        EditAccess access_id ->
            case access_id of
                Just id ->
                    { state = { state | access_edits = Just id }
                    , cmd = Cmd.none
                    , requests = []
                    , reload = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = []
                    , reload = False
                    , notifications = []
                    }

        AddAccess ->
            case state.access_edits of
                Just new_access ->
                    { state = state
                    , cmd =
                        Http.request
                            { method = "POST"
                            , headers =
                                [ Http.header "id_token" id_token
                                ]
                            , url = Users.accessAddUrl
                            , body =
                                Http.jsonBody
                                    (Encode.object
                                        [ ( "access_id", Encode.int new_access )
                                        , ( "user_id", Encode.int user_id )
                                        , ( "permission_level", Encode.null )
                                        ]
                                    )
                            , expect =
                                Http.expectWhatever
                                    (AddedAccess new_access)
                            , timeout = Nothing
                            , tracker = Users.accessAddUrl |> Just
                            }
                    , requests = [ Users.accessAddUrl |> AddRequest ]
                    , reload = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = []
                    , reload = False
                    , notifications = []
                    }

        AddedAccess new_access result ->
            case result of
                Ok _ ->
                    { state = init
                    , cmd = Cmd.none
                    , requests = [ Users.accessAddUrl |> RemoveRequest ]
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ Users.accessAddUrl |> RemoveRequest ]
                    , reload = False
                    , notifications =
                        [ NError
                            "There was a network error submitting edits"
                        ]
                    }


view :
    Users.User
    -> State
    -> Html Msg
view user state =
    div []
        [ p [ class "title has-text-centered" ]
            [ text (user.first_name ++ " " ++ user.last_name) ]
        , p [ class "columns" ]
            [ span [ class "column" ]
                [ p [ class "subtitle has-text-centered" ]
                    [ text "User Details" ]
                , div [ class "box" ]
                    [ span [] [ text "First Name: " ]
                    , Users.viewEditableText
                        user.first_name
                        state.first_name
                        EditFirstName
                        ResetFirstName
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Last Name: " ]
                    , Users.viewEditableText
                        user.last_name
                        state.last_name
                        EditLastName
                        ResetLastName
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Email: " ]
                    , Users.viewEditableText
                        user.email
                        state.email
                        EditEmail
                        ResetEmail
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Banner ID: " ]
                    , Users.viewEditableInt
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
                , div [ class "box" ] (List.map (Users.viewAccess RemoveAccess user) user.accesses)
                , Users.viewAddAccess state.access_edits EditAccess AddAccess
                ]
            ]
        ]


partialEncoder : Partial r -> Encode.Value
partialEncoder user =
    Encode.object
        ([]
            |> (\l ->
                    case user.first_name of
                        Just first_name ->
                            ( "first_name", Encode.string first_name ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case user.last_name of
                        Just last_name ->
                            ( "last_name", Encode.string last_name ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case user.banner_id of
                        Just banner_id ->
                            ( "banner_id", Encode.int banner_id ) :: l

                        Nothing ->
                            l
               )
            |> (\l ->
                    case user.email of
                        Just email ->
                            ( "email", Encode.string email ) :: l

                        Nothing ->
                            l
               )
        )
