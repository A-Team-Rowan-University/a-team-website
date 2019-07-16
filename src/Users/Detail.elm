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
    , permission_edits : Maybe Int
    }


init : State
init =
    { first_name = Nothing
    , last_name = Nothing
    , banner_id = Nothing
    , email = Nothing
    , permission_edits = Nothing
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
    | EditPermission (Maybe Int)
    | AddPermission
    | AddedPermission Int (Result Http.Error ())
    | RemovePermission Users.Permission
    | FinishRemovePermission Int (Result Http.Error (Maybe Int))
    | RemovedPermission Int (Result Http.Error ())
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

        RemovePermission permission ->
            { state = state
            , cmd =
                Http.request
                    { method = "GET"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = Users.permissionSearchUrl permission.id user_id
                    , body = Http.emptyBody
                    , expect =
                        Http.expectJson
                            (FinishRemovePermission permission.id)
                            (Decode.map List.head Users.userPermissionListDecoder)
                    , timeout = Nothing
                    , tracker =
                        Users.permissionSearchUrl permission.id user_id |> Just
                    }
            , requests =
                [ Users.permissionSearchUrl permission.id user_id
                    |> AddRequest
                ]
            , reload = False
            , notifications = []
            }

        FinishRemovePermission permission_id user_permission_result ->
            case user_permission_result of
                Ok (Just id) ->
                    { state = state
                    , cmd =
                        Http.request
                            { method = "DELETE"
                            , headers =
                                [ Http.header "id_token" id_token
                                ]
                            , url = Users.permissionUrl permission_id
                            , body = Http.emptyBody
                            , expect =
                                Http.expectWhatever
                                    (RemovedPermission permission_id)
                            , timeout = Nothing
                            , tracker = Users.permissionUrl permission_id |> Just
                            }
                    , requests =
                        [ Users.permissionSearchUrl permission_id user_id
                            |> RemoveRequest
                        , Users.permissionUrl permission_id
                            |> AddRequest
                        ]
                    , reload = False
                    , notifications = []
                    }

                Ok Nothing ->
                    { state = { state | permission_edits = Nothing }
                    , cmd = Cmd.none
                    , requests =
                        [ Users.permissionSearchUrl permission_id user_id
                            |> RemoveRequest
                        ]
                    , reload = True
                    , notifications =
                        [ NWarning
                            """
                            The user permission dissapeared while I was
                            trying to remove it! Strange, but probably
                            fine
                            """
                        ]
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ Users.permissionSearchUrl permission_id user_id
                            |> RemoveRequest
                        ]
                    , reload = False
                    , notifications =
                        [ NError
                            """
                            There was a network error finding the permission
                            to remove
                            """
                        ]
                    }

        RemovedPermission permission_id result ->
            case result of
                Ok _ ->
                    { state = { state | permission_edits = Nothing }
                    , cmd = Cmd.none
                    , requests =
                        [ Users.permissionUrl permission_id
                            |> RemoveRequest
                        ]
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests =
                        [ Users.permissionUrl permission_id
                            |> RemoveRequest
                        ]
                    , reload = False
                    , notifications =
                        [ NError
                            "There was a network error removing the permission"
                        ]
                    }

        EditPermission permission_id ->
            case permission_id of
                Just id ->
                    { state = { state | permission_edits = Just id }
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

        AddPermission ->
            case state.permission_edits of
                Just new_permission ->
                    { state = state
                    , cmd =
                        Http.request
                            { method = "POST"
                            , headers =
                                [ Http.header "id_token" id_token
                                ]
                            , url = Users.permissionAddUrl
                            , body =
                                Http.jsonBody
                                    (Encode.object
                                        [ ( "permission_id", Encode.int new_permission )
                                        , ( "user_id", Encode.int user_id )
                                        , ( "permission_level", Encode.null )
                                        ]
                                    )
                            , expect =
                                Http.expectWhatever
                                    (AddedPermission new_permission)
                            , timeout = Nothing
                            , tracker = Users.permissionAddUrl |> Just
                            }
                    , requests = [ Users.permissionAddUrl |> AddRequest ]
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

        AddedPermission new_permission result ->
            case result of
                Ok _ ->
                    { state = init
                    , cmd = Cmd.none
                    , requests = [ Users.permissionAddUrl |> RemoveRequest ]
                    , reload = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ Users.permissionAddUrl |> RemoveRequest ]
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
                , div [ class "box" ] (List.map (Users.viewPermission RemovePermission user) user.permissions)
                , Users.viewAddPermission state.permission_edits EditPermission AddPermission
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
