module Users.New exposing (Msg, State, init, update, view)

import Html exposing (Html, button, div, input, p, span, text)
import Html.Attributes exposing (class, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Encode
import Network exposing (Notification(..), RequestChange(..))
import Set exposing (Set)
import Users.Users as User


type alias NewUser r =
    { r
        | first_name : String
        , last_name : String
        , banner_id : Int
        , email : String
        , permissions : Set Int
    }


type alias State =
    { first_name : String
    , last_name : String
    , banner_id : Int
    , email : String
    , permissions : Set Int
    , permission_edits : Maybe Int
    }


init : State
init =
    { first_name = ""
    , last_name = ""
    , banner_id = 0
    , email = ""
    , permissions = Set.empty
    , permission_edits = Nothing
    }


type Msg
    = EditFirstName String
    | EditLastName String
    | EditEmail String
    | EditBannerId (Maybe Int)
    | EditPermission (Maybe Int)
    | AddPermission
    | RemovePermission Int
    | Submit
    | Submitted (Result Http.Error ())


type alias Response =
    { state : State
    , cmd : Cmd Msg
    , requests : List RequestChange
    , done : Bool
    , notifications : List Notification
    }


update : String -> State -> Msg -> Response
update id_token state msg =
    case msg of
        EditFirstName first_name ->
            { state = { state | first_name = first_name }
            , cmd = Cmd.none
            , requests = []
            , done = False
            , notifications = []
            }

        EditLastName last_name ->
            { state = { state | last_name = last_name }
            , cmd = Cmd.none
            , requests = []
            , done = False
            , notifications = []
            }

        EditBannerId banner_id ->
            case banner_id of
                Just id ->
                    { state = { state | banner_id = id }
                    , cmd = Cmd.none
                    , requests = []
                    , done = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = []
                    , done = False
                    , notifications = []
                    }

        EditEmail email ->
            { state = { state | email = email }
            , cmd = Cmd.none
            , requests = []
            , done = False
            , notifications = []
            }

        EditPermission permission_id ->
            case permission_id of
                Just id ->
                    { state = { state | permission_edits = Just id }
                    , cmd = Cmd.none
                    , requests = []
                    , done = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = []
                    , done = False
                    , notifications = []
                    }

        AddPermission ->
            case state.permission_edits of
                Just permission_id ->
                    { state =
                        { state
                            | permissions =
                                Set.insert
                                    permission_id
                                    state.permissions
                            , permission_edits = Nothing
                        }
                    , cmd = Cmd.none
                    , requests = []
                    , done = False
                    , notifications = []
                    }

                Nothing ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = []
                    , done = False
                    , notifications = []
                    }

        RemovePermission permission_id ->
            { state =
                { state
                    | permissions =
                        Set.filter (\id -> id /= permission_id) state.permissions
                }
            , cmd = Cmd.none
            , requests = []
            , done = False
            , notifications = []
            }

        Submit ->
            { state = init
            , cmd =
                Http.request
                    { method = "POST"
                    , headers = [ Http.header "id_token" id_token ]
                    , url = User.manyUrl
                    , body = Http.jsonBody (newEncoder state)
                    , expect = Http.expectWhatever Submitted
                    , timeout = Nothing
                    , tracker = Nothing
                    }
            , requests = [ User.manyUrl |> RemoveRequest ]
            , done = False
            , notifications = []
            }

        Submitted result ->
            case result of
                Ok _ ->
                    { state = init
                    , cmd = Cmd.none
                    , requests = [ User.manyUrl |> RemoveRequest ]
                    , done = True
                    , notifications = []
                    }

                Err e ->
                    { state = state
                    , cmd = Cmd.none
                    , requests = [ User.manyUrl |> RemoveRequest ]
                    , done = False
                    , notifications =
                        [ NError
                            """
                            There was a network error submitting the new user
                            """
                        ]
                    }


view : State -> Html Msg
view state =
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
                        , value state.first_name
                        , onInput EditFirstName
                        ]
                        []
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Last Name: " ]
                    , input
                        [ class "input"
                        , value state.last_name
                        , onInput EditLastName
                        ]
                        []
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Email: " ]
                    , input
                        [ class "input"
                        , value state.email
                        , onInput EditEmail
                        ]
                        []
                    ]
                , div [ class "box" ]
                    [ span [] [ text "Banner ID: " ]
                    , input
                        [ class "input"
                        , type_ "number"
                        , value (String.fromInt state.banner_id)
                        , onInput
                            (\s -> String.toInt s |> EditBannerId)
                        ]
                        []
                    ]
                , button
                    [ class "button is-primary"
                    , onClick Submit
                    ]
                    [ text "Submit new user" ]
                ]
            , div [ class "column" ]
                [ p [ class "subtitle has-text-centered" ]
                    [ text "User Permissions" ]
                , div [ class "box" ]
                    (Set.toList state.permissions
                        |> List.map (viewPermission RemovePermission)
                    )
                , User.viewAddPermission
                    state.permission_edits
                    EditPermission
                    AddPermission
                ]
            ]
        ]


viewPermission : (Int -> msg) -> Int -> Html msg
viewPermission onRemove id =
    div [ class "columns" ]
        [ span [ class "column" ]
            [ String.fromInt id |> text ]
        , div [ class "column" ]
            [ button
                [ class
                    "button is-danger is-pulled-right"
                , onClick
                    (onRemove id)
                ]
                [ text "Remove" ]
            ]
        ]


newEncoder : NewUser r -> Json.Encode.Value
newEncoder user =
    Json.Encode.object
        [ ( "first_name", Json.Encode.string user.first_name )
        , ( "last_name", Json.Encode.string user.last_name )
        , ( "banner_id", Json.Encode.int user.banner_id )
        , ( "email", Json.Encode.string user.email )
        , ( "permissions", Json.Encode.list Json.Encode.int (Set.toList user.permissions) )
        ]
